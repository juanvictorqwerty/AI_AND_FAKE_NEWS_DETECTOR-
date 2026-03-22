import { Injectable, Logger } from '@nestjs/common';
import { DatabaseService } from '../db/database.service';
import { newsCheckedTable, newsCheckedIndexTable } from '../db/schema';
import { eq, sql } from 'drizzle-orm';

/**
 * TypeScript type for a single fact-check result
 * Matches the structure specified in the requirements
 */
export interface FactCheckResult {
    id: string; // UUID
    claim: string;
    verdict: 'true' | 'false' | 'unverified';
    confidence: 'low' | 'medium' | 'high';
    reason: string;
    sources: string[];
    createdAt: string; // ISO timestamp
}

/**
 * Service for storing fact-check results in PostgreSQL using Drizzle ORM
 *
 * Architecture:
 * - newsCheckedTable: Stores full fact-check response data (requests + response)
 * - newsCheckedIndexTable: Stores references/IDs to news_checked entries for quick lookup
 *
 * Key features:
 * - Appends new results to existing JSONB array in newsCheckedTable
 * - Handles null values using COALESCE
 * - Atomic operations to avoid race conditions
 * - Preserves all existing responses
 * - Maintains index table for efficient queries
 */
@Injectable()
export class FactCheckStorageService {
    private readonly logger = new Logger(FactCheckStorageService.name);

    constructor(private readonly db: DatabaseService) {}

    /**
     * Stores a fact-check result for a user
     *
     * Storage logic:
     * 1. Insert full result into newsCheckedTable (requests + response)
     * 2. Append the new entry ID to newsCheckedIndexTable.newsList
     * 3. If newsList is null → create array with new ID
     * 4. If newsList exists → append new ID to existing array
     * 5. Uses atomic operations to prevent race conditions
     *
     * @param userId - The UUID of the user
     * @param factCheckResult - The fact-check result object to store
     * @returns Promise<void>
     * @throws Error if the operation fails
     */
    async storeFactCheckResult(
        userId: string,
        factCheckResult: FactCheckResult,
    ): Promise<void> {
        this.logger.log(`Storing fact-check result for user ${userId}, claim: ${factCheckResult.claim}`);

        try {
            // Step 1: Insert the full fact-check result into newsCheckedTable
            // This stores both the request (claim) and response (full result)
            const insertedResult = await this.db.db
                .insert(newsCheckedTable)
                .values({
                    userID: userId,
                    requests: { claim: factCheckResult.claim }, // Store the original claim
                    response: factCheckResult, // Store the full fact-check result
                })
                .returning({ id: newsCheckedTable.id });

            if (!insertedResult || insertedResult.length === 0) {
                throw new Error('Failed to insert fact-check result into newsCheckedTable');
            }

            const newEntryId = insertedResult[0].id;
            this.logger.log(`Inserted fact-check result with ID: ${newEntryId}`);

            // Step 2: Append the new entry ID to newsCheckedIndexTable.newsList
            // Use PostgreSQL JSONB concatenation operator (||) to append
            // COALESCE handles the case where newsList is null by defaulting to an empty array
            // The operation is atomic at the database level, preventing race conditions
            
            const updateResult = await this.db.db
                .update(newsCheckedIndexTable)
                .set({
                    // Use SQL template for JSONB concatenation
                    // COALESCE(newsList, '[]'::jsonb) ensures we start with an empty array if null
                    // || operator appends the new ID as a single-element array
                    newsList: sql`COALESCE(${newsCheckedIndexTable.newsList}, '[]'::jsonb) || ${JSON.stringify([newEntryId])}::jsonb`,
                })
                .where(eq(newsCheckedIndexTable.userID, userId))
                .returning({ id: newsCheckedIndexTable.userID });

            // If no rows were affected, the user doesn't have an index entry yet
            // We need to create one with the initial ID
            if (!updateResult || updateResult.length === 0) {
                this.logger.log(`No existing index entry for user ${userId}, creating new entry`);
                
                await this.db.db
                    .insert(newsCheckedIndexTable)
                    .values({
                        userID: userId,
                        newsList: [newEntryId], // Initialize with the first ID
                    })
                    .onConflictDoUpdate({
                        target: newsCheckedIndexTable.userID,
                        set: {
                            // If conflict occurs, append to existing list
                            newsList: sql`COALESCE(${newsCheckedIndexTable.newsList}, '[]'::jsonb) || ${JSON.stringify([newEntryId])}::jsonb`,
                        },
                    });
            }

            this.logger.log(`Successfully stored fact-check result for user ${userId}`);
        } catch (error) {
            this.logger.error(`Failed to store fact-check result for user ${userId}:`, error);
            throw new Error(`Failed to store fact-check result: ${error.message}`);
        }
    }

    /**
     * Retrieves all fact-check results for a user
     *
     * @param userId - The UUID of the user
     * @returns Promise<FactCheckResult[]> - Array of fact-check results, empty array if none exist
     */
    async getFactCheckResults(userId: string): Promise<FactCheckResult[]> {
        this.logger.log(`Retrieving fact-check results for user ${userId}`);

        try {
            // First, get the list of IDs from the index table
            const indexResult = await this.db.db
                .select({ newsList: newsCheckedIndexTable.newsList })
                .from(newsCheckedIndexTable)
                .where(eq(newsCheckedIndexTable.userID, userId))
                .limit(1);

            if (!indexResult || indexResult.length === 0) {
                this.logger.log(`No fact-check results found for user ${userId}`);
                return [];
            }

            const newsList = indexResult[0].newsList;
            
            // Ensure we have an array of IDs
            const entryIds: string[] = Array.isArray(newsList) ? newsList : [];
            
            if (entryIds.length === 0) {
                this.logger.log(`No fact-check results found for user ${userId}`);
                return [];
            }

            // Fetch all the actual fact-check results from newsCheckedTable
            const results: FactCheckResult[] = [];
            
            for (const entryId of entryIds) {
                const entry = await this.db.db
                    .select({ response: newsCheckedTable.response })
                    .from(newsCheckedTable)
                    .where(eq(newsCheckedTable.id, entryId))
                    .limit(1);

                if (entry && entry.length > 0 && entry[0].response) {
                    results.push(entry[0].response as FactCheckResult);
                }
            }
            
            this.logger.log(`Retrieved ${results.length} fact-check results for user ${userId}`);
            return results;
        } catch (error) {
            this.logger.error(`Failed to retrieve fact-check results for user ${userId}:`, error);
            throw new Error(`Failed to retrieve fact-check results: ${error.message}`);
        }
    }

    /**
     * Retrieves a specific fact-check result by its ID
     *
     * @param userId - The UUID of the user
     * @param factCheckId - The UUID of the fact-check result
     * @returns Promise<FactCheckResult | null> - The fact-check result or null if not found
     */
    async getFactCheckResultById(
        userId: string,
        factCheckId: string,
    ): Promise<FactCheckResult | null> {
        this.logger.log(`Retrieving fact-check result ${factCheckId} for user ${userId}`);

        try {
            // First, get the list of IDs from the index table
            const indexResult = await this.db.db
                .select({ newsList: newsCheckedIndexTable.newsList })
                .from(newsCheckedIndexTable)
                .where(eq(newsCheckedIndexTable.userID, userId))
                .limit(1);

            if (!indexResult || indexResult.length === 0) {
                this.logger.log(`No fact-check results found for user ${userId}`);
                return null;
            }

            const newsList = indexResult[0].newsList;
            
            if (!Array.isArray(newsList)) {
                return null;
            }

            // Check if the factCheckId exists in the user's list
            if (!newsList.includes(factCheckId)) {
                this.logger.log(`Fact-check result ${factCheckId} not found for user ${userId}`);
                return null;
            }

            // Fetch the actual fact-check result from newsCheckedTable
            const entry = await this.db.db
                .select({ response: newsCheckedTable.response })
                .from(newsCheckedTable)
                .where(eq(newsCheckedTable.id, factCheckId))
                .limit(1);

            if (!entry || entry.length === 0 || !entry[0].response) {
                this.logger.log(`Fact-check result ${factCheckId} not found in newsCheckedTable`);
                return null;
            }

            this.logger.log(`Found fact-check result ${factCheckId} for user ${userId}`);
            return entry[0].response as FactCheckResult;
        } catch (error) {
            this.logger.error(`Failed to retrieve fact-check result ${factCheckId} for user ${userId}:`, error);
            throw new Error(`Failed to retrieve fact-check result: ${error.message}`);
        }
    }
}
