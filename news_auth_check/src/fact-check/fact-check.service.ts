import {
    Injectable,
    HttpException,
    HttpStatus,
    Logger,
} from '@nestjs/common';
import axios, { AxiosError } from 'axios';
import {
    FactCheckClaimDto,
    FactCheckResultDto,
    ClaimReviewStatus,
    ClaimReviewDto,
} from './dto';

/**
 * Interface for Google Fact Check API claim review response
 */
interface GoogleClaimReview {
    publisher: {
        name: string;
        site: string;
    };
    url: string;
    title: string;
    reviewDate: string;
    textualRating: string;
}

/**
 * Interface for Google Fact Check API claim response
 */
interface GoogleClaim {
    text: string;
    claimant?: string;
    claimDate?: string;
    claimReview: GoogleClaimReview[];
}

/**
 * Interface for Google Fact Check API response
 */
interface GoogleFactCheckResponse {
    claims?: GoogleClaim[];
    nextPageToken?: string;
}

/**
 * Service for fact-checking claims using Google Fact Check Tools API
 * Provides methods to verify claims and return structured results
 */
@Injectable()
export class FactCheckService {
    private readonly logger = new Logger(FactCheckService.name);
    private readonly apiKey: string;
    private readonly baseUrl = 'https://factchecktools.googleapis.com/v1alpha1/claims:search';

    constructor() {
        this.apiKey = process.env.GOOGLE_FACT_CHECK_API_KEY || '';
        if (!this.apiKey) {
            this.logger.warn('GOOGLE_FACT_CHECK_API_KEY is not set. Fact-checking will fail.');
        }
    }

    /**
     * Fact-check a claim using Google Fact Check Tools API
     * @param factCheckClaimDto - The claim to fact-check
     * @returns FactCheckResultDto with the fact-check results
     */
    async factCheckClaim(
        factCheckClaimDto: FactCheckClaimDto,
    ): Promise<FactCheckResultDto> {
        const { claim, languageCode = 'en' } = factCheckClaimDto;

        try {
            this.logger.log(`Fact-checking claim: "${claim.substring(0, 100)}..."`);

            const response = await axios.get<GoogleFactCheckResponse>(
                this.baseUrl,
                {
                    params: {
                        key: this.apiKey,
                        query: claim,
                        languageCode: languageCode,
                    },
                    timeout: 10000, // 10 second timeout
                },
            );

            const data = response.data;

            if (!data.claims || data.claims.length === 0) {
                this.logger.log('No fact-check results found for the claim');
                return {
                    success: true,
                    claimText: claim,
                    status: ClaimReviewStatus.UNVERIFIED,
                    source: 'No fact-check found',
                    sourceUrl: '',
                    reviewDate: '',
                    textualRating: 'No fact-check available for this claim',
                    evidenceSummary: 'We could not find any fact-check reviews for this claim. This does not mean the claim is true or false, just that it has not been reviewed by fact-checking organizations yet.',
                    totalReviews: 0,
                    message: 'No fact-check results found for this claim',
                };
            }

            // Process the first claim (most relevant)
            const firstClaim = data.claims[0];
            const reviews = this.mapClaimReviews(firstClaim.claimReview);
            const topReview = reviews[0];

            this.logger.log(`Found ${reviews.length} fact-check reviews`);

            // Generate user-friendly evidence summary
            const evidenceSummary = this.generateEvidenceSummary(firstClaim, reviews);

            return {
                success: true,
                claimText: firstClaim.text || claim,
                status: topReview.status,
                source: topReview.publisher,
                sourceUrl: topReview.url,
                reviewDate: topReview.reviewDate,
                textualRating: topReview.textualRating,
                evidenceSummary,
                claimant: firstClaim.claimant,
                claimDate: firstClaim.claimDate,
                totalReviews: reviews.length,
                allReviews: reviews,
            };
        } catch (error) {
            return this.handleError(error, claim);
        }
    }

    /**
     * Map Google claim reviews to our DTO format
     */
    private mapClaimReviews(
        claimReviews: GoogleClaimReview[],
    ): ClaimReviewDto[] {
        return claimReviews.map((review) => ({
            publisher: review.publisher?.name || 'Unknown',
            url: review.url || '',
            title: review.title || '',
            reviewDate: review.reviewDate || '',
            textualRating: review.textualRating || 'Unknown',
            status: this.mapTextualRatingToStatus(review.textualRating),
        }));
    }

    /**
     * Map textual rating to standardized status (true / false / unverified)
     * Uses comprehensive keyword matching to determine verdict
     */
    private mapTextualRatingToStatus(
        textualRating: string | undefined,
    ): ClaimReviewStatus {
        if (!textualRating) {
            return ClaimReviewStatus.UNVERIFIED;
        }

        const rating = textualRating.toLowerCase();

        // FALSE indicators - comprehensive list of false/untrue ratings
        const falseIndicators = [
            'false', 'fake', 'incorrect', 'not true', 'misleading',
            'untrue', 'fabricated', 'hoax', 'fiction', 'wrong',
            'inaccurate', 'debunked', 'no evidence', 'baseless',
            'contradicted', 'refuted', 'disproven', 'pants on fire',
            'mostly false', 'four pinocchios', 'not accurate',
        ];

        // TRUE indicators - comprehensive list of true/correct ratings
        const trueIndicators = [
            'true', 'correct', 'accurate', 'confirmed', 'verified',
            'authentic', 'genuine', 'real', 'substantiated',
            'mostly true', 'true but', 'largely accurate',
        ];

        // Check for false indicators first (more specific)
        for (const indicator of falseIndicators) {
            if (rating.includes(indicator)) {
                // Make sure it's not a negation like "not false" = true
                if (!this.isNegated(rating, indicator)) {
                    return ClaimReviewStatus.FALSE;
                }
            }
        }

        // Check for true indicators
        for (const indicator of trueIndicators) {
            if (rating.includes(indicator)) {
                // Make sure it's not a negation like "not true" = false
                if (!this.isNegated(rating, indicator)) {
                    return ClaimReviewStatus.TRUE;
                }
            }
        }

        return ClaimReviewStatus.UNVERIFIED;
    }

    /**
     * Check if a keyword is negated in the rating text
     * e.g., "not true" should not match as true
     */
    private isNegated(text: string, keyword: string): boolean {
        const negations = ['not', 'no', 'never', "n't", 'hardly', 'barely', 'scarcely'];
        const index = text.indexOf(keyword);
        
        if (index === -1) return false;

        // Check the 20 characters before the keyword for negations
        const beforeText = text.substring(Math.max(0, index - 20), index);
        return negations.some(neg => beforeText.includes(neg));
    }

    /**
     * Generate a user-friendly summary of the fact-check evidence
     */
    private generateEvidenceSummary(
        claim: GoogleClaim,
        reviews: ClaimReviewDto[],
    ): string {
        if (!reviews || reviews.length === 0) {
            return 'No fact-check reviews available for this claim.';
        }

        const mainReview = reviews[0];
        const status = mainReview.status;
        const publisher = mainReview.publisher;
        
        // Build summary based on status
        let summary = '';
        
        if (status === ClaimReviewStatus.FALSE) {
            summary = `This claim has been rated as **FALSE** by ${publisher}. `;
            summary += this.extractKeyEvidence(mainReview.textualRating);
        } else if (status === ClaimReviewStatus.TRUE) {
            summary = `This claim has been verified as **TRUE** by ${publisher}. `;
            summary += this.extractKeyEvidence(mainReview.textualRating);
        } else {
            summary = `${publisher} reviewed this claim. `;
            summary += this.extractKeyEvidence(mainReview.textualRating);
        }

        // Add multiple sources note if applicable
        if (reviews.length > 1) {
            const otherPublishers = reviews
                .slice(1, 3)
                .map(r => r.publisher)
                .join(', ');
            summary += ` Additional verification from ${otherPublishers}.`;
        }

        return summary;
    }

    /**
     * Extract and clean key evidence from textual rating
     */
    private extractKeyEvidence(textualRating: string): string {
        if (!textualRating) return '';

        // Clean up the evidence text
        let evidence = textualRating
            .replace(/\s+/g, ' ')
            .trim();

        // If too long, truncate intelligently
        if (evidence.length > 200) {
            const sentences = evidence.match(/[^.!?]+[.!?]+/g) || [evidence];
            evidence = sentences.slice(0, 2).join(' ').trim();
            if (evidence.length > 200) {
                evidence = evidence.substring(0, 197) + '...';
            }
        }

        return evidence;
    }

    /**
     * Handle errors from the API call
     */
    private handleError(
        error: unknown,
        claim: string,
    ): FactCheckResultDto {
        if (axios.isAxiosError(error)) {
            const axiosError = error as AxiosError;

            // Handle rate limiting
            if (axiosError.response?.status === 429) {
                this.logger.error('Rate limit exceeded for Google Fact Check API');
                throw new HttpException(
                    {
                        success: false,
                        message: 'Rate limit exceeded. Please try again later.',
                        errorCode: 'RATE_LIMIT_EXCEEDED',
                    },
                    HttpStatus.TOO_MANY_REQUESTS,
                );
            }

            // Handle invalid API key
            if (axiosError.response?.status === 403) {
                this.logger.error('Invalid API key for Google Fact Check API');
                throw new HttpException(
                    {
                        success: false,
                        message: 'Invalid API key. Please check your configuration.',
                        errorCode: 'INVALID_API_KEY',
                    },
                    HttpStatus.FORBIDDEN,
                );
            }

            // Handle other API errors
            this.logger.error(
                `Google Fact Check API error: ${axiosError.message}`,
                axiosError.stack,
            );
            throw new HttpException(
                {
                    success: false,
                    message: 'Failed to fact-check claim. Please try again later.',
                    errorCode: 'API_ERROR',
                },
                HttpStatus.BAD_GATEWAY,
            );
        }

        // Handle unexpected errors
        this.logger.error(
            `Unexpected error during fact-check: ${error}`,
        );
        throw new HttpException(
            {
                success: false,
                message: 'An unexpected error occurred. Please try again later.',
                errorCode: 'INTERNAL_ERROR',
            },
            HttpStatus.INTERNAL_SERVER_ERROR,
        );
    }
}
