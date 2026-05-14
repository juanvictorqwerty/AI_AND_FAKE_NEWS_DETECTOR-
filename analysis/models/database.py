"""
Database Models for Authenticated Media Analysis

Defines SQLAlchemy models for storing analysis results with user authentication.
Uses existing media_checked and media_checked_index tables from the schema.
"""

import uuid
from datetime import datetime
from typing import Optional, Dict, Any, List
from sqlalchemy import Column, String, DateTime, Integer, Boolean, JSON, ForeignKey, Index, select
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.ext.declarative import declarative_base
import os
from dotenv import load_dotenv

load_dotenv()

Base = declarative_base()

# Database configuration
DATABASE_URL = os.getenv('DATABASE_URL', 'postgresql+asyncpg://user:password@localhost/dbname')

# Create async engine
engine = create_async_engine(DATABASE_URL, echo=False, future=True)
async_session_factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


async def get_db_session() -> AsyncSession:
    """Get database session dependency"""
    async with async_session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


class User(Base):
    """Users table - for token validation"""
    __tablename__ = "users"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(String, nullable=True)


class MediaChecked(Base):
    """
    Media checked table for storing individual media analysis records
    """
    __tablename__ = "media_checked"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow, nullable=False)
    userID = Column(UUID(as_uuid=True), ForeignKey('users.id', ondelete='CASCADE'), nullable=False)
    isPhoto = Column(Boolean, nullable=False)
    isVideo = Column(Boolean, nullable=False)
    urlList = Column(JSON, nullable=False)
    score = Column(Integer, nullable=False)
    
    __table_args__ = (
        Index('idx_media_checked_userID', 'userID'),
        Index('idx_media_checked_created_at', 'created_at'),
    )
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            'id': str(self.id),
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'user_id': str(self.userID),
            'is_photo': self.isPhoto,
            'is_video': self.isVideo,
            'url_list': self.urlList,
            'score': self.score
        }


class MediaCheckedIndex(Base):
    """
    Media checked index table for tracking user's media analysis history
    """
    __tablename__ = "media_checked_index"
    
    userID = Column(UUID(as_uuid=True), ForeignKey('users.id', ondelete='CASCADE'), primary_key=True)
    mediaCheckedList = Column(JSON, nullable=True)
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            'user_id': str(self.userID),
            'media_checked_list': self.mediaCheckedList or []
        }


class Token(Base):
    """Tokens table - for authentication tokens"""
    __tablename__ = "tokens"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey('users.id', ondelete='CASCADE'), nullable=False)
    token = Column(String(512), nullable=False)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow, nullable=True)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    is_revoked = Column(Boolean, default=False, nullable=False)
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            'id': str(self.id),
            'user_id': str(self.user_id),
            'token': self.token,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'expires_at': self.expires_at.isoformat() if self.expires_at else None,
            'is_revoked': self.is_revoked
        }


class DatabaseService:
    """Service for database operations"""
    
    def __init__(self):
        self.session_factory = async_session_factory
    
    async def create_tables(self):
        """Create all tables"""
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
    
    async def close(self):
        """Close database connections"""
        await engine.dispose()
    
    async def verify_user_exists(self, user_id: str) -> bool:
        """Verify if user exists in database by ID"""
        async with self.session_factory() as session:
            try:
                user_uuid = uuid.UUID(user_id)
                result = await session.execute(select(User).where(User.id == user_uuid))
                user = result.scalar_one_or_none()
                return user is not None
            except (ValueError, Exception):
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
        """
        async with self.session_factory() as session:
            try:
                user_uuid = uuid.UUID(user_id)
                
                # Create media_checked record
                media_record = MediaChecked(
                    userID=user_uuid,
                    isPhoto=is_photo,
                    isVideo=is_video,
                    urlList=url_list,
                    score=score
                )
                session.add(media_record)
                await session.flush()
                
                analysis_id = str(media_record.id)
                
                # Update or create media_checked_index
                result = await session.execute(
                    select(MediaCheckedIndex).where(MediaCheckedIndex.userID == user_uuid)
                )
                index_record = result.scalar_one_or_none()
                
                if index_record is None:
                    index_record = MediaCheckedIndex(
                        userID=user_uuid,
                        mediaCheckedList=[analysis_id]
                    )
                    session.add(index_record)
                else:
                    current_list = index_record.mediaCheckedList or []
                    current_list.append(analysis_id)
                    index_record.mediaCheckedList = current_list
                
                await session.commit()
                return analysis_id
                
            except Exception as e:
                await session.rollback()
                raise e
    
    async def get_user_analyses(self, user_id: str, limit: int = 50, offset: int = 0) -> List[Dict[str, Any]]:
        """Get analysis history for a user"""
        async with self.session_factory() as session:
            try:
                user_uuid = uuid.UUID(user_id)
                result = await session.execute(
                    select(MediaChecked)
                    .where(MediaChecked.userID == user_uuid)
                    .order_by(MediaChecked.created_at.desc())
                    .limit(limit)
                    .offset(offset)
                )
                records = result.scalars().all()
                return [record.to_dict() for record in records]
            except Exception:
                return []
    
    async def get_analysis_by_id(self, analysis_id: str, user_id: Optional[str] = None) -> Optional[Dict[str, Any]]:
        """Get analysis by ID, optionally verify user ownership"""
        async with self.session_factory() as session:
            try:
                analysis_uuid = uuid.UUID(analysis_id)
                query = select(MediaChecked).where(MediaChecked.id == analysis_uuid)
                
                if user_id:
                    user_uuid = uuid.UUID(user_id)
                    query = query.where(MediaChecked.userID == user_uuid)
                
                result = await session.execute(query)
                record = result.scalar_one_or_none()
                return record.to_dict() if record else None
            except Exception:
                return None
    
    async def delete_analysis(self, analysis_id: str, user_id: str) -> bool:
        """Delete analysis and update index"""
        async with self.session_factory() as session:
            try:
                analysis_uuid = uuid.UUID(analysis_id)
                user_uuid = uuid.UUID(user_id)
                
                result = await session.execute(
                    select(MediaChecked)
                    .where(MediaChecked.id == analysis_uuid)
                    .where(MediaChecked.userID == user_uuid)
                )
                record = result.scalar_one_or_none()
                
                if not record:
                    return False
                
                await session.delete(record)
                
                result = await session.execute(
                    select(MediaCheckedIndex).where(MediaCheckedIndex.userID == user_uuid)
                )
                index_record = result.scalar_one_or_none()
                
                if index_record and index_record.mediaCheckedList:
                    index_record.mediaCheckedList = [
                        aid for aid in index_record.mediaCheckedList if aid != analysis_id
                    ]
                
                await session.commit()
                return True
            except Exception:
                await session.rollback()
                return False


# Global database service instance
db_service = DatabaseService()