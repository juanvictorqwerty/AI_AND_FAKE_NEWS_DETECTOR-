import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../db/database.service';
import { usersTable } from '../db/schema';
import { eq } from 'drizzle-orm';

export type User = typeof usersTable.$inferSelect;
export type NewUser = typeof usersTable.$inferInsert;

@Injectable()
export class UsersService {
    constructor(private readonly db: DatabaseService) {}

    async findByEmail(email: string): Promise<User | undefined> {
        const result = await this.db.db
            .select()
            .from(usersTable)
            .where(eq(usersTable.email, email))
            .limit(1);
        return result[0];
    }

    async findById(id: string): Promise<User | undefined> {
        const result = await this.db.db
            .select()
            .from(usersTable)
            .where(eq(usersTable.id, id))
            .limit(1);
        return result[0];
    }

    async create(email: string, password: string, name: string): Promise<NewUser> {
        const result = await this.db.db
            .insert(usersTable)
            .values({
                email,
                password,
                name,
            })
            .returning();
        return result[0];
    }

    async createAnonymous(name?: string): Promise<NewUser> {
        const result = await this.db.db
            .insert(usersTable)
            .values({
                email: null,
                password: null,
                name: name || null,
            })
            .returning();
        return result[0];
    }

    async updateUser(
        id: string,
        updateData: Partial<Pick<User, 'name' | 'email' | 'password'>>,
    ): Promise<User | undefined> {
        const result = await this.db.db
            .update(usersTable)
            .set(updateData)
            .where(eq(usersTable.id, id))
            .returning();
        return result[0];
    }
}
