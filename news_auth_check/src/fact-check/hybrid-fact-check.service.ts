import { Injectable, Logger } from '@nestjs/common';
import { FactCheckService } from './fact-check.service';
import { WebScraperService } from './web-scraper.service';
import { SearchQueryService } from './search-query.service';
import {
    HybridFactCheckDto,
    SearchFactCheckResultDto,
    SearchSourceDto,
    ClaimReviewStatus,
} from './dto';

/**
 * Service that combines Google Fact Check API with web search
 * Provides comprehensive fact-checking using multiple sources
 */
@Injectable()
export class HybridFactCheckService {
    private readonly logger = new Logger(HybridFactCheckService.name);

    constructor(
        private readonly factCheckService: FactCheckService,
        private readonly webScraperService: WebScraperService,
        private readonly searchQueryService: SearchQueryService,
    ) {}

    /**
     * Perform hybrid fact-checking
     * 1. First checks Google Fact Check API
     * 2. Always searches the web (Wikipedia prioritized) for additional context
     * 3. Combines results and provides verdict
     */
    async hybridFactCheck(
        dto: HybridFactCheckDto,
    ): Promise<SearchFactCheckResultDto> {
        const { claim, languageCode = 'en', skipWebSearch = false } = dto;

        this.logger.log(`Starting hybrid fact-check for: "${claim.substring(0, 50)}..."`);

        // Generate search query for reference
        const searchQuery = this.searchQueryService.generateSearchQuery(claim);

        // Step 1: Check Google Fact Check API
        const googleResult = await this.checkGoogleFactCheck(claim, languageCode);

        // If Google API found a definitive result, we still search web for additional context
        let webResults: any[] = [];
        
        if (!skipWebSearch) {
            this.logger.log('Searching web for additional sources (Wikipedia prioritized)...');
            
            try {
                // Always try to get Wikipedia and other authoritative sources
                webResults = await this.webScraperService.searchWebWithFallback(claim);
                
                if (webResults.length > 0) {
                    this.logger.log(`Found ${webResults.length} web sources`);
                }
            } catch (error) {
                this.logger.error(`Web search failed: ${error}`);
            }
        }

        // Step 2: Determine verdict based on all available data
        let verdict: 'true' | 'false' | 'unverified' | 'inconclusive';
        let evidenceSummary: string;

        // If Google API has definitive result, use it but supplement with web sources
        if (googleResult && googleResult.status !== ClaimReviewStatus.UNVERIFIED) {
            verdict = this.mapStatusToVerdict(googleResult.status);
            evidenceSummary = this.generateCombinedEvidenceSummary(claim, googleResult, webResults);
        } else if (webResults.length > 0) {
            // Try to determine verdict from web sources
            verdict = this.analyzeWebResults(webResults);
            evidenceSummary = this.generateWebEvidenceSummary(claim, webResults, verdict, googleResult);
        } else {
            verdict = 'unverified';
            evidenceSummary = this.generateUnverifiedSummary(claim, googleResult);
        }

        return {
            success: true,
            claimText: claim,
            searchQuery,
            googleFactCheckResult: googleResult ? {
                found: true,
                status: googleResult.status,
                source: googleResult.source,
                sourceUrl: googleResult.sourceUrl,
                reviewDate: googleResult.reviewDate,
                textualRating: googleResult.textualRating,
            } : undefined,
            webSearchResults: webResults.slice(0, 5),
            combinedVerdict: verdict,
            evidenceSummary,
            totalSources: webResults.length + (googleResult && googleResult.status !== ClaimReviewStatus.UNVERIFIED ? 1 : 0),
            trustedSourcesCount: webResults.filter(r => r.isTrusted).length + (googleResult && googleResult.status !== ClaimReviewStatus.UNVERIFIED ? 1 : 0),
            message: webResults.length === 0 && (!googleResult || googleResult.status === ClaimReviewStatus.UNVERIFIED) 
                ? 'No definitive fact-check found from reliable sources.' 
                : undefined,
        };
    }

    /**
     * Check Google Fact Check API
     */
    private async checkGoogleFactCheck(
        claim: string,
        languageCode: string,
    ) {
        try {
            const result = await this.factCheckService.factCheckClaim({
                claim,
                languageCode,
            });
            return result.success ? result : null;
        } catch (error) {
            this.logger.error(`Google Fact Check API error: ${error}`);
            return null;
        }
    }

    /**
     * Analyze web search results to determine a verdict
     */
    private analyzeWebResults(results: SearchSourceDto[]): 'true' | 'false' | 'unverified' | 'inconclusive' {
        // Count results by implied verdict based on keywords in snippets
        let trueCount = 0;
        let falseCount = 0;
        let unverifiedCount = 0;

        const trueKeywords = ['true', 'confirmed', 'verified', 'correct', 'accurate'];
        const falseKeywords = ['false', 'fake', 'debunked', 'misinformation', 'hoax', 'incorrect'];

        for (const result of results) {
            const snippet = (result.snippet + ' ' + result.title).toLowerCase();
            
            // Check for fact-check sites with definitive answers
            if (result.isTrusted) {
                if (falseKeywords.some(k => snippet.includes(k))) {
                    falseCount += 2; // Weight trusted sources higher
                } else if (trueKeywords.some(k => snippet.includes(k))) {
                    trueCount += 2;
                }
            }
        }

        // Determine verdict based on weighted counts
        if (falseCount > trueCount * 1.5) return 'false';
        if (trueCount > falseCount * 1.5) return 'true';
        if (trueCount === 0 && falseCount === 0) return 'unverified';
        return 'inconclusive';
    }

    /**
     * Generate combined evidence summary from Google API and web results
     */
    private generateCombinedEvidenceSummary(
        claim: string,
        googleResult: any,
        webResults: SearchSourceDto[],
    ): string {
        let summary = '';

        // Add Google Fact Check result
        summary += `Fact-Check Result: ${googleResult.evidenceSummary}\n\n`;

        // Add web sources
        const wikiResults = webResults.filter(r => r.url.includes('wikipedia.org'));
        const otherResults = webResults.filter(r => !r.url.includes('wikipedia.org') && r.isTrusted).slice(0, 2);

        if (wikiResults.length > 0) {
            summary += 'Wikipedia Reference:\n';
            for (const result of wikiResults.slice(0, 2)) {
                summary += `- ${result.title}: ${result.snippet.substring(0, 150)}...\n`;
            }
            summary += '\n';
        }

        if (otherResults.length > 0) {
            summary += 'Additional References:\n';
            for (const result of otherResults) {
                summary += `- ${result.publisher}: ${result.title}\n`;
            }
        }

        summary += `\nVerdict: ${googleResult.status.toUpperCase()}. This claim has been reviewed by fact-checking organizations.`;

        return summary.trim();
    }

    /**
     * Generate evidence summary from web results
     */
    private generateWebEvidenceSummary(
        claim: string,
        webResults: SearchSourceDto[],
        verdict: string,
        googleResult: any,
    ): string {
        let summary = '';

        // Start with Google result if available
        if (googleResult && googleResult.status !== ClaimReviewStatus.UNVERIFIED) {
            summary += `Google Fact Check: ${googleResult.evidenceSummary}\n\n`;
        }

        // Add web search findings
        const wikiResults = webResults.filter(r => r.url.includes('wikipedia.org'));
        const otherTrusted = webResults.filter(r => !r.url.includes('wikipedia.org') && r.isTrusted).slice(0, 2);
        
        if (wikiResults.length > 0) {
            summary += 'Wikipedia Information:\n';
            for (const result of wikiResults.slice(0, 2)) {
                summary += `- ${result.title}: ${result.snippet.substring(0, 200)}...\n`;
            }
            summary += '\n';
        }

        if (otherTrusted.length > 0) {
            summary += 'Additional Sources:\n';
            for (const result of otherTrusted) {
                summary += `- ${result.publisher}: "${result.title}"\n`;
            }
        }

        // Add verdict interpretation
        summary += `\nCombined verdict: ${verdict.toUpperCase()}. `;
        
        switch (verdict) {
            case 'true':
                summary += 'Wikipedia and available sources confirm this claim appears to be accurate.';
                break;
            case 'false':
                summary += 'Evidence suggests this claim is false or misleading.';
                break;
            case 'inconclusive':
                summary += 'Sources provide conflicting information or insufficient evidence to determine accuracy.';
                break;
            case 'unverified':
                summary += 'Wikipedia has information on this topic, but no specific fact-check verdict found.';
                break;
        }

        return summary.trim();
    }

    /**
     * Generate summary when claim is unverified
     */
    private generateUnverifiedSummary(claim: string, googleResult: any): string {
        if (googleResult) {
            return `${googleResult.evidenceSummary}\n\nNo additional web sources found to provide further verification.`;
        }
        return `We could not find any fact-check reviews or reliable sources for this claim: "${claim}". This does not mean the claim is true or false, only that it has not been reviewed by fact-checking organizations or major news outlets.`;
    }

    /**
     * Map ClaimReviewStatus to combined verdict
     */
    private mapStatusToVerdict(status: ClaimReviewStatus): 'true' | 'false' | 'unverified' | 'inconclusive' {
        switch (status) {
            case ClaimReviewStatus.TRUE:
                return 'true';
            case ClaimReviewStatus.FALSE:
                return 'false';
            case ClaimReviewStatus.MIXED:
            case ClaimReviewStatus.PARTLY_TRUE:
                return 'inconclusive';
            case ClaimReviewStatus.UNVERIFIED:
            default:
                return 'unverified';
        }
    }
}
