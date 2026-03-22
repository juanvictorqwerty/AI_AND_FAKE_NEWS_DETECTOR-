import { Module } from '@nestjs/common';
import { FactCheckController } from './fact-check.controller';
import { FactCheckService } from './fact-check.service';
import { HybridFactCheckService } from './hybrid-fact-check.service';
import { WebScraperService } from './web-scraper.service';
import { SearchQueryService } from './search-query.service';
import { AuthModule } from '../auth/auth.module';

/**
 * FactCheckModule - Provides comprehensive fact-checking capabilities
 * 
 * Features:
 * - Google Fact Check Tools API integration
 * - Hybrid fact-checking (Google API + Web Search)
 * - Web scraping with trusted source filtering
 * - Automatic search query generation
 * - Caching and rate limiting
 * 
 * Endpoints:
 * - POST /fact-check - Check via Google Fact Check API only
 * - POST /fact-check/hybrid - Combined Google API + Web Search
 * - POST /fact-check/search - Search web for sources
 * 
 * Authentication:
 * All endpoints require a valid JWT token in the Authorization header.
 * Format: Authorization: Bearer <token>
 * 
 * Environment Variables:
 * - GOOGLE_FACT_CHECK_API_KEY - For Google Fact Check API
 * - GOOGLE_SEARCH_API_KEY - For Google Custom Search (optional)
 * - GOOGLE_SEARCH_ENGINE_ID - For Google Custom Search (optional)
 * - SERP_API_KEY - Alternative search API (optional)
 */
@Module({
    imports: [AuthModule],
    controllers: [FactCheckController],
    providers: [
        FactCheckService,
        HybridFactCheckService,
        WebScraperService,
        SearchQueryService,
    ],
    exports: [FactCheckService, HybridFactCheckService],
})
export class FactCheckModule {}
