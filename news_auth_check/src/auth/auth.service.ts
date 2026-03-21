import { Injectable, UnauthorizedException, ConflictException } from '@nestjs/common';
import { UsersService } from '../users/users.service';
import { SignUpDto, SignInDto, AnonymousSignUpDto } from './dto';
import { DatabaseService } from '../db/database.service';
import * as schema from '../db/schema';
import { sql } from 'drizzle-orm';
import * as bcrypt from 'bcryptjs';
import * as jwt from 'jsonwebtoken';

@Injectable()
export class AuthService {
    private readonly jwtSecret = process.env.JWT_SECRET || 'your-secret-key';
    private readonly jwtExpiresIn = '7d';

    constructor(
        private readonly usersService: UsersService,
        private readonly db: DatabaseService,
    ) {}

    async signUp(signUpDto: SignUpDto) {
        const { email, password, name } = signUpDto;

        // Check if user already exists
        const existingUser = await this.usersService.findByEmail(email);
        if (existingUser) {
            throw new ConflictException('Email already exists');
        }

        // Hash password
        const hashedPassword = await bcrypt.hash(password, 10);

        // Create user
        const user = await this.usersService.create(email, hashedPassword, name);

        if (!user.id || !user.email) {
            throw new Error('Failed to create user');
        }

        // Generate token
        const token = this.generateToken(user.id, user.email);

        // Save token to database
        await this.saveToken(user.id, token);

        return {
            user: {
                id: user.id,
                email: user.email,
                name: user.name,
                isAdmin: user.isAdmin,
            },
            token,
        };
    }

    async signUpAnonymous(anonymousSignUpDto: AnonymousSignUpDto) {
        const { name } = anonymousSignUpDto;

        // Create anonymous user (no email, no password)
        const user = await this.usersService.createAnonymous(name);

        if (!user.id) {
            throw new Error('Failed to create anonymous user');
        }

        // Generate token (using empty string for email since there's no email)
        const token = this.generateToken(user.id, '');

        // Save token to database
        await this.saveToken(user.id, token);

        return {
            user: {
                id: user.id,
                email: null,
                name: user.name,
                isAdmin: user.isAdmin,
            },
            token,
        };
    }

    async signIn(signInDto: SignInDto) {
        const { email, password } = signInDto;

        // Find user by email
        const user = await this.usersService.findByEmail(email);
        if (!user) {
            throw new UnauthorizedException('Invalid credentials');
        }

        // Check if user is banned
        if (user.isBanned) {
            throw new UnauthorizedException('User is banned');
        }

        // Verify password
        if (!user.password) {
            throw new UnauthorizedException('Invalid credentials');
        }
        const isPasswordValid = await bcrypt.compare(password, user.password);
        if (!isPasswordValid) {
            throw new UnauthorizedException('Invalid credentials');
        }

        if (!user.id || !user.email) {
            throw new Error('Invalid user data');
        }

        // Generate token
        const token = this.generateToken(user.id, user.email);

        // Save token to database
        await this.saveToken(user.id, token);

        return {
            user: {
                id: user.id,
                email: user.email,
                name: user.name,
                isAdmin: user.isAdmin,
            },
            token,
        };
    }

    private generateToken(userId: string, email: string): string {
        return jwt.sign(
            { sub: userId, email },
            this.jwtSecret,
            { expiresIn: this.jwtExpiresIn },
        );
    }

    private async saveToken(userId: string, token: string): Promise<void> {
        const expiresAt = new Date();
        expiresAt.setDate(expiresAt.getDate() + 7); // 7 days from now

        // Use raw SQL with sql() helper
        await this.db.db.execute(
            sql`INSERT INTO tokens (id, user_id, token, created_at, expires_at, is_revoked) 
                VALUES (gen_random_uuid(), ${userId}, ${token}, NOW(), ${expiresAt}, false)`
        );
    }

    async validateToken(token: string): Promise<{ userId: string; email: string } | null> {
        try {
            const decoded = jwt.verify(token, this.jwtSecret) as { sub: string; email: string };
            return { userId: decoded.sub, email: decoded.email };
        } catch {
            return null;
        }
    }
}
