import { IsOptional, IsString } from 'class-validator';

export class AnonymousSignUpDto {
    @IsOptional()
    @IsString()
    name?: string;
}
