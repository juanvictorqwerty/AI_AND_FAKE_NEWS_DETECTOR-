import {
    Controller,
    Post,
    Patch,
    Get,
    Body,
    UseGuards,
    HttpCode,
    HttpStatus,
} from '@nestjs/common';
import { ProfileService } from './profile.service';
import { JwtAuthGuard } from '../auth/auth.guard';
import { CurrentUser, CurrentUserPayload } from '../auth/current-user.decorator';
import { CompleteProfileDto, EditProfileDto } from './dto';

@Controller('profile')
@UseGuards(JwtAuthGuard)
export class ProfileController {
    constructor(private readonly profileService: ProfileService) {}

    @Get()
    @HttpCode(HttpStatus.OK)
    async getProfile(@CurrentUser('userId') userId: string) {
        try {
            const data = await this.profileService.getProfile(userId);
            return data;
        } catch (error) {
            const message = error.response?.message || error.message || 'Failed to get profile';
            return { success: false, message };
        }
    }

    @Post('complete')
    @HttpCode(HttpStatus.OK)
    async completeProfile(
        @CurrentUser('userId') userId: string,
        @Body() completeProfileDto: CompleteProfileDto,
    ) {
        try {
            const data = await this.profileService.completeProfile(userId, completeProfileDto);
            return data;
        } catch (error) {
            const message = error.response?.message || error.message || 'Failed to complete profile';
            return { success: false, message };
        }
    }

    @Patch('edit')
    @HttpCode(HttpStatus.OK)
    async editProfile(
        @CurrentUser('userId') userId: string,
        @Body() editProfileDto: EditProfileDto,
    ) {
        try {
            const data = await this.profileService.editProfile(userId, editProfileDto);
            return data;
        } catch (error) {
            const message = error.response?.message || error.message || 'Failed to edit profile';
            return { success: false, message };
        }
    }
}
