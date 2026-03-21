import { Controller, Post, Body, HttpCode, HttpStatus } from '@nestjs/common';
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
}
