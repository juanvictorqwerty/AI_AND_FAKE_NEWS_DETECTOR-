# Fact-Check Storage Service

## Overview

This service provides functionality to store fact-check results in PostgreSQL using Drizzle ORM. It uses a two-table architecture to efficiently store and retrieve fact-check data while ensuring atomic operations and preserving all existing responses.

## Key Features

- **Atomic Operations**: Uses PostgreSQL's atomic UPDATE operations to prevent race conditions
- **Null Handling**: Uses COALESCE to handle null values gracefully
- **JSONB Concatenation**: Appends new results using PostgreSQL's JSONB concatenation operator (||)
- **Type Safety**: Full TypeScript support with proper interfaces
- **Preservation**: Always preserves existing responses when appending new ones
- **Two-Table Architecture**: Separates full data storage from index for optimal performance

## Architecture

### Database Schema

The service uses two existing tables:

#### 1. newsCheckedTable (Full Data Storage)
Stores the complete fact-check request and response data:

```typescript
export const newsCheckedTable = pgTable("news_checked", {
    id: uuid("id").defaultRandom().primaryKey().notNull(),
    created_at: timestamp("created_at", { withTimezone: true }).defaultNow(),
    userID: uuid("userID").notNull().references(() => usersTable.id),
    requests: jsonb("requests").notNull(), // Original claim/request
    response: jsonb("response").notNull()  // Full fact-check result
});
```

#### 2. newsCheckedIndexTable (Index/Reference Storage)
Stores references to news_checked entries for quick lookup:

```typescript
export const newsCheckedIndexTable = pgTable("news_checked_index", {
    userID: uuid("userID").primaryKey().notNull().references(() => usersTable.id),
    newsList: jsonb("newsList") // JSONB array storing IDs of news_checked entries
});
```

### TypeScript Types

```typescript
export interface FactCheckResult {
    id: string; // UUID
    claim: string;
    verdict: 'true' | 'false' | 'unverified';
    confidence: 'low' | 'medium' | 'high';
    reason: string;
    sources: string[];
    createdAt: string; // ISO timestamp
}
```

## Storage Logic

The service implements a two-table storage architecture:

### Step 1: Store Full Data in newsCheckedTable
Insert the complete fact-check result (request + response) into `newsCheckedTable`:

```sql
INSERT INTO news_checked (user_id, requests, response)
VALUES (?, '{"claim": "..."}', '{"id": "...", "claim": "...", ...}')
RETURNING id;
```

### Step 2: Update Index in newsCheckedIndexTable
Append the new entry ID to the user's `newsList` in `newsCheckedIndexTable`:

```sql
UPDATE news_checked_index
SET news_list = COALESCE(news_list, '[]'::jsonb) || '["<new-entry-id>"]'::jsonb
WHERE user_id = ?;
```

**Key Points:**
1. **If the user's `newsList` is null** → Creates a JSON array with the new ID
2. **If `newsList` is non-empty** → Appends the new ID to the existing JSONB array
3. **Always preserves existing responses** → No data is ever lost
4. **Atomic operation** → Uses database-level atomicity to avoid race conditions
5. **Two-table design** → Separates full data from index for optimal performance

### SQL Operations Explained

**Insert Operation:**
```sql
INSERT INTO news_checked (user_id, requests, response)
VALUES ('user-uuid', '{"claim": "Earth is flat"}', '{"id": "...", "verdict": "false", ...}')
RETURNING id;
```
- Stores the complete fact-check data
- Returns the new entry's UUID

**Update Operation:**
```sql
UPDATE news_checked_index
SET news_list = COALESCE(news_list, '[]'::jsonb) || '["new-entry-id"]'::jsonb
WHERE user_id = 'user-uuid';
```
- `COALESCE(news_list, '[]'::jsonb)` - Returns an empty array if `news_list` is null
- `||` - JSONB concatenation operator that appends arrays
- `'["new-entry-id"]'::jsonb` - The new entry ID wrapped in an array

## API Methods

### `storeFactCheckResult(userId: string, factCheckResult: FactCheckResult): Promise<void>`

Stores a fact-check result for a user.

**Parameters:**
- `userId` - The UUID of the user
- `factCheckResult` - The fact-check result object to store

**Returns:** `Promise<void>`

**Throws:** `Error` if the operation fails

**Example:**
```typescript
const result: FactCheckResult = {
    id: '550e8400-e29b-41d4-a716-446655440000',
    claim: 'The Earth is flat',
    verdict: 'false',
    confidence: 'high',
    reason: 'Multiple scientific sources confirm Earth is spherical',
    sources: ['https://nasa.gov', 'https://esa.int'],
    createdAt: new Date().toISOString()
};

await factCheckStorageService.storeFactCheckResult(userId, result);
```

### `getFactCheckResults(userId: string): Promise<FactCheckResult[]>`

Retrieves all fact-check results for a user.

**Parameters:**
- `userId` - The UUID of the user

**Returns:** `Promise<FactCheckResult[]>` - Array of fact-check results, empty array if none exist

**Example:**
```typescript
const results = await factCheckStorageService.getFactCheckResults(userId);
console.log(`User has ${results.length} fact-check results`);
```

### `getFactCheckResultById(userId: string, factCheckId: string): Promise<FactCheckResult | null>`

Retrieves a specific fact-check result by its ID.

**Parameters:**
- `userId` - The UUID of the user
- `factCheckId` - The UUID of the fact-check result

**Returns:** `Promise<FactCheckResult | null>` - The fact-check result or null if not found

**Example:**
```typescript
const result = await factCheckStorageService.getFactCheckResultById(userId, factCheckId);
if (result) {
    console.log(`Verdict: ${result.verdict}`);
}
```

## Performance Optimization

### GIN Index Recommendation

For fast lookups by fact-check "id" within the JSONB array, create a GIN index:

```sql
-- Create GIN index on the newsList JSONB column
-- This enables fast containment queries and element lookups
CREATE INDEX idx_news_checked_index_news_list_gin 
ON news_checked_index 
USING GIN (news_list);
```

**Benefits:**
- Enables fast `@>` (contains) queries
- Supports `?` (key exists) operator
- Optimizes array element lookups
- Significantly improves query performance for large JSONB arrays

**Example queries with GIN index:**

```sql
-- Find users who have a specific fact-check result
SELECT * FROM news_checked_index 
WHERE news_list @> '[{"id": "550e8400-e29b-41d4-a716-446655440000"}]';

-- Check if a user has any fact-check results
SELECT * FROM news_checked_index 
WHERE news_list ? 'id';

-- Find users with fact-check results containing specific claim
SELECT * FROM news_checked_index 
WHERE news_list @> '[{"claim": "Earth is flat"}]';
```

### Additional Index Considerations

For even better performance, consider these additional indexes:

```sql
-- Index on user_id (already exists as primary key)
-- This is automatically created by the primary key constraint

-- Partial index for users with non-null news_list
CREATE INDEX idx_news_checked_index_has_news 
ON news_checked_index (user_id) 
WHERE news_list IS NOT NULL;
```

## Integration with NestJS Module

To use this service in your application, add it to the `FactCheckModule`:

```typescript
import { Module } from '@nestjs/common';
import { FactCheckController } from './fact-check.controller';
import { FactCheckStorageService } from './fact-check-storage.service';
import { WebScraperService } from './web-scraper.service';
import { SearchQueryService } from './search-query.service';
import { VerdictAnalysisService } from './verdict-analysis.service';
import { DatabaseModule } from '../db/db.module';

@Module({
    imports: [DatabaseModule],
    controllers: [FactCheckController],
    providers: [
        FactCheckStorageService,
        WebScraperService,
        SearchQueryService,
        VerdictAnalysisService,
    ],
    exports: [FactCheckStorageService],
})
export class FactCheckModule {}
```

## Usage in Controller

Example of using the storage service in a controller:

```typescript
import { Controller, Post, Body, UseGuards, Req } from '@nestjs/common';
import { FactCheckStorageService, FactCheckResult } from './fact-check-storage.service';
import { JwtAuthGuard } from '../auth/auth.guard';
import type { Request } from 'express';

@Controller('fact-check')
@UseGuards(JwtAuthGuard)
export class FactCheckController {
    constructor(
        private readonly factCheckStorageService: FactCheckStorageService,
        // ... other services
    ) {}

    @Post('verify')
    async verifyClaim(
        @Body() dto: { claim: string },
        @Req() req: Request,
    ) {
        const user = (req as any).user;
        
        // ... perform fact-checking logic ...
        
        // Create the fact-check result
        const factCheckResult: FactCheckResult = {
            id: crypto.randomUUID(),
            claim: dto.claim,
            verdict: 'false',
            confidence: 'high',
            reason: 'Multiple sources contradict this claim',
            sources: ['https://source1.com', 'https://source2.com'],
            createdAt: new Date().toISOString(),
        };
        
        // Store the result
        await this.factCheckStorageService.storeFactCheckResult(
            user.userId,
            factCheckResult,
        );
        
        return {
            success: true,
            result: factCheckResult,
        };
    }

    @Get('history')
    async getHistory(@Req() req: Request) {
        const user = (req as any).user;
        
        const results = await this.factCheckStorageService.getFactCheckResults(
            user.userId,
        );
        
        return {
            success: true,
            count: results.length,
            results,
        };
    }
}
```

## Error Handling

The service includes comprehensive error handling:

- All database operations are wrapped in try-catch blocks
- Errors are logged with context using NestJS Logger
- Errors are re-thrown with descriptive messages
- Null values are handled gracefully using COALESCE

## Race Condition Prevention

The service prevents race conditions through:

1. **Atomic UPDATE operations**: Database-level atomicity ensures only one update succeeds
2. **Single SQL statement**: The entire append operation is a single atomic SQL statement
3. **No read-modify-write cycles**: Avoids the classic race condition pattern
4. **UPSERT pattern**: Uses `onConflictDoUpdate` for insert-or-update operations

## Testing

Example unit test for the storage service:

```typescript
import { Test, TestingModule } from '@nestjs/testing';
import { FactCheckStorageService } from './fact-check-storage.service';
import { DatabaseService } from '../db/database.service';

describe('FactCheckStorageService', () => {
    let service: FactCheckStorageService;
    let dbService: DatabaseService;

    beforeEach(async () => {
        const module: TestingModule = await Test.createTestingModule({
            providers: [
                FactCheckStorageService,
                {
                    provide: DatabaseService,
                    useValue: {
                        db: {
                            update: jest.fn(),
                            insert: jest.fn(),
                            select: jest.fn(),
                        },
                    },
                },
            ],
        }).compile();

        service = module.get<FactCheckStorageService>(FactCheckStorageService);
        dbService = module.get<DatabaseService>(DatabaseService);
    });

    it('should be defined', () => {
        expect(service).toBeDefined();
    });

    describe('storeFactCheckResult', () => {
        it('should store a fact-check result', async () => {
            const userId = 'test-user-id';
            const result: FactCheckResult = {
                id: 'test-id',
                claim: 'Test claim',
                verdict: 'true',
                confidence: 'high',
                reason: 'Test reason',
                sources: [],
                createdAt: new Date().toISOString(),
            };

            // Mock the database operations
            // ... test implementation ...
        });
    });
});
```

## Migration

To add the GIN index to your database, create a migration:

```bash
pnpm drizzle-kit generate
```

Then add the GIN index creation to the generated migration file:

```sql
CREATE INDEX IF NOT EXISTS idx_news_checked_index_news_list_gin 
ON news_checked_index 
USING GIN (news_list);
```

## Best Practices

1. **Always use the service methods** - Don't directly manipulate the JSONB field
2. **Handle errors gracefully** - The service throws errors that should be caught and handled
3. **Use TypeScript types** - Leverage the `FactCheckResult` interface for type safety
4. **Monitor performance** - Use the GIN index for production deployments
5. **Log operations** - The service includes comprehensive logging for debugging

## Troubleshooting

### Issue: Slow queries when looking up fact-check results

**Solution:** Ensure the GIN index is created:
```sql
CREATE INDEX idx_news_checked_index_news_list_gin 
ON news_checked_index 
USING GIN (news_list);
```

### Issue: Race conditions when multiple requests store results simultaneously

**Solution:** The service already handles this through atomic operations. If you're still experiencing issues, check that you're using the service methods and not direct database manipulation.

### Issue: Null pointer errors when accessing newsList

**Solution:** The service uses COALESCE to handle nulls. Ensure you're using the service methods which handle this automatically.

## Conclusion

This service provides a robust, type-safe, and performant solution for storing fact-check results in PostgreSQL using Drizzle ORM. It leverages PostgreSQL's powerful JSONB operators and atomic operations to ensure data integrity and prevent race conditions.
