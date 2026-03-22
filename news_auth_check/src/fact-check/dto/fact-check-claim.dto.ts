import { IsString, IsNotEmpty, IsOptional, MaxLength } from 'class-validator';

/**
 * DTO for fact-check claim request
 * Validates the input claim text to be fact-checked
 */
export class FactCheckClaimDto {
    @IsString()
    @IsNotEmpty({ message: 'Claim text is required' })
    @MaxLength(1000, { message: 'Claim text must not exceed 1000 characters' })
    claim: string;

    @IsString()
    @IsOptional()
    @MaxLength(100, { message: 'Language code must not exceed 100 characters' })
    languageCode?: string;
}
