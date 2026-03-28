import os
import asyncio
from contextlib import asynccontextmanager
from typing import List
from fastapi import FastAPI, UploadFile, File, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from loguru import logger
from dotenv import load_dotenv

from service.minio_service import MinIOService
from service.analysis_service import AnalysisService
from controller.upload_controller import UploadController
from models.schemas import UploadResponse, AnalysisResult, HealthResponse, VideoUploadResponse

# Load environment variables
load_dotenv()

# Initialize services
minio_service = None
analysis_service = None
upload_controller = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Lifespan context manager for FastAPI
    Handles startup and shutdown events
    """
    global minio_service, analysis_service, upload_controller
    
    # Startup
    logger.info("Starting AI Image Analysis Service...")
    
    try:
        # Initialize MinIO service
        minio_service = MinIOService()
        logger.info("MinIO service initialized")
        
        # Initialize Analysis service
        analysis_service = AnalysisService()
        logger.info("Analysis service initialized")
        
        # Initialize Upload controller
        upload_controller = UploadController(minio_service, analysis_service)
        logger.info("Upload controller initialized")
        
        # Start background cleanup task
        asyncio.create_task(periodic_cleanup())
        
        logger.info("AI Image Analysis Service started successfully")
        
    except Exception as e:
        logger.error(f"Error during startup: {e}")
        raise
    
    yield
    
    # Shutdown
    logger.info("Shutting down AI Image Analysis Service...")

# Create FastAPI app
app = FastAPI(
    title="AI Image Analysis Service",
    description="Backend service for AI-powered image analysis",
    version="1.0.0",
    lifespan=lifespan
)

# Configure CORS
cors_origins = os.getenv('CORS_ORIGINS', '["http://localhost:3000", "http://localhost:8080", "http://localhost:5000"]')
# Parse CORS origins from string
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

# Configure logging
logger.add(
    "logs/app.log",
    rotation="10 MB",
    retention="7 days",
    level="INFO"
)

@app.get("/", tags=["Root"])
async def root():
    """Root endpoint"""
    return {
        "message": "AI Image Analysis Service",
        "version": "1.0.0",
        "docs": "/docs"
    }

@app.get("/health", response_model=HealthResponse, tags=["Health"])
async def health_check():
    """
    Health check endpoint
    
    Returns:
        HealthResponse with service status
    """
    try:
        # Check MinIO connection
        minio_connected = minio_service.check_connection() if minio_service else False
        
        # Check if model is loaded
        model_loaded = analysis_service.is_model_loaded() if analysis_service else False
        
        return HealthResponse(
            status="healthy" if (minio_connected and model_loaded) else "degraded",
            minio_connected=minio_connected,
            model_loaded=model_loaded
        )
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return HealthResponse(
            status="unhealthy",
            minio_connected=False,
            model_loaded=False
        )

@app.post("/upload", response_model=UploadResponse, tags=["Upload"])
async def upload_file(
    file: UploadFile = File(...),
    background_tasks: BackgroundTasks = None
):
    """
    Upload image file for AI analysis
    
    Args:
        file: Image file (PNG, JPG, JPEG)
        background_tasks: FastAPI background tasks
        
    Returns:
        UploadResponse with file_id and status
        
    Raises:
        HTTPException: If validation fails or upload error
    """
    if not upload_controller:
        raise HTTPException(status_code=503, detail="Service not initialized")
    
    return await upload_controller.upload_file(file, background_tasks)

@app.post("/upload/video", response_model=VideoUploadResponse, tags=["Upload"])
async def upload_video_frames(
    files: List[UploadFile] = File(...),
    background_tasks: BackgroundTasks = None
):
    """
    Upload and analyze multiple video frames with smart aggregation
    
    This endpoint accepts up to 60 image files (video frames), processes each
    using the AI analysis pipeline, and aggregates results using confidence-weighted
    majority voting.
    
    Args:
        files: List of image files (JPG, JPEG, PNG, WEBP, BMP)
        background_tasks: FastAPI background tasks
        
    Returns:
        VideoUploadResponse with aggregated analysis results
        
    Raises:
        HTTPException: If validation fails or processing error
    """
    if not upload_controller:
        raise HTTPException(status_code=503, detail="Service not initialized")
    
    return await upload_controller.upload_video_frames(files, background_tasks)

@app.get("/results/{file_id}", response_model=AnalysisResult, tags=["Results"])
async def get_results(file_id: str):
    """
    Get analysis results for uploaded file
    
    Args:
        file_id: Unique file identifier
        
    Returns:
        AnalysisResult with status and analysis data
        
    Raises:
        HTTPException: If file_id not found or invalid
    """
    if not upload_controller:
        raise HTTPException(status_code=503, detail="Service not initialized")
    
    return await upload_controller.get_result(file_id)

@app.delete("/cleanup", tags=["Maintenance"])
async def trigger_cleanup():
    """
    Manually trigger cleanup of expired files
    
    Returns:
        Cleanup status message
    """
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
    """
    Periodic cleanup task for expired files
    Runs every hour
    """
    while True:
        try:
            await asyncio.sleep(3600)  # Run every hour
            
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
    
    uvicorn.run(
        "main:app",
        host=host,
        port=port,
        reload=debug,
        log_level="info"
    )
