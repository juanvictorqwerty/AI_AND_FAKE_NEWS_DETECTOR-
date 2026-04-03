import os
import asyncio
from contextlib import asynccontextmanager
from typing import List, Dict, Any, Optional
from fastapi import FastAPI, UploadFile, File, HTTPException, BackgroundTasks, Depends
from fastapi.middleware.cors import CORSMiddleware
from loguru import logger
from dotenv import load_dotenv

from service.minio_service import MinIOService
from service.analysis_service import AnalysisService
from controller.upload_controller import UploadController
from controller.authenticated_upload_controller import router
from middleware.auth_middleware import validate_jwt_token
from models.schemas import UploadResponse, AnalysisResult, HealthResponse, VideoUploadResponse, AnalysisStatus
from service.database_service import db_service

load_dotenv()

minio_service = None
analysis_service = None
upload_controller = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    global minio_service, analysis_service, upload_controller
    
    logger.info("Starting AI Image Analysis Service...")
    
    try:
        minio_service = MinIOService()
        logger.info("MinIO service initialized")
        
        analysis_service = AnalysisService()
        logger.info("Analysis service initialized")
        
        upload_controller = UploadController(minio_service, analysis_service)
        logger.info("Upload controller initialized")
        
        asyncio.create_task(periodic_cleanup())
        
        logger.info("AI Image Analysis Service started successfully")
        
    except Exception as e:
        logger.error(f"Error during startup: {e}")
        raise
    
    yield
    
    logger.info("Shutting down AI Image Analysis Service...")
    await db_service.close()


app = FastAPI(
    title="AI Image Analysis Service",
    description="Backend service for AI-powered image analysis",
    version="1.0.0",
    lifespan=lifespan
)

# Configure CORS
cors_origins = os.getenv('CORS_ORIGINS', '["http://localhost:3000", "http://localhost:8080", "http://localhost:5000"]')
import json
try:
    origins = json.loads(cors_origins)
except:
    origins = ["http://localhost:3000", "http://localhost:8080", "http://localhost:5000"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(router)

logger.add("logs/app.log", rotation="10 MB", retention="7 days", level="INFO")


@app.get("/", tags=["Root"])
async def root():
    return {
        "message": "AI Image Analysis Service",
        "version": "1.0.0",
        "docs": "/docs"
    }


@app.get("/health", response_model=HealthResponse, tags=["Health"])
async def health_check():
    try:
        minio_connected = minio_service.check_connection() if minio_service else False
        model_loaded = analysis_service.is_model_loaded() if analysis_service else False
        
        return HealthResponse(
            status="healthy" if (minio_connected and model_loaded) else "degraded",
            minio_connected=minio_connected,
            model_loaded=model_loaded
        )
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return HealthResponse(status="unhealthy", minio_connected=False, model_loaded=False)


# =============================================================================
# AUTHENTICATED UPLOAD ENDPOINTS
# =============================================================================

def safe_confidence_format(confidence: Optional[float]) -> str:
    """Safely format confidence as percentage string"""
    if confidence is None:
        return "N/A"
    try:
        return f"{confidence:.2%}"
    except (ValueError, TypeError):
        return "N/A"


@app.post("/upload", response_model=UploadResponse, tags=["Authenticated Upload"])
async def upload_photo(
    file: UploadFile = File(...),
    background_tasks: BackgroundTasks = None,
    user: Dict[str, Any] = Depends(validate_jwt_token)
):
    """
    Upload PHOTO file for AI analysis (Authenticated)
    
    Stores results with isPhoto=True, isVideo=False
    Score: 1 if human, 0 if AI
    """
    if not upload_controller:
        raise HTTPException(status_code=503, detail="Service not initialized")
    
    try:
        # For authenticated uploads, process synchronously to get immediate analysis results
        result = await upload_controller.analyze_single_image(file, None)
        
        # Debug logging to see what result actually contains
        logger.debug(f"Upload result type: {type(result)}")
        logger.debug(f"Upload result attributes: {dir(result) if hasattr(result, '__dict__') else result}")
        
        # Extract prediction and confidence from result dict
        prediction = result.get('label', None)
        confidence = result.get('confidence', None)
        file_id = result.get('file_id', 'unknown')

        # Convert prediction to string and lowercase for comparison
        prediction_str = str(prediction).lower() if prediction else 'unknown'

        # Store 1 for human, 0 for AI (binary score as requested)
        score = 1 if prediction_str == 'human' else 0

        # Get file URL for storage (use file_id from result)
        file_url = file_id
        url_list = [file_url]
        
        # Store as PHOTO: isPhoto=True, isVideo=False
        analysis_id = await db_service.store_media_analysis(
            user_id=user['user_id'],
            is_photo=True,
            is_video=False,
            url_list=url_list,
            is_human_generated=(score == 1)
        )

        # Update results_storage for legacy endpoint compatibility
        upload_controller.results_storage[file_id] = AnalysisResult(
            file_id=file_id,
            status=AnalysisStatus.COMPLETED,
            label=prediction,
            confidence=confidence,
            probabilities=result.get('probabilities', {}),
            processing_time=result.get('processing_time', 0.0)
        )

        # Safely format confidence for message
        confidence_str = safe_confidence_format(confidence)
        message = f"Analysis complete: {prediction or 'unknown'} (confidence: {confidence_str})"

        logger.info(f"Photo analysis stored for user {user['user_id']}: analysis_id={analysis_id}, prediction={prediction}, score={score}")

        return UploadResponse(
            success=True,
            file_id=result.get('file_id', 'unknown'),
            message=message,
            file_size=None,  # Not available in sync result
            file_type='image',
            prediction=prediction,
            confidence=confidence,
            analysis_id=analysis_id
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in authenticated photo upload: {e}")
        raise HTTPException(status_code=500, detail=f"Upload failed: {str(e)}")


@app.post("/upload/video", response_model=VideoUploadResponse, tags=["Authenticated Upload"])
async def upload_video(
    files: List[UploadFile] = File(...),
    background_tasks: BackgroundTasks = None,
    user: Dict[str, Any] = Depends(validate_jwt_token)
):
    """
    Upload VIDEO frames for AI analysis (Authenticated)
    
    Stores results with isPhoto=False, isVideo=True
    Score: 1 if human, 0 for AI
    """
    if not upload_controller:
        raise HTTPException(status_code=503, detail="Service not initialized")
    
    try:
        # For authenticated uploads, process synchronously to get immediate analysis results
        result = await upload_controller.upload_video_frames(files, None)
        
        # Debug logging
        logger.debug(f"Video upload result type: {type(result)}")
        logger.debug(f"Video upload result attributes: {dir(result) if hasattr(result, '__dict__') else result}")
        
        # Extract prediction and confidence from result dict
        prediction = result.get('prediction', None)
        confidence = result.get('confidence', None)
        
        # Convert prediction to string and lowercase for comparison
        prediction_str = str(prediction).lower() if prediction else 'unknown'
        
        # Store 1 for human, 0 for AI (binary score as requested)
        score = 1 if prediction_str == 'human' else 0
        
        # Get file URLs for storage (use frame filenames)
        frames = result.get('frames', [])
        url_list = [frame.get('filename', f.filename) for frame, f in zip(frames, files)] if frames else [f.filename for f in files]
        
        # Store as VIDEO: isPhoto=False, isVideo=True
        analysis_id = await db_service.store_media_analysis(
            user_id=user['user_id'],
            is_photo=False,
            is_video=True,
            url_list=url_list,
            is_human_generated=(score == 1)
        )
        
        logger.info(f"Video analysis stored for user {user['user_id']}: analysis_id={analysis_id}, prediction={prediction}, score={score}")
        
        # Return response matching VideoUploadResponse schema
        return VideoUploadResponse(
            status="success",
            prediction=prediction,
            confidence=confidence or 0.0,
            frame_count=result.get('frame_count', len(files)),
            valid_frame_count=result.get('valid_frame_count', len(files)),
            aggregated_score=result.get('aggregated_score', confidence or 0.0),
            frames=result.get('frames', []),
            label_distribution=result.get('label_distribution', None),
            total_processing_time=result.get('total_processing_time', None),
            analysis_id=analysis_id
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in authenticated video upload: {e}")
        raise HTTPException(status_code=500, detail=f"Video upload failed: {str(e)}")


@app.get("/analyze/history", tags=["Authenticated Analysis"])
async def get_analysis_history(
    limit: int = 50,
    offset: int = 0,
    user: Dict[str, Any] = Depends(validate_jwt_token)
):
    """Get analysis history for current user"""
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
        raise HTTPException(status_code=500, detail=f"Failed to get analysis history: {str(e)}")


@app.get("/analyze/results/{analysis_id}", tags=["Authenticated Analysis"])
async def get_analysis_result(
    analysis_id: str,
    user: Dict[str, Any] = Depends(validate_jwt_token)
):
    """Get analysis results by ID"""
    try:
        result = await db_service.get_analysis_result(analysis_id)
        
        if not result:
            raise HTTPException(status_code=404, detail=f"Analysis not found: {analysis_id}")
        
        # Verify ownership
        if result.get('user_id') != user['user_id']:
            raise HTTPException(status_code=403, detail="Not authorized to access this analysis")
        
        return {"status": "success", "data": result}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting analysis results: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get analysis results: {str(e)}")


@app.delete("/analyze/results/{analysis_id}", tags=["Authenticated Analysis"])
async def delete_analysis(
    analysis_id: str,
    user: Dict[str, Any] = Depends(validate_jwt_token)
):
    """Delete analysis by ID"""
    try:
        deleted = await db_service.delete_analysis(
            analysis_id=analysis_id,
            user_id=user['user_id']
        )
        
        if not deleted:
            raise HTTPException(status_code=404, detail=f"Analysis not found or not authorized: {analysis_id}")
        
        return {"status": "success", "message": f"Analysis deleted: {analysis_id}"}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting analysis: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to delete analysis: {str(e)}")


# =============================================================================
# LEGACY ENDPOINTS (Unauthenticated)
# =============================================================================

@app.post("/upload/public", response_model=UploadResponse, tags=["Legacy Upload"])
async def upload_file_public(
    file: UploadFile = File(...),
    background_tasks: BackgroundTasks = None
):
    """Upload image file for AI analysis (Public - no authentication)"""
    if not upload_controller:
        raise HTTPException(status_code=503, detail="Service not initialized")
    
    result = await upload_controller.upload_file(file, background_tasks)
    
    # Convert result to UploadResponse format
    prediction = getattr(result, 'prediction', None) or getattr(result, 'label', None)
    confidence = getattr(result, 'confidence', None)
    confidence_str = safe_confidence_format(confidence)
    
    return UploadResponse(
        success=True,
        file_id=getattr(result, 'file_id', 'unknown'),
        message=f"Analysis complete: {prediction or 'unknown'} (confidence: {confidence_str})",
        file_size=getattr(result, 'file_size', None),
        file_type=getattr(result, 'file_type', 'image'),
        prediction=prediction,
        confidence=confidence,
        analysis_id=None  # No database storage for public uploads
    )


@app.post("/upload/video/public", response_model=VideoUploadResponse, tags=["Legacy Upload"])
async def upload_video_frames_public(
    files: List[UploadFile] = File(...),
    background_tasks: BackgroundTasks = None
):
    """Upload and analyze multiple video frames (Public - no authentication)"""
    if not upload_controller:
        raise HTTPException(status_code=503, detail="Service not initialized")
    
    result = await upload_controller.upload_video_frames(files, background_tasks)
    
    prediction = getattr(result, 'prediction', None) or getattr(result, 'final_label', None)
    confidence = getattr(result, 'confidence', None)
    
    return VideoUploadResponse(
        status="success",
        prediction=prediction,
        confidence=confidence or 0.0,
        frame_count=getattr(result, 'frame_count', len(files)),
        valid_frame_count=getattr(result, 'valid_frame_count', len(files)),
        aggregated_score=getattr(result, 'aggregated_score', confidence or 0.0),
        frames=getattr(result, 'frames', []),
        label_distribution=getattr(result, 'label_distribution', None),
        total_processing_time=getattr(result, 'total_processing_time', None),
        analysis_id=None  # No database storage for public uploads
    )


@app.get("/results/{file_id}", response_model=AnalysisResult, tags=["Legacy Results"])
async def get_results(file_id: str):
    """Get analysis results for uploaded file (Public)"""
    if not upload_controller:
        raise HTTPException(status_code=503, detail="Service not initialized")
    
    return await upload_controller.get_result(file_id)


@app.delete("/cleanup", tags=["Maintenance"])
async def trigger_cleanup():
    """Manually trigger cleanup of expired files"""
    try:
        if minio_service:
            ttl = int(os.getenv('FILE_TTL', 3600))
            minio_service.cleanup_expired_files(ttl)
            return {"message": "Cleanup completed successfully"}
        else:
            raise HTTPException(status_code=503, detail="MinIO service not available")
    except Exception as e:
        logger.error(f"Cleanup failed: {e}")
        raise HTTPException(status_code=500, detail=f"Cleanup failed: {str(e)}")


async def periodic_cleanup():
    """Periodic cleanup task for expired files"""
    while True:
        try:
            await asyncio.sleep(3600)
            
            if minio_service:
                ttl = int(os.getenv('FILE_TTL', 3600))
                minio_service.cleanup_expired_files(ttl)
                logger.info("Periodic cleanup completed")
                
        except Exception as e:
            logger.error(f"Periodic cleanup error: {e}")


if __name__ == "__main__":
    import uvicorn
    
    host = os.getenv('APP_HOST', '0.0.0.0')
    port = int(os.getenv('APP_PORT', 8000))
    debug = os.getenv('APP_DEBUG', 'True').lower() == 'true'
    
    logger.info(f"Starting server on {host}:{port}")
    
    uvicorn.run("main:app", host=host, port=port, reload=debug, log_level="info")