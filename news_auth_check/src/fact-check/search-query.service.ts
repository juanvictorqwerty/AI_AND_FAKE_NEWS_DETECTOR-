import { Injectable, Logger } from '@nestjs/common';

// Claim type classification
export type ClaimType = 'fact' | 'news' | 'controversial';

// Result interface
export interface QueryGenerationResult {
    type: ClaimType;
    searchQuery: string;
}

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

    // Controversial indicators
    private readonly controversialIndicators = [
        'vaccine', 'election', 'politician', 'political', 'government',
        'conspiracy', 'climate', 'global warming', 'immigration', 'abortion',
        'gun', 'weapon', 'terrorist', 'extremist', 'hoax', 'fake news',
        'scam', 'fraud', 'lie', 'false', 'misinformation', 'disinformation',
        'racist', 'sexist', 'homophobic', 'transgender', 'lgbtq',
        'congress', 'senate', 'parliament', 'white house'
    ];

    // News indicators
    private readonly newsIndicators = [
        'breaking', 'developing', 'announcement', 'reported',
        'crisis', 'emergency', 'outbreak', 'pandemic', 'war', 'conflict',
        'attack', 'shooting', 'explosion', 'disaster', 'accident',
        'summit', 'conference', 'vote', 'meeting'
    ];

    // Fact indicators
    private readonly factIndicators = [
        'where is', 'what is', 'who is', 'when did', 'how did',
        'is it true that', 'does', 'can', 'location', 'capital',
        'population', 'founded', 'created', 'invented', 'discovered',
        'country', 'city', 'river', 'mountain', 'ocean', 'continent',
        'planet', 'star', 'element', 'chemical', 'species', 'animal',
        'president', 'king', 'queen', 'emperor', 'history', 'ancient',
        'world war', 'century', 'year', 'date', 'birth', 'death'
    ];

    /**
     * Classify claim and generate optimized search query
     * Based on the system prompt rules:
     * - "fact" → general knowledge (geography, science, history)
     * - "news" → recent or time-sensitive events
     * - "controversial" → disputed, political, or viral claims
     * 
     * @param claim - The user's claim
     * @returns Object with claim type and optimized search query
     */
    classifyAndGenerateQuery(claim: string): QueryGenerationResult {
        this.logger.log(`Classifying and generating query for: "${claim.substring(0, 50)}..."`);

        // Step 1: Classify the claim
        const claimType = this.classifyClaim(claim);

        // Step 2: Generate optimized query based on type
        const searchQuery = this.generateTypeBasedQuery(claim, claimType);

        this.logger.log(`Classified as: ${claimType}, Generated query: "${searchQuery}"`);
        
        return {
            type: claimType,
            searchQuery,
        };
    }

    /**
     * Generate an optimized search query from a claim
     * @param claim - The user's claim
     * @returns Optimized search query string
     */
    generateSearchQuery(claim: string): string {
        const result = this.classifyAndGenerateQuery(claim);
        return result.searchQuery;
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

    // ============== Private Methods ==============

    /**
     * Classify a claim into one of three types
     */
    private classifyClaim(claim: string): ClaimType {
        const claimLower = claim.toLowerCase();

        // Check for controversial first (highest priority)
        if (this.controversialIndicators.some(ind => claimLower.includes(ind))) {
            return 'controversial';
        }

        // Check for news indicators
        if (this.newsIndicators.some(ind => claimLower.includes(ind))) {
            return 'news';
        }

        // Check for fact indicators
        if (this.factIndicators.some(ind => claimLower.includes(ind))) {
            return 'fact';
        }

        // Default: treat as controversial if unclear (safer for fact-checking)
        return 'controversial';
    }

    /**
     * Generate optimized query based on claim type
     */
    private generateTypeBasedQuery(claim: string, claimType: ClaimType): string {
        // Clean the claim first
        let query = this.cleanClaim(claim);

        switch (claimType) {
            case 'fact':
                return this.optimizeFactQuery(query);
            case 'news':
                return this.optimizeNewsQuery(query);
            case 'controversial':
                return this.optimizeControversialQuery(query);
            default:
                return this.optimizeControversialQuery(query);
        }
    }

    /**
     * Optimize for factual claims (geography, science, history)
     */
    private optimizeFactQuery(query: string): string {
        const queryLower = query.toLowerCase();

        // If already has question phrases, add Wikipedia
        if (queryLower.includes('where') || queryLower.includes('what') || 
            queryLower.includes('who') || queryLower.includes('when')) {
            return `${query} Wikipedia`;
        }

        // Convert to question format based on content
        if (queryLower.includes('is ') || queryLower.includes('are ')) {
            return `Is it true that ${query}`;
        }

        // Add what/where/who based on context
        if (queryLower.includes('located') || queryLower.includes('location')) {
            return `Where is ${query.replace(/\b(located|location)\b/gi, '').trim()}`;
        }

        if (queryLower.includes('capital')) {
            return `What is the capital of ${query.replace(/\bcapital\b/gi, '').trim()}`;
        }

        // Default: add "what is" for facts
        return `What is ${query}`;
    }

    /**
     * Optimize for news claims (recent events)
     */
    private optimizeNewsQuery(query: string): string {
        // Remove vague time terms
        query = this.removeVagueTerms(query);

        // Check if query already has news keywords
        const hasNewsKeyword = ['news', 'report', 'update', 'breaking'].some(kw => 
            query.toLowerCase().includes(kw)
        );

        if (!hasNewsKeyword) {
            // Add year if present in claim, otherwise add news
            const yearMatch = query.match(/\b(19|20)\d{2}\b/);
            if (yearMatch) {
                return `${query} news report ${yearMatch[0]}`;
            }
            return `${query} news report`;
        }

        return query;
    }

    /**
     * Optimize for controversial claims (disputed, political, viral)
     */
    private optimizeControversialQuery(query: string): string {
        // Remove vague terms
        query = this.removeVagueTerms(query);

        const queryLower = query.toLowerCase();

        // Check if already has fact-check keywords
        if (queryLower.includes('fact check') || queryLower.includes('true or false')) {
            return query;
        }

        // Add fact check and true/false indicators
        if (queryLower.includes('is ') || queryLower.includes('are ') || 
            queryLower.includes('was ') || queryLower.includes('were ')) {
            return `${query} fact check true or false`;
        }

        // Default for controversial
        return `${query} fact check verified`;
    }

    /**
     * Clean and normalize claim text
     */
    private cleanClaim(claim: string): string {
        return claim
            .replace(/[^\w\s.,!?'"-]/g, '')
            .replace(/\s+/g, ' ')
            .trim()
            .substring(0, 200);
    }

    /**
     * Remove vague time terms from query
     */
    private removeVagueTerms(query: string): string {
        let result = query;
        for (const term of this.vagueTerms) {
            const regex = new RegExp(`\\b${term}\\b`, 'gi');
            result = result.replace(regex, '');
        }
        return result.replace(/\s+/g, ' ').trim();
    }

    /**
     * Add news keywords to make query more targeted
     */
    private addNewsKeywords(query: string): string {
        const hasKeyword = this.newsKeywords.some(kw => 
            query.toLowerCase().includes(kw)
        );

        if (!hasKeyword) {
            return `${query} news`;
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
