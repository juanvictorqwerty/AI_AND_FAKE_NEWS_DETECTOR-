import { Module } from '@nestjs/common';
import { FactCheckController } from './fact-check.controller';
import { WebScraperService } from './web-scraper.service';
import { SearchQueryService } from './search-query.service';
import { AuthModule } from '../auth/auth.module';

/**
 * FactCheckModule - Provides web search fact-checking capabilities
 * 
 * Features:
 * - Web scraping with trusted source filtering
 * - Automatic search query generation with claim classification
 * - Claim type detection (fact, news, controversial)
 * 
 * Endpoints:
 * - POST /fact-check/search - Search web for sources with claim classification
 * 
 * Authentication:
 * All endpoints require a valid JWT token in the Authorization header.
 * Format: Authorization: Bearer <token>
 * 
 * Environment Variables:
 * - SERP_API_KEY - For SerpAPI search (optional)
 * - GOOGLE_SEARCH_API_KEY - For Google Custom Search (optional)
 * - GOOGLE_SEARCH_ENGINE_ID - For Google Custom Search (optional)
 */
@Module({
    imports: [AuthModule],
    controllers: [FactCheckController],
    providers: [
        WebScraperService,
        SearchQueryService,
    ],
    exports: [WebScraperService, SearchQueryService],
})
export class FactCheckModule {}
