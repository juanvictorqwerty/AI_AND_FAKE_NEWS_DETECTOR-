/**
 * Enum representing possible fact-check review statuses
 */
export enum ClaimReviewStatus {
    TRUE = 'true',
    FALSE = 'false',
    MIXED = 'mixed',
    UNVERIFIED = 'unverified',
    PARTLY_TRUE = 'partly_true',
}

/**
 * DTO for individual claim review from a fact-checker
 */
export class ClaimReviewDto {
    publisher: string;
    url: string;
    title: string;
    reviewDate: string;
    textualRating: string;
    status: ClaimReviewStatus;
}

/**
 * DTO for a single claim with its reviews
 */
export class ClaimDto {
    text: string;
    claimant: string;
    claimDate: string;
    reviews: ClaimReviewDto[];
}

/**
 * DTO for fact-check response
 * Contains the structured result from Google Fact Check Tools API
 */
export class FactCheckResultDto {
    success: boolean;
    claimText: string;
    status: ClaimReviewStatus;
    source: string;
    sourceUrl: string;
    reviewDate: string;
    textualRating: string;
    evidenceSummary: string;
    claimant?: string;
    claimDate?: string;
    totalReviews: number;
    allReviews?: ClaimReviewDto[];
    message?: string;
}

/**
 * DTO for error response
 */
export class FactCheckErrorDto {
    success: false;
    message: string;
    errorCode?: string;
}
