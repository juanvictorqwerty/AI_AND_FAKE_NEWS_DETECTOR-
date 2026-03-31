"""
JWT Authentication Middleware for FastAPI

Validates JWT tokens against database tokens table, checking existence,
revocation status, and expiration.
"""

import os
from typing import Optional, Dict, Any
from fastapi import HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from loguru import logger
from dotenv import load_dotenv
from datetime import datetime

from service.database_service import db_service

load_dotenv()

security = HTTPBearer()


class JWTAuthMiddleware:
    """JWT Authentication Middleware with database token validation"""
    
    def __init__(self):
        logger.info("JWT Auth Middleware initialized with database validation")
    
    async def __call__(
        self,
        credentials: HTTPAuthorizationCredentials = Depends(security)
    ) -> Dict[str, Any]:
        token = credentials.credentials
        
        try:
            # Check raw token in database
            token_record = await db_service.get_token_by_value(token)
            
            if not token_record:
                logger.warning("Token not found in database")
                raise HTTPException(status_code=401, detail="Invalid token")
            
            # Check if token is revoked
            if token_record.get('is_revoked'):
                logger.warning(f"Token revoked for user: {token_record.get('user_id')}")
                raise HTTPException(status_code=401, detail="Token has been revoked")
            
            # Check database expiration
            expires_at = token_record.get('expires_at')
            if expires_at and datetime.now(expires_at.tzinfo) > expires_at:
                logger.warning(f"Token expired in database for user: {token_record.get('user_id')}")
                raise HTTPException(status_code=401, detail="Token expired")
            
            user_id = str(token_record.get('user_id'))
            
            logger.info(f"Token validated from database for user: {user_id}")
            
            return {
                'user_id': user_id,
                'token_id': str(token_record.get('id')),
                'token_record': token_record
            }
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Token validation error: {e}")
            raise HTTPException(status_code=401, detail="Token validation failed")


jwt_auth = JWTAuthMiddleware()


async def validate_jwt_token(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> Dict[str, Any]:
    """Dependency function for validating JWT tokens against database"""
    return await jwt_auth(credentials)