import { config } from 'dotenv';
import { defineConfig } from 'drizzle-kit';

// Load environment variables first
config({ path: '.env.production' });

// 📂 NEWS AUTH CHECK DATABASE CONFIG (NEON)
// -------------------------------------------

if (!process.env.DATABASE_URL) {
    throw new Error('DATABASE_URL is not defined in .env.production');
}

console.log('✅ Production DB URL:', process.env.DATABASE_URL);

// Export default directly to avoid variable shadowing/naming conflicts
export default defineConfig({
    out: './drizzle',
    schema: ['./src/db/schema.ts', './src/db/relations.ts'],
    dialect: 'postgresql',
    dbCredentials: {
        url: process.env.DATABASE_URL, // Dropped the trailing '!' as the error check above guarantees it exists
    },
});