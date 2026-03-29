"""
JWT Authentication Middleware for FastAPI

Validates JWT tokens from Authorization header, checks if user exists in database,
and extracts user information.
"""

import os
import time
from typing import Optional, Dict, Any
from fastapi import HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import jwt
from loguru import logger
from dotenv import load_dotenv

from service.database_service import db_service

load_dotenv()

JWT_SECRET = os.getenv('JWT_SECRET', 'your-secret-key')
JWT_ALGORITHM = 'HS256'
security = HTTPBearer()


class JWTAuthMiddleware:
    """JWT Authentication Middleware for FastAPI with database validation"""
    
    def __init__(self, secret: str = JWT_SECRET, algorithm: str = JWT_ALGORITHM):
        self.secret = secret
        self.algorithm = algorithm
        logger.info(f"JWT Auth Middleware initialized with algorithm: {algorithm}")
    
    async def __call__(
        self,
        credentials: HTTPAuthorizationCredentials = Depends(security)
    ) -> Dict[str, Any]:
        token = credentials.credentials
        
        try:
            payload = jwt.decode(token, self.secret, algorithms=[self.algorithm])
            
            if 'exp' in payload:
                current_time = time.time()
                if current_time > payload['exp']:
                    logger.warning(f"Token expired for user: {payload.get('sub', 'unknown')}")
                    raise HTTPException(status_code=401, detail="Token expired")
            
            user_id = payload.get('sub')
            email = payload.get('email')
            
            if not user_id:
                logger.warning("Token missing user_id (sub) claim")
                raise HTTPException(status_code=401, detail="Invalid token: missing user_id")
            
            # Validate user exists in database
            user_exists = await db_service.verify_user_exists(user_id)
            if not user_exists:
                logger.warning(f"User not found in database: {user_id}")
                raise HTTPException(status_code=401, detail="Invalid token: user not found")
            
            logger.info(f"Token validated for user: {user_id}")
            
            return {
                'user_id': user_id,
                'email': email,
                'payload': payload
            }
            
        except jwt.ExpiredSignatureError:
            logger.warning("Token signature expired")
            raise HTTPException(status_code=401, detail="Token expired")
        except jwt.InvalidTokenError as e:
            logger.warning(f"Invalid token: {e}")
            raise HTTPException(status_code=401, detail="Invalid token")
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Token validation error: {e}")
            raise HTTPException(status_code=401, detail="Token validation failed")


jwt_auth = JWTAuthMiddleware()


async def validate_jwt_token(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> Dict[str, Any]:
    """Dependency function for validating JWT tokens with database check"""
    return await jwt_auth(credentials)


def decode_token_without_verification(token: str) -> Optional[Dict[str, Any]]:
    """Decode JWT token without verification (for debugging only)"""
    try:
        payload = jwt.decode(token, options={"verify_signature": False})
        return payload
    except Exception as e:
        logger.error(f"Error decoding token: {e}")
        return None