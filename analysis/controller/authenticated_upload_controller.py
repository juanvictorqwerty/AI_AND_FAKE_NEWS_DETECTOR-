"""
Authenticated Upload Controller for FastAPI

Handles authenticated media uploads with JWT validation and database storage.
Uses existing media_checked and media_checked_index tables.
"""

import os
import time
from typing import Dict, Any
from fastapi import APIRouter, UploadFile, File, HTTPException, Depends, Form
from loguru import logger
from dotenv import load_dotenv

from middleware.auth_middleware import validate_jwt_token
from service.analysis_service import AnalysisService
from service.database_service import db_service

# Load environment variables
load_dotenv()

# Create router
router = APIRouter(prefix="/analyze", tags=["Authenticated Analysis"])

# Initialize analysis service
analysis_service = None


def get_analysis_service():
    """Get or initialize analysis service"""
    global analysis_service
    if analysis_service is None:
        analysis_service = AnalysisService()
    return analysis_service


@router.post("/media")
async def analyze_media(
    file: UploadFile = File(...),
    type: str = Form(..., description="Media type: 'image' or 'video'"),
    user: Dict[str, Any] = Depends(validate_jwt_token)
):
    """
    Analyze media file with JWT authentication
    
    This endpoint validates the JWT token, processes the media file using AI analysis,
    stores results in the database, and returns a JSON response with prediction and confidence.
    
    Args:
        file: Media file (image or video)
        type: Media type ("image" or "video")
        user: User information from JWT token (injected by dependency)
        
    Returns:
        JSON response with status, prediction, confidence, media_type, and analysis_id
        
    Raises:
        HTTPException: 400 for validation errors, 401 for auth errors, 500 for processing errors
    """
    start_time = time.time()
    
    try:
        # Validate media type
        if type not in ['image', 'video']:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid media type: {type}. Must be 'image' or 'video'"
            )
        
        # Validate file
        if not file.filename:
            raise HTTPException(
                status_code=400,
                detail="No file provided"
            )
        
        # Check file size (max 20MB)
        max_file_size = 20 * 1024 * 1024  # 20MB
        file_content = await file.read()
        file_size = len(file_content)
        
        if file_size > max_file_size:
            raise HTTPException(
                status_code=400,
                detail=f"File size exceeds maximum limit of 20MB (current: {file_size / (1024*1024):.2f}MB)"
            )
        
        # Reset file pointer
        await file.seek(0)
        
        logger.info(f"Processing {type} upload for user: {user['user_id']}")
        logger.info(f"File: {file.filename}, Size: {file_size} bytes")
        
        # Process media using AI analysis
        analysis_service = get_analysis_service()
        
        if type == 'image':
            # Analyze image
            analysis_result = await analysis_service.analyze_image(file_content)
        else:
            # For video, we would need to extract frames first
            # For now, raise an error (video processing can be added later)
            raise HTTPException(
                status_code=501,
                detail="Video analysis not yet implemented. Please use image analysis."
            )
        
        # Extract prediction and confidence
        prediction = analysis_result.get('label', 'unknown')
        confidence = analysis_result.get('confidence', 0.0)
        probabilities = analysis_result.get('probabilities', {})
        processing_time = analysis_result.get('processing_time', 0.0)
        
        # Normalize prediction to 'real' or 'fake'
        # The AI model returns labels like 'ai' or 'human'
        if prediction.lower() in ['ai', 'artificial', 'fake']:
            prediction = 'fake'
        elif prediction.lower() in ['human', 'real']:
            prediction = 'real'
        
        # Store results in database using existing tables
        analysis_id = await db_service.store_media_analysis(
            user_id=user['user_id'],
            is_photo=(type == 'image'),
            is_video=(type == 'video'),
            url_list=[file.filename],
            is_human_generated=(prediction.lower() in ['real', 'human'])
        )
        
        total_time = time.time() - start_time
        
        logger.info(f"Analysis completed: {prediction} ({confidence:.4f}) in {total_time:.2f}s")
        
        # Return JSON response
        return {
            "status": "success",
            "data": {
                "prediction": prediction,
                "confidence": confidence,
                "media_type": type,
                "analysis_id": analysis_id
            }
        }
        
    except HTTPException:
        # Re-raise HTTP exceptions
        raise
    except Exception as e:
        logger.error(f"Error processing media: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Media processing failed: {str(e)}"
        )


@router.get("/results/{analysis_id}")
async def get_analysis_results(
    analysis_id: str,
    user: Dict[str, Any] = Depends(validate_jwt_token)
):
    """
    Get analysis results by ID
    
    Args:
        analysis_id: Unique analysis identifier
        user: User information from JWT token
        
    Returns:
        JSON response with analysis details
        
    Raises:
        HTTPException: 404 if not found, 401 if not authorized
    """
    try:
        # Get analysis from database
        result = await db_service.get_analysis_result(analysis_id)
        
        if not result:
            raise HTTPException(
                status_code=404,
                detail=f"Analysis not found: {analysis_id}"
            )
        
        # Check if user owns this analysis
        if result['user_id'] != user['user_id']:
            raise HTTPException(
                status_code=403,
                detail="Not authorized to access this analysis"
            )
        
        return {
            "status": "success",
            "data": result
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting analysis results: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get analysis results: {str(e)}"
        )


@router.get("/history")
async def get_analysis_history(
    limit: int = 50,
    offset: int = 0,
    user: Dict[str, Any] = Depends(validate_jwt_token)
):
    """
    Get analysis history for current user
    
    Args:
        limit: Maximum number of results (default: 50)
        offset: Offset for pagination (default: 0)
        user: User information from JWT token
        
    Returns:
        JSON response with list of analyses
    """
    try:
        analyses = await db_service.get_user_analyses(
            user_id=user['user_id'],
            limit=limit,
            offset=offset
        )
        
        return {
            "status": "success",
            "data": {
                "analyses": analyses,
                "count": len(analyses),
                "limit": limit,
                "offset": offset
            }
        }
        
    except Exception as e:
        logger.error(f"Error getting analysis history: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get analysis history: {str(e)}"
        )


@router.delete("/results/{analysis_id}")
async def delete_analysis(
    analysis_id: str,
    user: Dict[str, Any] = Depends(validate_jwt_token)
):
    """
    Delete analysis by ID
    
    Args:
        analysis_id: Unique analysis identifier
        user: User information from JWT token
        
    Returns:
        JSON response with deletion status
        
    Raises:
        HTTPException: 404 if not found, 401 if not authorized
    """
    try:
        deleted = await db_service.delete_analysis(
            analysis_id=analysis_id,
            user_id=user['user_id']
        )
        
        if not deleted:
            raise HTTPException(
                status_code=404,
                detail=f"Analysis not found or not authorized: {analysis_id}"
            )
        
        return {
            "status": "success",
            "message": f"Analysis deleted: {analysis_id}"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting analysis: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to delete analysis: {str(e)}"
        )
