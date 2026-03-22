import {
    Controller,
    Post,
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
    }> {
        const user = (req as any).user;
        this.logger.log(`Received search request from user: ${user?.userId || 'unknown'}`);
        
        const { claim } = dto;
        
        // Classify the claim and generate optimized query
        const queryResult = this.searchQueryService.classifyAndGenerateQuery(claim);
        
        // Search using the optimized query
        const sources = await this.webScraperService.searchWeb(queryResult.searchQuery);
        
        // Analyze verdict based on sources
        const verdict = this.verdictAnalysisService.analyzeVerdict(claim, sources);
        
        return {
            success: true,
            claim: claim,
            type: queryResult.type,
            searchQuery: queryResult.searchQuery,
            sources,
            verdict,
        };
    }
}
