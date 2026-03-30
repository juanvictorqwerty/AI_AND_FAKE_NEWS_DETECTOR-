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
from sqlalchemy.orm import sessionmaker
from sqlalchemy import select, and_
from loguru import logger
from dotenv import load_dotenv

from models.database import Base, MediaChecked, MediaCheckedIndex

# Load environment variables
load_dotenv()


class DatabaseService:
    """Service for database operations"""
    
    def __init__(self):
        """Initialize database service"""
        # Use the provided DATABASE_URL
        self.database_url = os.getenv('DATABASE_URL', 'postgresql://admin:admin123@localhost:5432/mydb')
        
        # Convert to async URL for asyncpg
        if self.database_url.startswith('postgresql://'):
            self.database_url = self.database_url.replace('postgresql://', 'postgresql+asyncpg://', 1)
        
        # Create async engine
        self.engine = create_async_engine(
            self.database_url,
            echo=False,  # Set to True for SQL query logging
            pool_pre_ping=True,
            pool_size=10,
            max_overflow=20
        )
        
        # Create async session factory
        self.async_session = async_sessionmaker(
            self.engine,
            class_=AsyncSession,
            expire_on_commit=False
        )
        
        # Log connection info (without password)
        safe_url = self.database_url.split('@')[1] if '@' in self.database_url else self.database_url
        logger.info(f"Database service initialized with URL: {safe_url}")
    
    async def get_session(self) -> AsyncSession:
        """Get async database session"""
        return self.async_session()
    
    async def create_tables(self):
        """Create database tables if they don't exist"""
        try:
            async with self.engine.begin() as conn:
                await conn.run_sync(Base.metadata.create_all)
            logger.info("Database tables created successfully")
        except Exception as e:
            logger.error(f"Error creating database tables: {e}")
            raise
    
    async def store_analysis_result(
        self,
        user_id: str,
        media_type: str,
        prediction: str,
        confidence: float,
        analysis_details: Optional[Dict[str, Any]] = None,
        file_path: Optional[str] = None
    ) -> str:
        """
        Store analysis results in database (transaction)
        
        Args:
            user_id: User ID from JWT token
            media_type: "image" or "video"
            prediction: "real" or "fake"
            confidence: Confidence score (0.0 to 1.0)
            analysis_details: Additional analysis metadata
            file_path: Path to stored file (optional)
            
        Returns:
            analysis_id: Unique analysis identifier
            
        Raises:
            Exception: If database operation fails
        """
        analysis_id = str(uuid.uuid4())
        
        try:
            async with self.async_session() as session:
                async with session.begin():
                    # Insert into media_checked table
                    media_record = MediaChecked(
                        id=uuid.UUID(analysis_id),
                        userID=uuid.UUID(user_id),
                        isPhoto=(media_type == 'image'),
                        isVideo=(media_type == 'video'),
                        urlList=[file_path] if file_path else [],
                        score=int(confidence * 100)  # Convert to 0-100 scale
                    )
                    session.add(media_record)
                    
                    # Update or create media_checked_index record
                    query = select(MediaCheckedIndex).where(
                        MediaCheckedIndex.userID == uuid.UUID(user_id)
                    )
                    result = await session.execute(query)
                    index_record = result.scalar_one_or_none()
                    
                    if index_record:
                        # Update existing record
                        index_record.add_analysis_id(analysis_id)
                    else:
                        # Create new record
                        index_record = MediaCheckedIndex(
                            userID=uuid.UUID(user_id),
                            mediaCheckedList=[analysis_id]
                        )
                        session.add(index_record)
                    
                    # Commit transaction
                    await session.commit()
                    
                    logger.info(f"Analysis result stored: {analysis_id} for user: {user_id}")
                    return analysis_id
                    
        except Exception as e:
            logger.error(f"Error storing analysis result: {e}")
            raise Exception(f"Failed to store analysis result: {str(e)}")
    
    async def get_analysis_result(self, analysis_id: str) -> Optional[Dict[str, Any]]:
        """
        Get analysis result by ID
        
        Args:
            analysis_id: Unique analysis identifier
            
        Returns:
            Dictionary with analysis details or None if not found
        """
        try:
            async with self.async_session() as session:
                # Query media_checked table
                query = select(MediaChecked).where(
                    MediaChecked.id == uuid.UUID(analysis_id)
                )
                
                result = await session.execute(query)
                media_record = result.scalar_one_or_none()
                
                if not media_record:
                    logger.warning(f"Analysis not found: {analysis_id}")
                    return None
                
                return {
                    'analysis_id': str(media_record.id),
                    'user_id': str(media_record.userID),
                    'media_type': media_record.media_type,
                    'prediction': media_record.prediction,
                    'confidence': media_record.confidence,
                    'file_path': media_record.urlList[0] if media_record.urlList else None,
                    'analysis_details': {
                        'score': media_record.score,
                        'is_photo': media_record.isPhoto,
                        'is_video': media_record.isVideo
                    },
                    'created_at': media_record.created_at.isoformat() if media_record.created_at else None
                }
                
        except Exception as e:
            logger.error(f"Error getting analysis result: {e}")
            return None
    
    async def get_user_analyses(
        self,
        user_id: str,
        limit: int = 50,
        offset: int = 0
    ) -> List[Dict[str, Any]]:
        """
        Get all analyses for a user
        
        Args:
            user_id: User ID from JWT token
            limit: Maximum number of results
            offset: Offset for pagination
            
        Returns:
            List of analysis dictionaries
        """
        try:
            async with self.async_session() as session:
                # Query media_checked table
                query = (
                    select(MediaChecked)
                    .where(MediaChecked.userID == uuid.UUID(user_id))
                    .order_by(MediaChecked.created_at.desc())
                    .limit(limit)
                    .offset(offset)
                )
                
                result = await session.execute(query)
                rows = result.all()
                
                analyses = []
                for (media_record,) in rows:
                    analyses.append({
                        'analysis_id': str(media_record.id),
                        'user_id': str(media_record.userID),
                        'media_type': media_record.media_type,
                        'prediction': media_record.prediction,
                        'confidence': media_record.confidence,
                        'file_path': media_record.urlList[0] if media_record.urlList else None,
                        'analysis_details': {
                            'score': media_record.score,
                            'is_photo': media_record.isPhoto,
                            'is_video': media_record.isVideo
                        },
                        'created_at': media_record.created_at.isoformat() if media_record.created_at else None
                    })
                
                logger.info(f"Retrieved {len(analyses)} analyses for user: {user_id}")
                return analyses
                
        except Exception as e:
            logger.error(f"Error getting user analyses: {e}")
            return []
    
    async def delete_analysis(self, analysis_id: str, user_id: str) -> bool:
        """
        Delete analysis (only if owned by user)
        
        Args:
            analysis_id: Unique analysis identifier
            user_id: User ID from JWT token
            
        Returns:
            True if deleted, False otherwise
        """
        try:
            async with self.async_session() as session:
                async with session.begin():
                    # Find analysis in media_checked table
                    query = (
                        select(MediaChecked)
                        .where(
                            and_(
                                MediaChecked.id == uuid.UUID(analysis_id),
                                MediaChecked.userID == uuid.UUID(user_id)
                            )
                        )
                    )
                    
                    result = await session.execute(query)
                    media_record = result.scalar_one_or_none()
                    
                    if not media_record:
                        logger.warning(f"Analysis not found or not owned by user: {analysis_id}")
                        return False
                    
                    # Delete from media_checked
                    await session.delete(media_record)
                    
                    # Also remove from media_checked_index
                    index_query = select(MediaCheckedIndex).where(
                        MediaCheckedIndex.userID == uuid.UUID(user_id)
                    )
                    index_result = await session.execute(index_query)
                    index_record = index_result.scalar_one_or_none()
                    
                    if index_record and index_record.mediaCheckedList:
                        # Remove the analysis_id from the list
                        if analysis_id in index_record.mediaCheckedList:
                            index_record.mediaCheckedList.remove(analysis_id)
                            await session.commit()
                    
                    logger.info(f"Analysis deleted: {analysis_id}")
                    return True
                    
        except Exception as e:
            logger.error(f"Error deleting analysis: {e}")
            return False
    
    async def store_media_analysis(
        self,
        user_id: str,
        is_photo: bool,
        is_video: bool,
        url_list: List[str],
        score: int
    ) -> str:
        """
        Store media analysis in both media_checked and media_checked_index tables
        
        Args:
            user_id: User ID from JWT token
            is_photo: Whether the media is a photo
            is_video: Whether the media is a video
            url_list: List of URLs for the media
            score: Analysis score (0-100)
            
        Returns:
            analysis_id: Unique analysis identifier
        """
        analysis_id = str(uuid.uuid4())
        
        try:
            async with self.async_session() as session:
                async with session.begin():
                    # Create media_checked record
                    media_record = MediaChecked(
                        id=uuid.UUID(analysis_id),
                        userID=uuid.UUID(user_id),
                        isPhoto=is_photo,
                        isVideo=is_video,
                        urlList=url_list,
                        score=score
                    )
                    session.add(media_record)
                    
                    # Update or create media_checked_index
                    result = await session.execute(
                        select(MediaCheckedIndex).where(MediaCheckedIndex.userID == uuid.UUID(user_id))
                    )
                    index_record = result.scalar_one_or_none()
                    
                    if index_record is None:
                        index_record = MediaCheckedIndex(
                            userID=uuid.UUID(user_id),
                            mediaCheckedList=[analysis_id]
                        )
                        session.add(index_record)
                    else:
                        current_list = index_record.mediaCheckedList or []
                        current_list.append(analysis_id)
                        index_record.mediaCheckedList = current_list
                    
                    await session.commit()
                    logger.info(f"Media analysis stored: {analysis_id} for user: {user_id}")
                    return analysis_id
                    
        except Exception as e:
            logger.error(f"Error storing media analysis: {e}")
            raise Exception(f"Failed to store media analysis: {str(e)}")
    
    async def close(self):
        """Close database connections"""
        try:
            await self.engine.dispose()
            logger.info("Database connections closed")
        except Exception as e:
            logger.error(f"Error closing database connections: {e}")
    

    async def get_token_by_value(self, token: str) -> Optional[Dict[str, Any]]:
        
        try:
            async with self.async_session() as session:
                from models.database import Token  # Import your Tokens model
                
                query = select(Token).where(Token.token == token).limit(1)
                result = await session.execute(query)
                token_record = result.scalar_one_or_none()
                
                if token_record:
                    return {
                        'id': str(token_record.id),
                        'user_id': str(token_record.user_id),
                        'token': token_record.token,
                        'created_at': token_record.created_at,
                        'expires_at': token_record.expires_at,
                        'is_revoked': token_record.is_revoked
                    }
                return None
                
        except Exception as e:
            logger.error(f"Database error fetching token: {e}")
            return None

# Create singleton instance
db_service = DatabaseService()
