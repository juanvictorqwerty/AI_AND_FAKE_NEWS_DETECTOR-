import {
    Controller,
    Post,
    Body,
    HttpCode,
    HttpStatus,
    Logger,
} from '@nestjs/common';
import { FactCheckService } from './fact-check.service';
import { FactCheckClaimDto, FactCheckResultDto } from './dto';

/**
 * Controller for fact-checking endpoints
 * Provides API endpoints to verify claims using Google Fact Check Tools
 */
@Controller('fact-check')
export class FactCheckController {
    private readonly logger = new Logger(FactCheckController.name);

    constructor(private readonly factCheckService: FactCheckService) {}

    /**
     * POST /fact-check
     * Fact-check a claim using Google Fact Check Tools API
     * @param factCheckClaimDto - The claim to fact-check
     * @returns FactCheckResultDto with fact-check results
     * 
     * Example Request:
     * POST /fact-check
     * {
     *   "claim": "The Earth is flat",
     *   "languageCode": "en"
     * }
     * 
     * Example Response:
     * {
     *   "success": true,
     *   "claimText": "The Earth is flat",
     *   "status": "false",
     *   "source": "Snopes",
     *   "sourceUrl": "https://www.snopes.com/fact-check/earth-flat/",
     *   "reviewDate": "2023-01-15",
     *   "textualRating": "False",
     *   "claimant": "Flat Earth Society",
     *   "claimDate": "2023-01-01",
     *   "totalReviews": 3,
     *   "allReviews": [...]
     * }
     */
    @Post()
    @HttpCode(HttpStatus.OK)
    async factCheck(
        @Body() factCheckClaimDto: FactCheckClaimDto,
    ): Promise<FactCheckResultDto> {
        this.logger.log(`Received fact-check request`);
        
        const result = await this.factCheckService.factCheckClaim(factCheckClaimDto);
        return result;
    }
}
