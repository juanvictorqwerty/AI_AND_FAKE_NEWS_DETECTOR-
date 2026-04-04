import {
    Controller,
    Post,
    Get,
    Body,
    HttpCode,
    HttpStatus,
    Logger,
    UseGuards,
    Req,
} from '@nestjs/common';
import type { Request } from 'express';
import { WebScraperService } from './web-scraper.service';
import { SearchQueryService } from './search-query.service';
import { VerdictAnalysisService, VerdictResult } from './verdict-analysis.service';
import { FactCheckStorageService, FactCheckResult } from './fact-check-storage.service';
import { MediaStorageService, MediaCheckResult } from './media-storage.service';
import { SearchSourceDto, ClaimType } from './dto';
import { JwtAuthGuard } from '../auth/auth.guard';

/**
 * Controller for fact-checking endpoints
 * Provides API endpoints to verify claims using web search with verdict analysis
 * 
 * Only /fact-check/search endpoint is available.
 * Requires JWT authentication.
 * Include the token in the Authorization header: Bearer <token>
 */
@Controller('fact-check')
@UseGuards(JwtAuthGuard)
export class FactCheckController {
    private readonly logger = new Logger(FactCheckController.name);

    constructor(
        private readonly webScraperService: WebScraperService,
        private readonly searchQueryService: SearchQueryService,
        private readonly verdictAnalysisService: VerdictAnalysisService,
        private readonly factCheckStorageService: FactCheckStorageService,
        private readonly mediaStorageService: MediaStorageService,
    ) {}

    /**
     * POST /fact-check/search
     * Search the web for fact-check sources and analyze verdict
     * 
     * Example Request:
     * POST /fact-check/search
     * Authorization: Bearer <your-jwt-token>
     * {
     *   "claim": "the strait of hormuz is closed"
     * }
     * 
     * Example Response:
     * {
     *   "success": true,
     *   "claim": "the strait of hormuz is closed",
     *   "type": "news",
     *   "searchQuery": "strait of hormuz closed news report",
     *   "sources": [...],
     *   "verdict": {
     *     "verdict": "unverified",
     *     "confidence": "low",
     *     "reason": "No definitive sources found to verify or refute this claim.",
     *     "usedSources": [...]
     *   }
     * }
     */
    @Post('search')
    @HttpCode(HttpStatus.OK)
    async searchFactCheck(
        @Body() dto: { claim: string },
        @Req() req: Request,
    ): Promise<{
        success: boolean;
        claim: string;
        type: ClaimType;
        searchQuery: string;
        sources: SearchSourceDto[];
        verdict: VerdictResult;
        stored: boolean;
    }> {
        const user = (req as any).user;
        this.logger.log(`Received search request from user: ${user?.userId || 'unknown'}`);
        
        const { claim } = dto;
        
        // Classify the claim and generate optimized query
        const queryResult = this.searchQueryService.classifyAndGenerateQuery(claim);
        
        // Search using the optimized query
        const sources = await this.webScraperService.searchWeb(queryResult.searchQuery);
        
        // Analyze verdict based on sources
        const verdict = await this.verdictAnalysisService.analyzeVerdict(claim, sources);
        
        // Create the fact-check result object
        const factCheckResult: FactCheckResult = {
            id: crypto.randomUUID(),
            claim: claim,
            verdict: verdict.verdict,
            confidence: verdict.confidence,
            reason: verdict.reason,
            sources: sources.map(s => s.url),
            createdAt: new Date().toISOString(),
        };
        
        // Store the fact-check result in the database
        let stored = false;
        try {
            if (user?.userId) {
                await this.factCheckStorageService.storeFactCheckResult(
                    user.userId,
                    factCheckResult,
                );
                stored = true;
                this.logger.log(`Successfully stored fact-check result for user ${user.userId}`);
            } else {
                this.logger.warn('User ID not found, skipping storage');
            }
        } catch (error) {
            this.logger.error(`Failed to store fact-check result: ${error.message}`);
            // Don't fail the request if storage fails, just log the error
        }
        
        return {
            success: true,
            claim: claim,
            type: queryResult.type,
            searchQuery: queryResult.searchQuery,
            sources,
            verdict,
            stored,
        };
    }

    /**
     * GET /fact-check/history
     * Retrieve all fact-check results for the authenticated user
     *
     * Example Request:
     * GET /fact-check/history
     * Authorization: Bearer <your-jwt-token>
     *
     * Example Response:
     * {
     *   "success": true,
     *   "count": 5,
     *   "results": [
     *     {
     *       "id": "uuid",
     *       "claim": "the strait of hormuz is closed",
     *       "verdict": "unverified",
     *       "confidence": "low",
     *       "reason": "No definitive sources found...",
     *       "sources": [...],
     *       "createdAt": "2024-01-01T00:00:00.000Z"
     *     },
     *     ...
     *   ]
     * }
     */
    @Get('history')
    @HttpCode(HttpStatus.OK)
    async getHistory(@Req() req: Request): Promise<{
        success: boolean;
        count: number;
        results: FactCheckResult[];
    }> {
        const user = (req as any).user;
        this.logger.log(`Retrieving fact-check history for user: ${user?.userId || 'unknown'}`);
        
        if (!user?.userId) {
            this.logger.warn('User ID not found');
            return {
                success: false,
                count: 0,
                results: [],
            };
        }
        
        try {
            const results = await this.factCheckStorageService.getFactCheckResults(user.userId);
            
            this.logger.log(`Retrieved ${results.length} fact-check results for user ${user.userId}`);
            
            return {
                success: true,
                count: results.length,
                results,
            };
        } catch (error) {
            this.logger.error(`Failed to retrieve fact-check history: ${error.message}`);
            return {
                success: false,
                count: 0,
                results: [],
            };
        }
    }

    /**
     * GET /fact-check/media-history
     * Retrieve all media check results for the authenticated user
     *
     * Example Request:
     * GET /fact-check/media-history
     * Authorization: Bearer <your-jwt-token>
     *
     * Example Response:
     * {
     *   "success": true,
     *   "count": 3,
     *   "results": [
     *     {
     *       "id": "uuid",
     *       "isPhoto": true,
     *       "isVideo": false,
     *       "urlList": ["https://example.com/image.jpg"],
     *       "score": 85,
     *       "createdAt": "2024-01-01T00:00:00.000Z"
     *     },
     *     ...
     *   ]
     * }
     */
    @Get('media-history')
    @HttpCode(HttpStatus.OK)
    async getMediaHistory(@Req() req: Request): Promise<{
        success: boolean;
        count: number;
        results: MediaCheckResult[];
    }> {
        const user = (req as any).user;
        this.logger.log(`Retrieving media check history for user: ${user?.userId || 'unknown'}`);

        if (!user?.userId) {
            this.logger.warn('User ID not found');
            return {
                success: false,
                count: 0,
                results: [],
            };
        }

        try {
            const results = await this.mediaStorageService.getMediaCheckResults(user.userId);

            this.logger.log(`Retrieved ${results.length} media check results for user ${user.userId}`);

            return {
                success: true,
                count: results.length,
                results,
            };
        } catch (error) {
            this.logger.error(`Failed to retrieve media check history: ${error.message}`);
            return {
                success: false,
                count: 0,
                results: [],
            };
        }
    }
}