# Fact-Check Storage Service - Quick Reference

## Files Created

1. **[`news_auth_check/src/fact-check/fact-check-storage.service.ts`](news_auth_check/src/fact-check/fact-check-storage.service.ts)** - Main service implementation
2. **[`news_auth_check/FACT_CHECK_STORAGE_README.md`](news_auth_check/FACT_CHECK_STORAGE_README.md)** - Comprehensive documentation
3. **[`news_auth_check/src/fact-check/fact-check.module.ts`](news_auth_check/src/fact-check/fact-check.module.ts)** - Updated module with new service

## Quick Start

### 1. Import the Service

```typescript
import { FactCheckStorageService, FactCheckResult } from './fact-check-storage.service';
```

### 2. Inject in Constructor

```typescript
constructor(
    private readonly factCheckStorageService: FactCheckStorageService,
) {}
```

### 3. Store a Result

```typescript
const result: FactCheckResult = {
    id: crypto.randomUUID(),
    claim: 'Your claim here',
    verdict: 'true', // or 'false' or 'unverified'
    confidence: 'high', // or 'medium' or 'low'
    reason: 'Explanation of verdict',
    sources: ['https://source1.com', 'https://source2.com'],
    createdAt: new Date().toISOString(),
};

await this.factCheckStorageService.storeFactCheckResult(userId, result);
```

### 4. Retrieve Results

```typescript
// Get all results for a user
const allResults = await this.factCheckStorageService.getFactCheckResults(userId);

// Get a specific result by ID
const specificResult = await this.factCheckStorageService.getFactCheckResultById(userId, resultId);
```

## TypeScript Interface

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

## Database Schema Used

The service uses two existing tables:

### newsCheckedTable (Full Data Storage)
```typescript
export const newsCheckedTable = pgTable("news_checked", {
    id: uuid("id").defaultRandom().primaryKey().notNull(),
    created_at: timestamp("created_at", { withTimezone: true }).defaultNow(),
    userID: uuid("userID").notNull().references(() => usersTable.id),
    requests: jsonb("requests").notNull(), // Original claim/request
    response: jsonb("response").notNull()  // Full fact-check result
});
```

### newsCheckedIndexTable (Index/Reference Storage)
```typescript
export const newsCheckedIndexTable = pgTable("news_checked_index", {
    userID: uuid("userID").primaryKey().notNull().references(() => usersTable.id),
    newsList: jsonb("newsList") // JSONB array storing IDs of news_checked entries
});
```

## Key Features

✅ **Atomic Operations** - Prevents race conditions
✅ **Null Handling** - Uses COALESCE for null values
✅ **JSONB Concatenation** - Appends without replacing
✅ **Type Safety** - Full TypeScript support
✅ **Preservation** - Never loses existing data
✅ **Two-Table Architecture** - Separates full data from index

## SQL Operations

### Step 1: Insert Full Data
```sql
INSERT INTO news_checked (user_id, requests, response)
VALUES ('user-uuid', '{"claim": "..."}', '{"id": "...", "verdict": "false", ...}')
RETURNING id;
```

### Step 2: Update Index
```sql
UPDATE news_checked_index
SET news_list = COALESCE(news_list, '[]'::jsonb) || '["new-entry-id"]'::jsonb
WHERE user_id = 'user-uuid';
```

## Performance Optimization

### Create GIN Index (Recommended for Production)

```sql
CREATE INDEX idx_news_checked_index_news_list_gin
ON news_checked_index
USING GIN (news_list);
```

**Benefits:**
- Fast `@>` (contains) queries
- Supports `?` (key exists) operator
- Optimizes array element lookups

## Module Integration

The service is already integrated into [`FactCheckModule`](news_auth_check/src/fact-check/fact-check.module.ts):

```typescript
@Module({
    imports: [AuthModule, DatabaseModule],
    controllers: [FactCheckController],
    providers: [
        WebScraperService,
        SearchQueryService,
        VerdictAnalysisService,
        FactCheckStorageService, // ← Added
    ],
    exports: [
        WebScraperService,
        SearchQueryService,
        VerdictAnalysisService,
        FactCheckStorageService, // ← Exported
    ],
})
export class FactCheckModule {}
```

## Error Handling

All methods include comprehensive error handling:

```typescript
try {
    await this.factCheckStorageService.storeFactCheckResult(userId, result);
} catch (error) {
    // Error is logged and re-thrown with descriptive message
    console.error('Failed to store result:', error.message);
}
```

## Race Condition Prevention

The service prevents race conditions through:

1. **Atomic UPDATE operations** - Database-level atomicity
2. **Single SQL statement** - No read-modify-write cycles
3. **UPSERT pattern** - Uses `onConflictDoUpdate`

## Example Controller Usage

```typescript
@Post('verify')
@UseGuards(JwtAuthGuard)
async verifyClaim(
    @Body() dto: { claim: string },
    @Req() req: Request,
) {
    const user = (req as any).user;
    
    // Perform fact-checking logic...
    
    const factCheckResult: FactCheckResult = {
        id: crypto.randomUUID(),
        claim: dto.claim,
        verdict: 'false',
        confidence: 'high',
        reason: 'Multiple sources contradict this claim',
        sources: ['https://source1.com', 'https://source2.com'],
        createdAt: new Date().toISOString(),
    };
    
    await this.factCheckStorageService.storeFactCheckResult(
        user.userId,
        factCheckResult,
    );
    
    return { success: true, result: factCheckResult };
}
```

## Testing

```typescript
describe('FactCheckStorageService', () => {
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

        await service.storeFactCheckResult(userId, result);
        // Assert...
    });
});
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Slow queries | Create GIN index on `news_list` column |
| Race conditions | Service handles this automatically via atomic operations |
| Null pointer errors | Service uses COALESCE to handle nulls |
| Type errors | Use `FactCheckResult` interface for type safety |

## Best Practices

1. ✅ Always use service methods (don't manipulate JSONB directly)
2. ✅ Handle errors gracefully (catch and log)
3. ✅ Use TypeScript types (`FactCheckResult` interface)
4. ✅ Create GIN index for production
5. ✅ Monitor performance with logging

## Summary

This implementation provides a **production-ready**, **type-safe**, and **performant** solution for storing fact-check results in PostgreSQL using Drizzle ORM. It leverages PostgreSQL's powerful JSONB operators and atomic operations to ensure data integrity and prevent race conditions.

**Key Achievement:** The service uses a two-table architecture to separate full data storage from index, appends to JSONB arrays without replacing existing data, handles null values gracefully, and ensures atomic operations to prevent race conditions.
