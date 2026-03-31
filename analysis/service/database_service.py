"""
Database Service for Authenticated Media Analysis

Handles database operations for storing and retrieving analysis results.
Uses existing media_checked and media_checked_index tables.
"""

import os
import uuid
from typing import Optional, Dict, Any, List
from datetime import datetime
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy import select, and_, text
from loguru import logger
from dotenv import load_dotenv

load_dotenv()


class DatabaseService:
    """Service for database operations"""

    def __init__(self):
        self.database_url = os.getenv('DATABASE_URL', 'postgresql://admin:admin123@localhost:5432/mydb')

        if self.database_url.startswith('postgresql://'):
            self.database_url = self.database_url.replace('postgresql://', 'postgresql+asyncpg://', 1)

        self.engine = create_async_engine(
            self.database_url,
            echo=False,
            pool_pre_ping=True,
            pool_size=10,
            max_overflow=20
        )

        self.async_session = async_sessionmaker(
            self.engine,
            class_=AsyncSession,
            expire_on_commit=False
        )

        safe_url = self.database_url.split('@')[1] if '@' in self.database_url else self.database_url
        logger.info(f"Database service initialized: {safe_url}")

    # ------------------------------------------------------------------
    # Table creation (no-op when tables already exist)
    # ------------------------------------------------------------------

    async def create_tables(self):
        """
        Ensure all tables exist.  Since the schema is owned by Drizzle,
        this just runs a lightweight connectivity check and logs success.
        Set echo=True on the engine if you want to see the DDL.
        """
        try:
            async with self.engine.connect() as conn:
                await conn.execute(text("SELECT 1"))
            logger.info("Database connection verified (tables managed by Drizzle)")
        except Exception as e:
            logger.error(f"Database connectivity check failed: {e}")
            raise

    # ------------------------------------------------------------------
    # Media analysis: store + index
    # ------------------------------------------------------------------

    async def store_media_analysis(
        self,
        user_id: str,
        is_photo: bool,
        is_video: bool,
        url_list: List[str],
        score: int
    ) -> str:
        """
        Insert a row into media_checked and update media_checked_index.

        Column names match the Drizzle schema exactly:
          media_checked        → id, created_at, userID, isPhoto, isVideo, url_list, score
          media_checked_index  → userID (PK), media_checked_list
        """
        analysis_id = str(uuid.uuid4())

        try:
            async with self.async_session() as session:
                async with session.begin():

                    # ── 1. Insert into media_checked ──────────────────────────────
                    import json
                    await session.execute(
                        text("""
                            INSERT INTO media_checked
                                (id, "userID", "isPhoto", "isVideo", url_list, score)
                            VALUES
                                (:id, :user_id, :is_photo, :is_video, cast(:url_list as jsonb), :score)
                        """),
                        {
                            "id":       analysis_id,
                            "user_id":  user_id,
                            "is_photo": is_photo,
                            "is_video": is_video,
                            "url_list": json.dumps(url_list),
                            "score":    score,
                        }
                    )

                    # ── 2. Upsert media_checked_index ─────────────────────────────
                    # Fetch current list (if the user row exists)
                    row = await session.execute(
                        text("""
                            SELECT media_checked_list
                            FROM   media_checked_index
                            WHERE  "userID" = :user_id
                        """),
                        {"user_id": user_id}
                    )
                    existing = row.scalar_one_or_none()

                    if existing is None:
                        # No index row yet — create one
                        await session.execute(
                            text("""
                                INSERT INTO media_checked_index ("userID", media_checked_list)
                                VALUES (:user_id, cast(:list as jsonb))
                            """),
                            {
                                "user_id": user_id,
                                "list":    json.dumps([analysis_id]),
                            }
                        )
                    else:
                        # Append to the existing JSON array via Postgres jsonb operator
                        await session.execute(
                            text("""
                                UPDATE media_checked_index
                                SET    media_checked_list = media_checked_list || cast(:new_item as jsonb)
                                WHERE  "userID" = :user_id
                            """),
                            {
                                "user_id":  user_id,
                                "new_item": json.dumps([analysis_id]),
                            }
                        )

                logger.info(f"Media analysis stored: {analysis_id} for user: {user_id}")
                return analysis_id

        except Exception as e:
            logger.error(f"Error storing media analysis: {e}")
            raise Exception(f"Failed to store media analysis: {str(e)}")

    # ------------------------------------------------------------------
    # Retrieve a single analysis
    # ------------------------------------------------------------------

    async def get_analysis_result(self, analysis_id: str) -> Optional[Dict[str, Any]]:
        """Return a single media_checked row as a dict, or None."""
        try:
            async with self.async_session() as session:
                row = await session.execute(
                    text("""
                        SELECT id, created_at, "userID", "isPhoto", "isVideo", url_list, score
                        FROM   media_checked
                        WHERE  id = :analysis_id
                    """),
                    {"analysis_id": analysis_id}
                )
                record = row.mappings().one_or_none()

                if record is None:
                    logger.warning(f"Analysis not found: {analysis_id}")
                    return None

                return self._row_to_dict(record)

        except Exception as e:
            logger.error(f"Error getting analysis result: {e}")
            return None

    # ------------------------------------------------------------------
    # Retrieve all analyses for a user
    # ------------------------------------------------------------------

    async def get_user_analyses(
        self,
        user_id: str,
        limit: int = 50,
        offset: int = 0
    ) -> List[Dict[str, Any]]:
        """Return paginated media_checked rows for a user."""
        try:
            async with self.async_session() as session:
                rows = await session.execute(
                    text("""
                        SELECT id, created_at, "userID", "isPhoto", "isVideo", url_list, score
                        FROM   media_checked
                        WHERE  "userID" = :user_id
                        ORDER  BY created_at DESC
                        LIMIT  :limit
                        OFFSET :offset
                    """),
                    {"user_id": user_id, "limit": limit, "offset": offset}
                )
                records = rows.mappings().all()

                analyses = [self._row_to_dict(r) for r in records]
                logger.info(f"Retrieved {len(analyses)} analyses for user: {user_id}")
                return analyses

        except Exception as e:
            logger.error(f"Error getting user analyses: {e}")
            return []

    # ------------------------------------------------------------------
    # Delete an analysis (owner-check included)
    # ------------------------------------------------------------------

    async def delete_analysis(self, analysis_id: str, user_id: str) -> bool:
        """
        Delete a media_checked row and remove it from media_checked_index.
        Only succeeds when the row is owned by user_id.
        """
        try:
            async with self.async_session() as session:
                async with session.begin():

                    # Verify ownership
                    row = await session.execute(
                        text("""
                            SELECT id FROM media_checked
                            WHERE  id = :analysis_id AND "userID" = :user_id
                        """),
                        {"analysis_id": analysis_id, "user_id": user_id}
                    )
                    if row.scalar_one_or_none() is None:
                        logger.warning(f"Analysis not found or not owned by user: {analysis_id}")
                        return False

                    # Delete from media_checked
                    await session.execute(
                        text('DELETE FROM media_checked WHERE id = :analysis_id'),
                        {"analysis_id": analysis_id}
                    )

                    # Remove from media_checked_index using Postgres jsonb functions
                    # jsonb_agg + jsonb_array_elements filters the target element out
                    await session.execute(
                        text("""
                            UPDATE media_checked_index
                            SET    media_checked_list = (
                                       SELECT COALESCE(jsonb_agg(elem), '[]'::jsonb)
                                       FROM   jsonb_array_elements(media_checked_list) AS elem
                                       WHERE  elem #>> '{}' <> :analysis_id
                                   )
                            WHERE  "userID" = :user_id
                        """),
                        {"analysis_id": analysis_id, "user_id": user_id}
                    )

                logger.info(f"Analysis deleted: {analysis_id}")
                return True

        except Exception as e:
            logger.error(f"Error deleting analysis: {e}")
            return False

    # ------------------------------------------------------------------
    # Token lookup
    # ------------------------------------------------------------------

    async def get_token_by_value(self, token: str) -> Optional[Dict[str, Any]]:
        """Return a tokens row by its raw token string."""
        try:
            async with self.async_session() as session:
                row = await session.execute(
                    text("""
                        SELECT id, user_id, token, created_at, expires_at, is_revoked
                        FROM   tokens
                        WHERE  token = :token
                        LIMIT  1
                    """),
                    {"token": token}
                )
                record = row.mappings().one_or_none()

                if record is None:
                    return None

                return {
                    "id":         str(record["id"]),
                    "user_id":    str(record["user_id"]),
                    "token":      record["token"],
                    "created_at": record["created_at"],
                    "expires_at": record["expires_at"],
                    "is_revoked": record["is_revoked"],
                }

        except Exception as e:
            logger.error(f"Database error fetching token: {e}")
            return None

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _row_to_dict(record) -> Dict[str, Any]:
        """Convert a media_checked row mapping to a plain dict."""
        url_list = record["url_list"] or []
        return {
            "analysis_id": str(record["id"]),
            "user_id":     str(record["userID"]),
            "is_photo":    record["isPhoto"],
            "is_video":    record["isVideo"],
            "score":       record["score"],
            "url_list":    url_list,
            "file_path":   url_list[0] if url_list else None,
            "created_at":  record["created_at"].isoformat() if record["created_at"] else None,
        }

    async def close(self):
        """Dispose the connection pool."""
        try:
            await self.engine.dispose()
            logger.info("Database connections closed")
        except Exception as e:
            logger.error(f"Error closing database connections: {e}")


# Singleton
db_service = DatabaseService()