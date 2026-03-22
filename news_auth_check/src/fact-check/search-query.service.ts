import { Injectable, Logger } from '@nestjs/common';

/**
 * Service for generating optimized search queries from user claims
 * Transforms claims into search-engine-friendly queries optimized for fact-checking
 */
@Injectable()
export class SearchQueryService {
    private readonly logger = new Logger(SearchQueryService.name);

    // Vague time terms to remove
    private readonly vagueTerms = [
        'today', 'yesterday', 'tomorrow', 'recently', 'just now',
        'latest', 'last week', 'last month', 'last year', 'this year',
        'current', 'now', 'right now', 'in the news'
    ];

    // Keywords to add for better fact-checking
    private readonly newsKeywords = [
        'news', 'report', 'update', 'fact check', 'verified',
        'debunked', 'confirmation', 'evidence'
    ];

    // Trusted source domains (high trust score)
    private readonly trustedDomains = [
        // Major news agencies
        'reuters.com', 'apnews.com', 'ap.org', 'afp.com',
        // BBC
        'bbc.com', 'bbc.co.uk',
        // Major newspapers
        'nytimes.com', 'washingtonpost.com', 'theguardian.com',
        'wsj.com', 'financial times', 'bloomberg.com',
        // TV networks
        'cnn.com', 'nbcnews.com', 'abcnews.go.com', 'cbsnews.com',
        'foxnews.com', 'msnbc.com', 'aljazeera.com',
        // Fact-checking sites
        'snopes.com', 'factcheck.org', 'politifact.com', 'fullfact.org',
        // Government & official (.gov domains)
        '.gov',
        // International organizations
        'who.int', 'un.org', 'europa.eu',
        // Academic & scientific
        'edu', 'nature.com', 'science.org', 'sciencemag.org',
        // Health
        'cdc.gov', 'mayoclinic.org', 'nih.gov', 'healthline.com',
        // Other trusted
        'wikipedia.org', 'nasa.gov', 'ox.ac.uk', 'cam.ac.uk',
    ];

    // Untrusted domains (low trust score - blocked)
    private readonly untrustedDomains = [
        'facebook.com', 'fb.com', 'instagram.com', 'twitter.com',
        'x.com', 'tiktok.com', 'reddit.com', 'youtube.com',
        'linkedin.com', 'pinterest.com', 'snapchat.com',
        'whatsapp.com', 'telegram.org', 'discord.com',
        'medium.com', 'substack.com', 'blogspot.com',
        'wordpress.com', 'tumblr.com',
    ];

    /**
     * Generate an optimized search query from a claim
     * Removes vague terms and adds keywords for reliable news
     * @param claim - The user's claim
     * @returns Optimized search query string
     */
    generateSearchQuery(claim: string): string {
        this.logger.log(`Generating search query for claim: "${claim.substring(0, 50)}..."`);

        // Step 1: Clean the claim
        let query = this.cleanClaim(claim);

        // Step 2: Remove vague time terms
        query = this.removeVagueTerms(query);

        // Step 3: Add news/reliable source keywords
        query = this.addNewsKeywords(query);

        // Step 4: Add year if relevant (helps with historical claims)
        query = this.addYearContext(query);

        this.logger.log(`Generated query: "${query}"`);
        return query;
    }

    /**
     * Generate alternative search queries for broader coverage
     */
    generateAlternativeQueries(claim: string): string[] {
        const queries: string[] = [];

        // Original optimized query
        queries.push(this.generateSearchQuery(claim));

        // Query with just key facts
        const keyFacts = this.extractKeyFacts(claim);
        if (keyFacts) {
            queries.push(`"${keyFacts}" news report`);
        }

        // Query with fact-check emphasis
        queries.push(`${claim} fact check verified`);

        // Query with trusted sources
        const trustedList = this.trustedDomains.slice(0, 3).join(' OR ');
        queries.push(`${claim} (${trustedList})`);

        return [...new Set(queries)];
    }

    /**
     * Check if a URL is from a trusted source
     */
    isTrustedSource(url: string): boolean {
        const urlLower = url.toLowerCase();
        
        // Check if it's an untrusted domain first
        for (const domain of this.untrustedDomains) {
            if (urlLower.includes(domain)) {
                return false;
            }
        }

        // Check if it's a trusted domain
        for (const domain of this.trustedDomains) {
            if (domain.startsWith('.')) {
                // Handle .gov domains
                if (urlLower.includes(domain)) {
                    return true;
                }
            } else if (urlLower.includes(domain)) {
                return true;
            }
        }

        return false;
    }

    /**
     * Get trust score for a URL (0-100)
     */
    getTrustScore(url: string): number {
        const urlLower = url.toLowerCase();

        // BLOCKED: Untrusted domains get 0
        for (const domain of this.untrustedDomains) {
            if (urlLower.includes(domain)) {
                return 0;
            }
        }

        // Highest score: Fact-checking sites
        const factCheckSites = ['snopes.com', 'factcheck.org', 'politifact.com', 'fullfact.org', 'afp.com'];
        if (factCheckSites.some(site => urlLower.includes(site))) {
            return 100;
        }

        // High score: Major news agencies
        const newsAgencies = ['reuters.com', 'apnews.com', 'ap.org', 'bbc.com', 'bbc.co.uk'];
        if (newsAgencies.some(site => urlLower.includes(site))) {
            return 95;
        }

        // High score: Government domains
        if (urlLower.includes('.gov')) {
            return 90;
        }

        // High score: Major newspapers
        const majorPapers = ['nytimes.com', 'washingtonpost.com', 'theguardian.com', 'wsj.com'];
        if (majorPapers.some(site => urlLower.includes(site))) {
            return 85;
        }

        // Medium-high: Educational institutions
        if (urlLower.includes('.edu')) {
            return 80;
        }

        // Medium: Health organizations
        const healthSites = ['who.int', 'cdc.gov', 'nih.gov', 'mayoclinic.org'];
        if (healthSites.some(site => urlLower.includes(site))) {
            return 80;
        }

        // Medium: Scientific journals
        const scienceSites = ['nature.com', 'science.org', 'sciencemag.org'];
        if (scienceSites.some(site => urlLower.includes(site))) {
            return 75;
        }

        // Medium: Wikipedia
        if (urlLower.includes('wikipedia.org')) {
            return 70;
        }

        // Medium: Other trusted news
        const otherTrusted = ['aljazeera.com', 'cnn.com', 'npr.org', 'theconversation.com'];
        if (otherTrusted.some(site => urlLower.includes(site))) {
            return 65;
        }

        // Default for unknown domains
        return 30;
    }

    /**
     * Get list of trusted domains
     */
    getTrustedDomains(): string[] {
        return [...this.trustedDomains];
    }

    /**
     * Get list of untrusted domains
     */
    getUntrustedDomains(): string[] {
        return [...this.untrustedDomains];
    }

    /**
     * Clean and normalize claim text
     */
    private cleanClaim(claim: string): string {
        return claim
            .replace(/[^\w\s.,!?'"-]/g, '') // Remove special characters except punctuation
            .replace(/\s+/g, ' ') // Normalize whitespace
            .trim()
            .substring(0, 200);
    }

    /**
     * Remove vague time terms from query
     */
    private removeVagueTerms(query: string): string {
        let result = query;
        for (const term of this.vagueTerms) {
            // Remove the term (case insensitive)
            const regex = new RegExp(`\\b${term}\\b`, 'gi');
            result = result.replace(regex, '');
        }
        // Clean up extra spaces
        return result.replace(/\s+/g, ' ').trim();
    }

    /**
     * Add news keywords to make query more targeted
     */
    private addNewsKeywords(query: string): string {
        // Check if query already has news keywords
        const hasKeyword = this.newsKeywords.some(kw => 
            query.toLowerCase().includes(kw)
        );

        if (!hasKeyword) {
            // Add "news" for general queries
            return `${query} news`;
        }

        return query;
    }

    /**
     * Add year context for historical claims
     */
    private addYearContext(query: string): string {
        // Check if query already has a year
        const yearPattern = /\b(19|20)\d{2}\b/;
        if (yearPattern.test(query)) {
            return query;
        }

        // Check for historical indicators that might benefit from year
        const historicalIndicators = ['created', 'established', 'founded', 'independent', 'war', 'election'];
        if (historicalIndicators.some(ind => query.toLowerCase().includes(ind))) {
            // Add current year context hint
            return query;
        }

        return query;
    }

    /**
     * Extract key facts/names from claim for alternative queries
     */
    private extractKeyFacts(claim: string): string {
        // Extract quoted text first
        const quotedMatch = claim.match(/"([^"]+)"/);
        if (quotedMatch) {
            return quotedMatch[1];
        }

        // Extract capitalized phrases (proper nouns)
        const words = claim.split(' ');
        const keyWords: string[] = [];
        
        for (const word of words) {
            if (/^[A-Z][a-z]+$/.test(word) && word.length > 2) {
                keyWords.push(word);
            }
            if (keyWords.length >= 4) break;
        }

        return keyWords.join(' ');
    }
}
