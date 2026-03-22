import { Injectable, Logger } from '@nestjs/common';
import { SearchSourceDto } from './dto';

/**
 * Verdict analysis result
 */
export interface VerdictResult {
    verdict: 'true' | 'false' | 'unverified';
    confidence: 'low' | 'medium' | 'high';
    reason: string;
    usedSources: {
        title: string;
        justification: string;
    }[];
}

/**
 * Service to analyze search results and determine verdict
 * Uses the provided sources to verify or refute claims
 */
@Injectable()
export class VerdictAnalysisService {
    private readonly logger = new Logger(VerdictAnalysisService.name);

    // Keywords that indicate truth/verification
    private readonly trueIndicators = [
        'true', 'confirmed', 'verified', 'accurate', 'correct',
        'fact', 'yes', 'real', 'actual', 'official', 'official statement',
        'debunked false', 'myth confirmed', 'is true', 'are true'
    ];

    // Keywords that indicate falsehood
    private readonly falseIndicators = [
        'false', 'fake', 'hoax', 'myth', 'lie', 'untrue', 'incorrect',
        'not true', 'not accurate', 'debunked', 'misinformation',
        'disinformation', 'fabricated', 'unverified claim', 'no evidence',
        'not confirmed', 'denied', 'rejected', 'scam', 'fraud'
    ];

    // Keywords that indicate unverified/ongoing
    private readonly unverifiedIndicators = [
        'unverified', 'unclear', 'unconfirmed', 'investigating',
        'developing', 'unknown', 'uncertain', 'pending', 'no information',
        'cannot verify', 'could not confirm', 'no comment'
    ];

    /**
     * Analyze claim against search results and determine verdict
     * 
     * @param claim - The original claim to verify
     * @param sources - Array of search results (trusted sources preferred)
     * @returns VerdictResult with verdict, confidence, reason, and sources
     */
    analyzeVerdict(claim: string, sources: SearchSourceDto[]): VerdictResult {
        this.logger.log(`Analyzing verdict for claim: "${claim.substring(0, 50)}..."`);
        
        if (!sources || sources.length === 0) {
            return {
                verdict: 'unverified',
                confidence: 'low',
                reason: 'No sources available to verify this claim.',
                usedSources: [],
            };
        }

        // Sort sources by trust (trusted first)
        const sortedSources = [...sources].sort((a, b) => 
            (b.isTrusted ? 1 : 0) - (a.isTrusted ? 1 : 0)
        );

        // Analyze each source
        const analysis = this.analyzeSources(claim, sortedSources);

        // Determine final verdict based on analysis
        return this.determineVerdict(claim, analysis, sortedSources);
    }

    /**
     * Analyze each source for truth indicators
     */
    private analyzeSources(
        claim: string,
        sources: SearchSourceDto[]
    ): { trueScore: number; falseScore: number; sourceCount: number } {
        let trueScore = 0;
        let falseScore = 0;
        let sourceCount = 0;

        const claimLower = claim.toLowerCase();
        
        // Extract key terms from claim for matching
        const keyTerms = this.extractKeyTerms(claim);

        for (const source of sources) {
            sourceCount++;
            const text = `${source.title} ${source.snippet}`.toLowerCase();
            const weight = source.isTrusted ? 2 : 1; // Weight trusted sources more

            // Check if source is related to the claim
            const isRelated = this.isSourceRelated(keyTerms, text);
            
            if (!isRelated) {
                continue; // Skip unrelated sources
            }

            // Count true indicators
            for (const indicator of this.trueIndicators) {
                if (text.includes(indicator)) {
                    trueScore += weight;
                }
            }

            // Count false indicators
            for (const indicator of this.falseIndicators) {
                if (text.includes(indicator)) {
                    falseScore += weight;
                }
            }

            // Count unverified indicators
            for (const indicator of this.unverifiedIndicators) {
                if (text.includes(indicator)) {
                    // Reduce both true and false scores
                    trueScore = Math.max(0, trueScore - weight * 0.5);
                    falseScore = Math.max(0, falseScore - weight * 0.5);
                }
            }
        }

        return { trueScore, falseScore, sourceCount };
    }

    /**
     * Determine final verdict based on analysis
     */
    private determineVerdict(
        claim: string,
        analysis: { trueScore: number; falseScore: number; sourceCount: number },
        sources: SearchSourceDto[]
    ): VerdictResult {
        const { trueScore, falseScore, sourceCount } = analysis;
        
        // Collect used sources
        const usedSources: { title: string; justification: string }[] = [];
        const claimLower = claim.toLowerCase();
        const keyTerms = this.extractKeyTerms(claim);

        for (const source of sources) {
            const text = `${source.title} ${source.snippet}`.toLowerCase();
            if (this.isSourceRelated(keyTerms, text)) {
                let justification = 'Related source found';
                
                // Add specific justification based on content
                if (this.trueIndicators.some(i => text.includes(i))) {
                    justification = 'Source confirms or verifies the claim';
                } else if (this.falseIndicators.some(i => text.includes(i))) {
                    justification = 'Source contradicts or debunks the claim';
                } else if (this.unverifiedIndicators.some(i => text.includes(i))) {
                    justification = 'Source indicates unverified status';
                }

                usedSources.push({
                    title: source.title,
                    justification,
                });

                if (usedSources.length >= 3) break; // Limit to 3 sources
            }
        }

        // Determine verdict
        const totalScore = trueScore + falseScore;
        
        if (totalScore === 0 || sourceCount === 0) {
            return {
                verdict: 'unverified',
                confidence: 'low',
                reason: 'No definitive sources found to verify or refute this claim.',
                usedSources,
            };
        }

        // Calculate confidence based on score difference
        const scoreDiff = Math.abs(trueScore - falseScore);
        const maxScore = Math.max(trueScore, falseScore);
        
        let confidence: 'low' | 'medium' | 'high';
        const ratio = scoreDiff / maxScore;

        if (ratio >= 2 && maxScore >= 4) {
            confidence = 'high';
        } else if (ratio >= 1 && maxScore >= 2) {
            confidence = 'medium';
        } else {
            confidence = 'low';
        }

        // Determine verdict
        if (trueScore > falseScore * 1.5) {
            return {
                verdict: 'true',
                confidence,
                reason: `Multiple sources ${sources[0]?.isTrusted ? 'from trusted sources' : ''} confirm this claim.`,
                usedSources,
            };
        } else if (falseScore > trueScore * 1.5) {
            return {
                verdict: 'false',
                confidence,
                reason: `Multiple sources ${sources[0]?.isTrusted ? 'from trusted sources' : ''} contradict this claim.`,
                usedSources,
            };
        } else {
            return {
                verdict: 'unverified',
                confidence: 'low',
                reason: 'Sources provide conflicting or insufficient information.',
                usedSources,
            };
        }
    }

    /**
     * Extract key terms from claim for matching
     */
    private extractKeyTerms(claim: string): string[] {
        // Remove common words
        const stopWords = ['the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
            'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could', 'should',
            'may', 'might', 'must', 'shall', 'can', 'to', 'of', 'in', 'for', 'on', 'with',
            'at', 'by', 'from', 'as', 'into', 'through', 'during', 'before', 'after',
            'above', 'below', 'between', 'under', 'again', 'further', 'then', 'once',
            'that', 'this', 'these', 'those', 'it', 'its'];
        
        const words = claim.toLowerCase()
            .replace(/[^\w\s]/g, '')
            .split(/\s+/)
            .filter(w => w.length > 2 && !stopWords.includes(w));
        
        return [...new Set(words)];
    }

    /**
     * Check if a source is related to the claim
     */
    private isSourceRelated(keyTerms: string[], sourceText: string): boolean {
        if (keyTerms.length === 0) return true;
        
        // Check if at least one key term appears in source
        const matchCount = keyTerms.filter(term => sourceText.includes(term)).length;
        
        // Consider related if at least 30% of key terms are found
        return matchCount >= Math.max(1, Math.floor(keyTerms.length * 0.3));
    }
}
