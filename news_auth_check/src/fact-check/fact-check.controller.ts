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
import { FactCheckService } from './fact-check.service';
import { HybridFactCheckService } from './hybrid-fact-check.service';
import { WebScraperService } from './web-scraper.service';
import {
    FactCheckClaimDto,
    FactCheckResultDto,
    HybridFactCheckDto,
    SearchFactCheckResultDto,
    SearchSourceDto,
} from './dto';
import { JwtAuthGuard } from '../auth/auth.guard';

/**
 * Controller for fact-checking endpoints
 * Provides API endpoints to verify claims using Google Fact Check Tools
 * 
 * All endpoints require JWT authentication.
 * Include the token in the Authorization header: Bearer <token>
 */
@Controller('fact-check')
@UseGuards(JwtAuthGuard)
export class FactCheckController {
    private readonly logger = new Logger(FactCheckController.name);

    constructor(
        private readonly factCheckService: FactCheckService,
        private readonly hybridFactCheckService: HybridFactCheckService,
        private readonly webScraperService: WebScraperService,
    ) {}

    /**
     * POST /fact-check
     * Fact-check a claim using Google Fact Check Tools API only
     * Requires valid JWT token in Authorization header
     * 
     * @param factCheckClaimDto - The claim to fact-check
     * @param req - Express request object with user info
     * @returns FactCheckResultDto with fact-check results
     */
    @Post()
    @HttpCode(HttpStatus.OK)
    async factCheck(
        @Body() factCheckClaimDto: FactCheckClaimDto,
        @Req() req: Request,
    ): Promise<FactCheckResultDto> {
        const user = (req as any).user;
        this.logger.log(`Received fact-check request from user: ${user?.userId || 'unknown'}`);
        
        const result = await this.factCheckService.factCheckClaim(factCheckClaimDto);
        return result;
    }

    /**
     * POST /fact-check/hybrid
     * Hybrid fact-checking combining Google Fact Check API + Web Search
     * First checks Google API, if unverified, searches the web for additional sources
     * 
     * Example Request:
     * POST /fact-check/hybrid
     * Authorization: Bearer <your-jwt-token>
     * {
     *   "claim": "The Earth is flat",
     *   "languageCode": "en",
     *   "skipWebSearch": false
     * }
     * 
     * Example Response:
     * {
     *   "success": true,
     *   "claimText": "The Earth is flat",
     *   "searchQuery": "The Earth is flat fact check",
     *   "googleFactCheckResult": { ... },
     *   "webSearchResults": [...],
     *   "combinedVerdict": "false",
     *   "evidenceSummary": "...",
     *   "totalSources": 5,
     *   "trustedSourcesCount": 3
     * }
     */
    @Post('hybrid')
    @HttpCode(HttpStatus.OK)
    async hybridFactCheck(
        @Body() dto: HybridFactCheckDto,
        @Req() req: Request,
    ): Promise<SearchFactCheckResultDto> {
        const user = (req as any).user;
        this.logger.log(`Received hybrid fact-check request from user: ${user?.userId || 'unknown'}`);
        
        const result = await this.hybridFactCheckService.hybridFactCheck(dto);
        return result;
    }

    /**
     * POST /fact-check/search
     * Search the web for fact-check sources
     * Returns search results from trusted sources only
     * 
     * Example Request:
     * POST /fact-check/search
     * Authorization: Bearer <your-jwt-token>
     * {
     *   "claim": "The Earth is flat"
     * }
     */
    @Post('search')
    @HttpCode(HttpStatus.OK)
    async searchFactCheck(
        @Body('claim') claim: string,
        @Req() req: Request,
    ): Promise<{ success: boolean; query: string; results: SearchSourceDto[] }> {
        const user = (req as any).user;
        this.logger.log(`Received search request from user: ${user?.userId || 'unknown'}`);
        
        const results = await this.webScraperService.searchWeb(claim);
        
        return {
            success: true,
            query: claim,
            results,
        };
    }
}
