import { Injectable, Logger } from '@nestjs/common';
import { DatabaseService } from '../db/database.service';
import { mediaCheckedTable, mediaCheckedIndexTable } from '../db/schema';
import { eq, sql } from 'drizzle-orm';

/**
 * TypeScript type for a single media check result
 */
export interface MediaCheckResult {
    id: string; // UUID
    isPhoto: boolean;
    isVideo: boolean;
    urlList: string[];
    score: number;
    createdAt: string; // ISO timestamp
}

/**
 * Service for storing media check results in PostgreSQL using Drizzle ORM
 *
 * Architecture:
 * - mediaCheckedTable: Stores full media response data
 * - mediaCheckedIndexTable: Stores references/IDs to media_checked entries for quick lookup
 *
 * Key features:
 * - Appends new results to existing JSONB array in mediaCheckedTable
 * - Handles null values using COALESCE
 * - Atomic operations to avoid race conditions
 * - Preserves all existing responses
 * - Maintains index table for efficient queries
 */
@Injectable()
export class MediaStorageService {
    private readonly logger = new Logger(MediaStorageService.name);

    constructor(private readonly db: DatabaseService) {}

    /**
     * Stores a media check result for a user
     *
     * Storage logic:
     * 1. Insert full result into mediaCheckedTable
     * 2. Append the new entry ID to mediaCheckedIndexTable.mediaCheckedList
     * 3. If mediaCheckedList is null → create array with new ID
     * 4. If mediaCheckedList exists → append new ID to existing array
     * 5. Uses atomic operations to prevent race conditions
     *
     * @param userId - The UUID of the user
     * @param mediaCheckResult - The media check result object to store
     * @returns Promise<void>
     * @throws Error if the operation fails
     */
    async storeMediaCheckResult(
        userId: string,
        mediaCheckResult: MediaCheckResult,
    ): Promise<void> {
        this.logger.log(`Storing media check result for user ${userId}, URLs: ${mediaCheckResult.urlList.length}`);

        try {
            // Step 1: Insert the full media check result into mediaCheckedTable
            const insertedResult = await this.db.db
                .insert(mediaCheckedTable)
                .values({
                    userID: userId,
                    isPhoto: mediaCheckResult.isPhoto,
                    isVideo: mediaCheckResult.isVideo,
                    urlList: mediaCheckResult.urlList,
                    score: mediaCheckResult.score,
                })
                .returning({ id: mediaCheckedTable.id });

            if (!insertedResult || insertedResult.length === 0) {
                throw new Error('Failed to insert media check result into mediaCheckedTable');
            }

            const newEntryId = insertedResult[0].id;
            this.logger.log(`Inserted media check result with ID: ${newEntryId}`);

            // Step 2: Append the new entry ID to mediaCheckedIndexTable.mediaCheckedList
            const updateResult = await this.db.db
                .update(mediaCheckedIndexTable)
                .set({
                    // Use SQL template for JSONB concatenation
                    mediaCheckedList: sql`COALESCE(${mediaCheckedIndexTable.mediaCheckedList}, '[]'::jsonb) || ${JSON.stringify([newEntryId])}::jsonb`,
                })
                .where(eq(mediaCheckedIndexTable.userID, userId))
                .returning({ id: mediaCheckedIndexTable.userID });

            // If no rows were affected, the user doesn't have an index entry yet
            if (!updateResult || updateResult.length === 0) {
                this.logger.log(`No existing index entry for user ${userId}, creating new entry`);

                await this.db.db
                    .insert(mediaCheckedIndexTable)
                    .values({
                        userID: userId,
                        mediaCheckedList: [newEntryId], // Initialize with the first ID
                    })
                    .onConflictDoUpdate({
                        target: mediaCheckedIndexTable.userID,
                        set: {
                            // If conflict occurs, append to existing list
                            mediaCheckedList: sql`COALESCE(${mediaCheckedIndexTable.mediaCheckedList}, '[]'::jsonb) || ${JSON.stringify([newEntryId])}::jsonb`,
                        },
                    });
            }

            this.logger.log(`Successfully stored media check result for user ${userId}`);
        } catch (error) {
            this.logger.error(`Failed to store media check result for user ${userId}:`, error);
            throw new Error(`Failed to store media check result: ${error.message}`);
        }
    }

    /**
     * Retrieves all media check results for a user
     *
     * @param userId - The UUID of the user
     * @returns Promise<MediaCheckResult[]> - Array of media check results, empty array if none exist
     */
    async getMediaCheckResults(userId: string): Promise<MediaCheckResult[]> {
        this.logger.log(`Retrieving media check results for user ${userId}`);

        try {
            // First, get the list of IDs from the index table
            const indexResult = await this.db.db
                .select({ mediaCheckedList: mediaCheckedIndexTable.mediaCheckedList })
                .from(mediaCheckedIndexTable)
                .where(eq(mediaCheckedIndexTable.userID, userId))
                .limit(1);

            if (!indexResult || indexResult.length === 0) {
                this.logger.log(`No media check results found for user ${userId}`);
                return [];
            }

            const mediaList = indexResult[0].mediaCheckedList;

            // Ensure we have an array of IDs
            const entryIds: string[] = Array.isArray(mediaList) ? mediaList : [];

            if (entryIds.length === 0) {
                this.logger.log(`No media check results found for user ${userId}`);
                return [];
            }

            // Fetch all the actual media check results from mediaCheckedTable
            const results: MediaCheckResult[] = [];

            for (const entryId of entryIds) {
                const entry = await this.db.db
                    .select({
                        id: mediaCheckedTable.id,
                        isPhoto: mediaCheckedTable.isPhoto,
                        isVideo: mediaCheckedTable.isVideo,
                        urlList: mediaCheckedTable.urlList,
                        score: mediaCheckedTable.score,
                        createdAt: mediaCheckedTable.created_at,
                    })
                    .from(mediaCheckedTable)
                    .where(eq(mediaCheckedTable.id, entryId))
                    .limit(1);

                if (entry && entry.length > 0 && entry[0]) {
                    results.push({
                        id: entry[0].id,
                        isPhoto: entry[0].isPhoto,
                        isVideo: entry[0].isVideo,
                        urlList: entry[0].urlList as string[],
                        score: entry[0].score,
                        createdAt: entry[0].createdAt?.toISOString() || new Date().toISOString(),
                    });
                }
            }

            this.logger.log(`Retrieved ${results.length} media check results for user ${userId}`);
            return results;
        } catch (error) {
            this.logger.error(`Failed to retrieve media check results for user ${userId}:`, error);
            throw new Error(`Failed to retrieve media check results: ${error.message}`);
        }
    }

    /**
     * Retrieves a specific media check result by its ID
     *
     * @param userId - The UUID of the user
     * @param mediaCheckId - The UUID of the media check result
     * @returns Promise<MediaCheckResult | null> - The media check result or null if not found
     */
    async getMediaCheckResultById(
        userId: string,
        mediaCheckId: string,
    ): Promise<MediaCheckResult | null> {
        this.logger.log(`Retrieving media check result ${mediaCheckId} for user ${userId}`);

        try {
            // First, get the list of IDs from the index table
            const indexResult = await this.db.db
                .select({ mediaCheckedList: mediaCheckedIndexTable.mediaCheckedList })
                .from(mediaCheckedIndexTable)
                .where(eq(mediaCheckedIndexTable.userID, userId))
                .limit(1);

            if (!indexResult || indexResult.length === 0) {
                this.logger.log(`No media check results found for user ${userId}`);
                return null;
            }

            const mediaList = indexResult[0].mediaCheckedList;

            if (!Array.isArray(mediaList)) {
                return null;
            }

            // Check if the mediaCheckId exists in the user's list
            if (!mediaList.includes(mediaCheckId)) {
                this.logger.log(`Media check result ${mediaCheckId} not found for user ${userId}`);
                return null;
            }

            // Fetch the actual media check result from mediaCheckedTable
            const entry = await this.db.db
                .select({
                    id: mediaCheckedTable.id,
                    isPhoto: mediaCheckedTable.isPhoto,
                    isVideo: mediaCheckedTable.isVideo,
                    urlList: mediaCheckedTable.urlList,
                    score: mediaCheckedTable.score,
                    createdAt: mediaCheckedTable.created_at,
                })
                .from(mediaCheckedTable)
                .where(eq(mediaCheckedTable.id, mediaCheckId))
                .limit(1);

            if (!entry || entry.length === 0) {
                this.logger.log(`Media check result ${mediaCheckId} not found in mediaCheckedTable`);
                return null;
            }

            this.logger.log(`Found media check result ${mediaCheckId} for user ${userId}`);
            return {
                id: entry[0].id,
                isPhoto: entry[0].isPhoto,
                isVideo: entry[0].isVideo,
                urlList: entry[0].urlList as string[],
                score: entry[0].score,
                createdAt: entry[0].createdAt?.toISOString() || new Date().toISOString(),
            };
        } catch (error) {
            this.logger.error(`Failed to retrieve media check result ${mediaCheckId} for user ${userId}:`, error);
            throw new Error(`Failed to retrieve media check result: ${error.message}`);
        }
    }
}