import { Injectable, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { drizzle } from 'drizzle-orm/node-postgres';
import { Pool } from 'pg';
import * as schema from './schema';
import 'dotenv/config';

@Injectable()
export class DatabaseService implements OnModuleInit, OnModuleDestroy {
    private pool: Pool;
    public db: ReturnType<typeof drizzle>;

    constructor() {
        this.pool = new Pool({
            connectionString: process.env.DATABASE_URL,
        });
        this.db = drizzle(this.pool, { schema });
    }

    async onModuleInit() {
        // Initialize if needed
    }

    async onModuleDestroy() {
        await this.pool.end();
    }
}
