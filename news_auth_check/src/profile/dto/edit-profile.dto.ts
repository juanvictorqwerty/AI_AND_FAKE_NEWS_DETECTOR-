import { IsEmail, IsString, MinLength, IsOptional } from 'class-validator';

export class EditProfileDto {
    @IsEmail()
    @IsOptional()
    email?: string;

    @IsString()
    @MinLength(6)
    @IsOptional()
    password?: string;

    @IsString()
    @IsOptional()
    name?: string;
}
