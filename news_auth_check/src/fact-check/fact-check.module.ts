import { Module } from '@nestjs/common';
import { FactCheckController } from './fact-check.controller';
import { FactCheckService } from './fact-check.service';

/**
 * FactCheckModule - Provides fact-checking capabilities using Google Fact Check Tools API
 * 
 * This module exports:
 * - FactCheckController: Handles HTTP requests for fact-checking
 * - FactCheckService: Business logic for interacting with Google Fact Check API
 * 
 * Usage:
 * Import this module in your AppModule to enable fact-checking endpoints.
 * Ensure GOOGLE_FACT_CHECK_API_KEY is set in your environment variables.
 */
@Module({
    controllers: [FactCheckController],
    providers: [FactCheckService],
    exports: [FactCheckService],
})
export class FactCheckModule {}
