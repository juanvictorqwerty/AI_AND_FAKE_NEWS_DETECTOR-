import { Injectable, Logger, HttpException, HttpStatus } from '@nestjs/common';
import axios, { AxiosError } from 'axios';
import { load } from 'cheerio';
import { SearchSourceDto } from './dto';
import { SearchQueryService } from './search-query.service';

/**
 * Service for web scraping fact-check sources
 * Uses multiple search APIs and scrapes results
 */
@Injectable()
export class WebScraperService {
    private readonly logger = new Logger(WebScraperService.name);
    private readonly requestCache = new Map<string, { data: SearchSourceDto[]; timestamp: number }>();
    private readonly CACHE_TTL = 30 * 60 * 1000; // 30 minutes
    private readonly requestTimestamps: number[] = [];
    private readonly RATE_LIMIT = 10; // requests per minute
    private readonly RATE_WINDOW = 60 * 1000; // 1 minute

    constructor(private readonly searchQueryService: SearchQueryService) {}

    /**
     * Search the web for fact-check sources
     * Uses Bing Search API (or can be configured for others)
     * @param claim - The claim to search for
     * @returns Array of search results from trusted sources
     */
    async searchWeb(claim: string): Promise<SearchSourceDto[]> {
        // Check cache first
        const cacheKey = this.generateCacheKey(claim);
        const cached = this.getFromCache(cacheKey);
        if (cached) {
            this.logger.log('Returning cached search results');
            return cached;
        }

        // Check rate limit
        if (!this.checkRateLimit()) {
            this.logger.warn('Rate limit exceeded for web search');
            throw new HttpException(
                'Search rate limit exceeded. Please try again later.',
                HttpStatus.TOO_MANY_REQUESTS
            );
        }

        // Generate search query
        const searchQuery = this.searchQueryService.generateSearchQuery(claim);
        this.logger.log(`Searching web for: "${searchQuery}"`);

        try {
            // Use Google Custom Search API or fallback to DuckDuckGo
            const results = await this.performSearch(searchQuery);
            
            // Filter and score results
            const filteredResults = this.filterAndScoreResults(results);
            
            // Cache results
            this.setCache(cacheKey, filteredResults);
            
            return filteredResults;
        } catch (error) {
            this.logger.error(`Web search failed: ${error}`);
            return this.handleSearchError(error);
        }
    }

    /**
     * Perform the actual search
     * Supports multiple search providers
     */
    private async performSearch(query: string): Promise<SearchSourceDto[]> {
        const apiKey = process.env.GOOGLE_SEARCH_API_KEY;
        const searchEngineId = process.env.GOOGLE_SEARCH_ENGINE_ID;

        // If Google Custom Search credentials are available, use them
        if (apiKey && searchEngineId) {
            return this.searchWithGoogle(query, apiKey, searchEngineId);
        }

        // Fallback: Use SerpAPI or other service
        const serpApiKey = process.env.SERP_API_KEY;
        if (serpApiKey) {
            return this.searchWithSerpApi(query, serpApiKey);
        }

        // Last resort: Return empty with message
        this.logger.warn('No search API configured');
        return [];
    }

    /**
     * Search using Google Custom Search API
     */
    private async searchWithGoogle(
        query: string,
        apiKey: string,
        searchEngineId: string
    ): Promise<SearchSourceDto[]> {
        const url = 'https://www.googleapis.com/customsearch/v1';
        
        const response = await axios.get(url, {
            params: {
                key: apiKey,
                cx: searchEngineId,
                q: query,
                num: 10,
                safe: 'active',
            },
            timeout: 10000,
        });

        const items = response.data.items || [];
        
        return items.map((item: any) => ({
            title: item.title || 'No title',
            url: item.link || '',
            date: item.pagemap?.metatags?.[0]?.['article:published_time'] || 
                  item.pagemap?.metatags?.[0]?.date || 
                  new Date().toISOString(),
            snippet: item.snippet || 'No description available',
            publisher: item.displayLink || new URL(item.link).hostname,
            isTrusted: this.searchQueryService.isTrustedSource(item.link),
        }));
    }

    /**
     * Search using SerpAPI (fallback)
     */
    private async searchWithSerpApi(query: string, apiKey: string): Promise<SearchSourceDto[]> {
        this.logger.log(`Using SerpAPI for search: "${query}"`);
        
        try {
            const url = 'https://serpapi.com/search';
            
            const response = await axios.get(url, {
                params: {
                    api_key: apiKey,
                    q: query,
                    engine: 'google',
                    num: 10,
                },
                timeout: 15000,
            });

            this.logger.log(`SerpAPI response status: ${response.status}`);
            this.logger.log(`SerpAPI response keys: ${Object.keys(response.data).join(', ')}`);

            // Check for error in response
            if (response.data.error) {
                this.logger.error(`SerpAPI error: ${response.data.error}`);
                return [];
            }

            const items = response.data.organic_results || [];
            this.logger.log(`Found ${items.length} organic results`);

            if (items.length === 0) {
                // Check for other result types
                const wikiResults = response.data.knowledge_graph || [];
                const newsResults = response.data.news_results || [];
                this.logger.log(`Knowledge graph: ${wikiResults.length}, News: ${newsResults.length}`);
            }
            
            return items.map((item: any) => ({
                title: item.title || 'No title',
                url: item.link || '',
                date: item.date || new Date().toISOString(),
                snippet: item.snippet || 'No description available',
                publisher: item.displayed_url || (item.link ? new URL(item.link).hostname : 'Unknown'),
                isTrusted: this.searchQueryService.isTrustedSource(item.link || ''),
            }));
        } catch (error: any) {
            this.logger.error(`SerpAPI request failed: ${error.message}`);
            if (error.response) {
                this.logger.error(`SerpAPI status: ${error.response.status}, data: ${JSON.stringify(error.response.data).substring(0, 200)}`);
            }
            return [];
        }
    }

    /**
     * Search web - uses SerpAPI directly
     */
    async searchWebWithFallback(claim: string): Promise<SearchSourceDto[]> {
        this.logger.log(`Searching web for: "${claim}"`);
        
        // Use SerpAPI directly
        const searchQuery = this.searchQueryService.generateSearchQuery(claim);
        const results = await this.searchWeb(searchQuery);
        
        this.logger.log(`Found ${results.length} search results`);
        
        // Sort by trust score
        return this.sortByTrustworthiness(results).slice(0, 10);
    }

    /**
     * Search Wikipedia specifically - with multiple fallback methods
     */
    private async searchWikipedia(claim: string): Promise<SearchSourceDto[]> {
        const cleanClaim = claim.replace(/[^\w\s]/g, ' ').trim();
        
        // Try method 1: Wikipedia API with origin=*
        try {
            const response = await axios.get('https://en.wikipedia.org/w/api.php', {
                params: {
                    action: 'query',
                    list: 'search',
                    srsearch: cleanClaim,
                    format: 'json',
                    origin: '*',
                    srlimit: 5,
                },
                timeout: 5000,
            });

            const searchResults = response.data?.query?.search || [];
            if (searchResults.length > 0) {
                return searchResults.map((result: any) => ({
                    title: result.title,
                    url: `https://en.wikipedia.org/wiki/${encodeURIComponent(result.title.replace(/\s/g, '_'))}`,
                    date: new Date().toISOString(),
                    snippet: this.stripHtml(result.snippet),
                    publisher: 'Wikipedia',
                    isTrusted: true,
                }));
            }
        } catch (error) {
            this.logger.warn(`Wikipedia API method 1 failed: ${error}`);
        }

        // Try method 2: Wikipedia REST API (no CORS issues)
        try {
            const response = await axios.get('https://en.wikipedia.org/api/rest_v1/page/summary/' + encodeURIComponent(cleanClaim.split(' ')[0]), {
                timeout: 5000,
            });

            if (response.data) {
                return [{
                    title: response.data.title,
                    url: response.data.content_urls?.desktop?.page || `https://en.wikipedia.org/wiki/${encodeURIComponent(cleanClaim.split(' ')[0])}`,
                    date: response.data.timestamp || new Date().toISOString(),
                    snippet: response.data.extract || 'No description available',
                    publisher: 'Wikipedia',
                    isTrusted: true,
                }];
            }
        } catch (error) {
            this.logger.warn(`Wikipedia REST API failed: ${error}`);
        }

        // Try method 3: DuckDuckGo Instant Answer API (free, no key needed)
        try {
            const response = await axios.get('https://api.duckduckgo.com/', {
                params: {
                    q: cleanClaim,
                    format: 'json',
                    no_html: 1,
                    skip_disambig: 1,
                },
                timeout: 5000,
            });

            if (response.data?.AbstractText && response.data.RelatedTopics?.length > 0) {
                const relatedWiki = response.data.RelatedTopics.find((t: any) => t.URL?.includes('wikipedia'));
                if (relatedWiki) {
                    return [{
                        title: response.data.Heading || cleanClaim,
                        url: relatedWiki.FirstURL || response.data.AbstractURL,
                        date: new Date().toISOString(),
                        snippet: response.data.AbstractText.substring(0, 300),
                        publisher: 'DuckDuckGo',
                        isTrusted: true,
                    }];
                }
            }
        } catch (error) {
            this.logger.warn(`DuckDuckGo API failed: ${error}`);
        }

        return [];
    }

    /**
     * Direct Wikipedia page lookup - with multiple fallbacks
     */
    private async searchWikipediaDirect(claim: string): Promise<SearchSourceDto[]> {
        // Extract key terms for Wikipedia lookup - try first 2-3 significant words
        const words = claim.split(' ').filter(w => w.length > 2);
        const keyTerms = words.slice(0, 2).join('_');

        // Try Wikipedia REST API first
        try {
            const response = await axios.get(`https://en.wikipedia.org/api/rest_v1/page/summary/${encodeURIComponent(keyTerms)}`, {
                timeout: 5000,
            });

            if (response.data && !response.data.type?.includes('disambiguation')) {
                return [{
                    title: response.data.title,
                    url: response.data.content_urls?.desktop?.page || `https://en.wikipedia.org/wiki/${encodeURIComponent(keyTerms)}`,
                    date: response.data.timestamp || new Date().toISOString(),
                    snippet: response.data.extract?.substring(0, 300) || 'No description available',
                    publisher: 'Wikipedia',
                    isTrusted: true,
                }];
            }
        } catch (error) {
            this.logger.warn(`Wikipedia REST direct failed: ${error}`);
        }

        // Try traditional API
        try {
            const response = await axios.get('https://en.wikipedia.org/w/api.php', {
                params: {
                    action: 'query',
                    prop: 'extracts',
                    titles: keyTerms,
                    format: 'json',
                    origin: '*',
                    exintro: true,
                    explaintext: true,
                    exsentences: 3,
                },
                timeout: 5000,
            });

            const pages = response.data?.query?.pages || {};
            
            for (const pageId in pages) {
                const page = pages[pageId];
                if (pageId !== '-1' && page.extract) {
                    return [{
                        title: page.title,
                        url: `https://en.wikipedia.org/wiki/${encodeURIComponent(page.title.replace(/\s/g, '_'))}`,
                        date: new Date().toISOString(),
                        snippet: page.extract.substring(0, 300),
                        publisher: 'Wikipedia',
                        isTrusted: true,
                    }];
                }
            }
        } catch (error) {
            this.logger.warn(`Wikipedia traditional API failed: ${error}`);
        }

        return [];
    }

    /**
     * Strip HTML tags from text
     */
    private stripHtml(html: string): string {
        return html.replace(/<[^>]*>/g, '');
    }

    /**
     * Sort results by trustworthiness
     */
    private sortByTrustworthiness(results: SearchSourceDto[]): SearchSourceDto[] {
        return results.sort((a, b) => {
            const scoreA = this.searchQueryService.getTrustScore(a.url);
            const scoreB = this.searchQueryService.getTrustScore(b.url);
            return scoreB - scoreA;
        });
    }

    /**
     * Scrape additional content from a URL
     * @param url - The URL to scrape
     * @returns Enriched source data
     */
    async scrapeUrl(url: string): Promise<Partial<SearchSourceDto>> {
        try {
            const response = await axios.get(url, {
                timeout: 10000,
                headers: {
                    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                },
            });

            const $ = load(response.data);
            
            // Extract meta information
            const title = $('title').text() || $('h1').first().text() || 'No title';
            const description = $('meta[name="description"]').attr('content') ||
                              $('meta[property="og:description"]').attr('content') ||
                              $('p').first().text().substring(0, 200);
            
            // Try to find date
            const date = $('meta[property="article:published_time"]').attr('content') ||
                        $('time').attr('datetime') ||
                        new Date().toISOString();

            return {
                title: title.trim(),
                snippet: description.trim(),
                date,
            };
        } catch (error) {
            this.logger.error(`Failed to scrape ${url}: ${error}`);
            return {};
        }
    }

    /**
     * Filter and score search results
     */
    private filterAndScoreResults(results: SearchSourceDto[]): SearchSourceDto[] {
        // Score and sort by trustworthiness
        const scored = results.map(result => ({
            ...result,
            trustScore: this.searchQueryService.getTrustScore(result.url),
        }));

        // Sort by trust score (descending)
        scored.sort((a, b) => (b as any).trustScore - (a as any).trustScore);

        // Filter out very low trust scores
        return scored
            .filter((r: any) => r.trustScore >= 50)
            .map(({ trustScore, ...rest }) => rest as SearchSourceDto);
    }

    /**
     * Check if request is within rate limits
     */
    private checkRateLimit(): boolean {
        const now = Date.now();
        
        // Remove timestamps outside the window
        while (this.requestTimestamps.length > 0 && 
               this.requestTimestamps[0] < now - this.RATE_WINDOW) {
            this.requestTimestamps.shift();
        }

        // Check if we can make another request
        if (this.requestTimestamps.length >= this.RATE_LIMIT) {
            return false;
        }

        // Record this request
        this.requestTimestamps.push(now);
        return true;
    }

    /**
     * Generate cache key for a query
     */
    private generateCacheKey(claim: string): string {
        return claim.toLowerCase().trim().replace(/\s+/g, ' ');
    }

    /**
     * Get cached results if valid
     */
    private getFromCache(key: string): SearchSourceDto[] | null {
        const cached = this.requestCache.get(key);
        if (cached && Date.now() - cached.timestamp < this.CACHE_TTL) {
            return cached.data;
        }
        return null;
    }

    /**
     * Cache search results
     */
    private setCache(key: string, data: SearchSourceDto[]): void {
        this.requestCache.set(key, {
            data,
            timestamp: Date.now(),
        });

        // Clean old cache entries periodically
        if (this.requestCache.size > 100) {
            const now = Date.now();
            for (const [k, v] of this.requestCache.entries()) {
                if (now - v.timestamp > this.CACHE_TTL) {
                    this.requestCache.delete(k);
                }
            }
        }
    }

    /**
     * Handle search errors gracefully
     */
    private handleSearchError(error: unknown): SearchSourceDto[] {
        if (axios.isAxiosError(error)) {
            const axiosError = error as AxiosError;
            
            if (axiosError.response?.status === 429) {
                throw new HttpException(
                    'Search API rate limit exceeded. Please try again later.',
                    HttpStatus.TOO_MANY_REQUESTS
                );
            }

            if (axiosError.response?.status === 403) {
                throw new HttpException(
                    'Search API access denied. Check your API credentials.',
                    HttpStatus.FORBIDDEN
                );
            }
        }

        // Return empty results on error rather than crashing
        this.logger.warn('Search failed, returning empty results');
        return [];
    }
}
