import { Injectable, ConflictException, NotFoundException } from '@nestjs/common';
import { UsersService } from '../users/users.service';
import { CompleteProfileDto, EditProfileDto } from './dto';
import * as bcrypt from 'bcryptjs';

@Injectable()
export class ProfileService {
    constructor(private readonly usersService: UsersService) {}

    async completeProfile(userId: string, completeProfileDto: CompleteProfileDto) {
        const { email, password, name } = completeProfileDto;

        // Check if user exists
        const user = await this.usersService.findById(userId);
        if (!user) {
            throw new NotFoundException('User not found');
        }

        // Check if email is already in use by another user
        if (email) {
            const existingUser = await this.usersService.findByEmail(email);
            if (existingUser && existingUser.id !== userId) {
                throw new ConflictException('Email already in use');
            }
        }

        // Hash password
        const hashedPassword = await bcrypt.hash(password, 10);

        // Update user with complete profile
        const updatedUser = await this.usersService.updateUser(userId, {
            email,
            password: hashedPassword,
            name,
        });

        if (!updatedUser) {
            throw new Error('Failed to update profile');
        }

        return {
            success: true,
            user: {
                id: updatedUser.id,
                email: updatedUser.email,
                name: updatedUser.name,
                isAdmin: updatedUser.isAdmin,
            },
        };
    }

    async editProfile(userId: string, editProfileDto: EditProfileDto) {
        const { email, password, name } = editProfileDto;

        // Check if user exists
        const user = await this.usersService.findById(userId);
        if (!user) {
            throw new NotFoundException('User not found');
        }

        // Check if email is already in use by another user
        if (email) {
            const existingUser = await this.usersService.findByEmail(email);
            if (existingUser && existingUser.id !== userId) {
                throw new ConflictException('Email already in use');
            }
        }

        // Prepare update data
        const updateData: Partial<{ email: string; password: string; name: string }> = {};

        if (email !== undefined) {
            updateData.email = email;
        }
        if (password !== undefined) {
            updateData.password = await bcrypt.hash(password, 10);
        }
        if (name !== undefined) {
            updateData.name = name;
        }

        // Update user
        const updatedUser = await this.usersService.updateUser(userId, updateData);

        if (!updatedUser) {
            throw new Error('Failed to update profile');
        }

        return {
            success: true,
            user: {
                id: updatedUser.id,
                email: updatedUser.email,
                name: updatedUser.name,
                isAdmin: updatedUser.isAdmin,
            },
        };
    }

    async getProfile(userId: string) {
        const user = await this.usersService.findById(userId);

        if (!user) {
            throw new NotFoundException('User not found');
        }

        return {
            success: true,
            user: {
                id: user.id,
                email: user.email,
                name: user.name,
                isAdmin: user.isAdmin,
                isBanned: user.isBanned,
            },
        };
    }
}
