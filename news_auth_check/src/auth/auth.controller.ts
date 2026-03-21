import { Controller, Post, Body, HttpCode, HttpStatus, Headers, UnauthorizedException } from '@nestjs/common';
import { AuthService } from './auth.service';
import { SignUpDto, SignInDto, AnonymousSignUpDto } from './dto';

@Controller('auth')
export class AuthController {
    constructor(private readonly authService: AuthService) {}

    @Post('signup')
    async signUp(@Body() signUpDto: SignUpDto) {
        try {
            const data = await this.authService.signUp(signUpDto);
            return { success: true, ...data };
        } catch (error) {
            const message = error.response?.message || error.message || 'Signup failed';
            return { success: false, message };
        }
    }

    @Post('signin')
    @HttpCode(HttpStatus.OK)
    async signIn(@Body() signInDto: SignInDto) {
        try {
            const data = await this.authService.signIn(signInDto);
            return { success: true, ...data };
        } catch (error) {
            const message = error.response?.message || error.message || 'Login failed';
            return { success: false, message };
        }
    }

    @Post('anonymous-signup')
    async signUpAnonymous(@Body() anonymousSignUpDto: AnonymousSignUpDto) {
        try {
            const data = await this.authService.signUpAnonymous(anonymousSignUpDto);
            return { success: true, ...data };
        } catch (error) {
            const message = error.response?.message || error.message || 'Anonymous signup failed';
            return { success: false, message };
        }
    }

    @Post('logout')
    @HttpCode(HttpStatus.OK)
    async logout(@Headers('authorization') authHeader: string) {
        try {
            if (!authHeader) {
                throw new UnauthorizedException('No authorization header provided');
            }

            const [type, token] = authHeader.split(' ');
            if (type !== 'Bearer' || !token) {
                throw new UnauthorizedException('Invalid authorization header format');
            }

            const revoked = await this.authService.revokeToken(token);

            if (!revoked) {
                return { success: false, message: 'Failed to logout' };
            }

            return { success: true, message: 'Logged out successfully' };
        } catch (error) {
            const message = error.response?.message || error.message || 'Logout failed';
            return { success: false, message };
        }
    }
}
