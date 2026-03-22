import { IsString, IsNotEmpty, MaxLength, IsOptional, IsArray } from 'class-validator';

// Claim type for classification
export type ClaimType = 'fact' | 'news' | 'controversial';

/**
 * DTO for search-based fact-check request
 */
export class SearchFactCheckDto {
    @IsString()
    @IsNotEmpty({ message: 'Claim text is required' })
    @MaxLength(1000, { message: 'Claim must not exceed 1000 characters' })
    claim: string;

    @IsString()
    @IsOptional()
    @MaxLength(10, { message: 'Language code must not exceed 10 characters' })
    languageCode?: string;

    @IsOptional()
    @IsArray()
    preferredSources?: string[];
}

/**
 * DTO for a single search result source
 */
export class SearchSourceDto {
    title: string;
    url: string;
    date: string;
    snippet: string;
    publisher: string;
    isTrusted: boolean;
}

/**
 * DTO for search-based fact-check response
 */
export class SearchFactCheckResultDto {
    success: boolean;
    claimText: string;
    claimType?: 'fact' | 'news' | 'controversial';
    searchQuery: string;
    googleFactCheckResult?: {
        found: boolean;
        status?: string;
        source?: string;
        sourceUrl?: string;
        reviewDate?: string;
        textualRating?: string;
    };
    webSearchResults: SearchSourceDto[];
    combinedVerdict: 'true' | 'false' | 'unverified' | 'inconclusive';
    evidenceSummary: string;
    totalSources: number;
    trustedSourcesCount: number;
    message?: string;
}

/**
 * DTO for hybrid fact-check request (combines both Google API and web search)
 */
export class HybridFactCheckDto {
    @IsString()
    @IsNotEmpty({ message: 'Claim text is required' })
    @MaxLength(1000, { message: 'Claim must not exceed 1000 characters' })
    claim: string;

    @IsString()
    @IsOptional()
    @MaxLength(10, { message: 'Language code must not exceed 10 characters' })
    languageCode?: string;

    @IsOptional()
    skipWebSearch?: boolean;
}
