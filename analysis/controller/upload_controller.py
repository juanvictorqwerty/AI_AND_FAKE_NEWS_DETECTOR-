import os
import asyncio
import time
from typing import Dict, Any, List
from fastapi import UploadFile, HTTPException, BackgroundTasks
from loguru import logger
from dotenv import load_dotenv

from service.minio_service import MinIOService
from service.analysis_service import AnalysisService
from service.aggregation_service import AggregationService
from models.schemas import UploadResponse, AnalysisResult, AnalysisStatus

# Load environment variables
load_dotenv()

class UploadController:
    """Controller for handling file uploads and analysis"""
    
    def __init__(self, minio_service: MinIOService, analysis_service: AnalysisService):
        """
        Initialize upload controller
        
        Args:
            minio_service: MinIO service instance
            analysis_service: Analysis service instance
        """
        self.minio_service = minio_service
        self.analysis_service = analysis_service
        
        # Initialize aggregation service
        confidence_threshold = float(os.getenv('AGGREGATION_CONFIDENCE_THRESHOLD', 0.5))
        self.aggregation_service = AggregationService(confidence_threshold)
        
        # In-memory storage for analysis results
        # In production, use Redis or database
        self.results_storage: Dict[str, AnalysisResult] = {}
        
        # Configuration
        self.max_file_size = 20 * 1024 * 1024  # 20MB
        self.allowed_extensions = {'.jpg', '.jpeg', '.png', '.webp', '.bmp'}
        self.allowed_mime_types = {'image/jpeg', 'image/png', 'image/jpg', 'image/webp', 'image/bmp'}
        
        # TTL configuration
        self.file_ttl = int(os.getenv('FILE_TTL', 3600))  # 1 hour
        self.result_ttl = int(os.getenv('RESULT_TTL', 3600))  # 1 hour
        
        logger.info("Upload controller initialized")
    
    async def upload_file(self, file: UploadFile, background_tasks: BackgroundTasks) -> UploadResponse:
        """
        Upload file and start analysis
        
        Args:
            file: Uploaded file
            background_tasks: FastAPI background tasks
            
        Returns:
            UploadResponse with file_id and status
        """
        try:
            # Validate file
            await self._validate_file(file)
            
            # Read file content
            file_content = await file.read()
            file_size = len(file_content)
            
            # Get file extension
            file_extension = os.path.splitext(file.filename)[1].lower()
            
            # Upload to MinIO
            upload_result = self.minio_service.upload_file(file_content, file_extension)
            file_id = upload_result['file_id']
            object_name = upload_result['object_name']
            
            logger.info(f"File uploaded: {file_id} ({file_size} bytes)")
            
            # Initialize result as processing
            self.results_storage[file_id] = AnalysisResult(
                file_id=file_id,
                status=AnalysisStatus.PROCESSING
            )
            
            # Start background analysis
            background_tasks.add_task(
                self._process_file_background,
                file_id=file_id,
                object_name=object_name
            )
            
            return UploadResponse(
                success=True,
                file_id=file_id,
                message="File uploaded successfully. Analysis started.",
                file_size=file_size,
                file_type="image"
            )
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error uploading file: {e}")
            raise HTTPException(status_code=500, detail=f"Upload failed: {str(e)}")
    
    async def analyze_single_image(
        self,
        file: UploadFile,
        background_tasks: BackgroundTasks = None
    ) -> Dict[str, Any]:
        """
        Analyze a single image file (reusable method)
        
        This method encapsulates the core image analysis logic and can be used
        by both /upload and /upload/video endpoints.
        
        Args:
            file: Uploaded image file
            background_tasks: Optional background tasks for async processing
            
        Returns:
            Dictionary with analysis results or file_id for background processing
        """
        # Validate file
        await self._validate_file(file)
        
        # Read file content
        file_content = await file.read()
        file_size = len(file_content)
        
        # Get file extension
        file_extension = os.path.splitext(file.filename)[1].lower()
        
        # Upload to MinIO
        upload_result = self.minio_service.upload_file(file_content, file_extension)
        file_id = upload_result['file_id']
        object_name = upload_result['object_name']
        
        logger.info(f"File uploaded: {file_id} ({file_size} bytes)")
        
        # If background_tasks provided, process asynchronously
        if background_tasks:
            # Initialize result as processing
            self.results_storage[file_id] = AnalysisResult(
                file_id=file_id,
                status=AnalysisStatus.PROCESSING
            )
            
            # Start background analysis
            background_tasks.add_task(
                self._process_file_background,
                file_id=file_id,
                object_name=object_name
            )
            
            return {
                'file_id': file_id,
                'status': 'processing',
                'file_size': file_size
            }
        else:
            # Process synchronously (for batch processing)
            file_data = self.minio_service.download_file(object_name)
            analysis_result = await self.analysis_service.analyze_image(file_data)
            
            # Schedule cleanup
            asyncio.create_task(self._cleanup_file_after_delay(file_id, object_name))
            
            return {
                'file_id': file_id,
                'status': 'completed',
                'filename': file.filename,
                'label': analysis_result['label'],
                'confidence': analysis_result['confidence'],
                'probabilities': analysis_result['probabilities'],
                'processing_time': analysis_result['processing_time']
            }
    
    async def upload_video_frames(
        self,
        files: List[UploadFile],
        background_tasks: BackgroundTasks = None
    ) -> Dict[str, Any]:
        """
        Upload and analyze multiple video frames with smart aggregation
        
        This method processes up to 60 video frames, analyzes each using the
        AI model, and aggregates results using confidence-weighted majority voting.
        
        Args:
            files: List of image files (video frames)
            background_tasks: Optional background tasks
            
        Returns:
            Dictionary with aggregated analysis results
        """
        start_time = time.time()
        
        # Validate number of files
        if not files:
            raise HTTPException(
                status_code=400,
                detail="No files provided"
            )
        
        if len(files) > 60:
            raise HTTPException(
                status_code=400,
                detail=f"Too many files. Maximum allowed: 60, provided: {len(files)}"
            )
        
        logger.info(f"=== Video Frame Processing Started ===")
        logger.info(f"Total frames: {len(files)}")
        logger.info(f"Confidence threshold: {self.aggregation_service.confidence_threshold}")
        
        # Process frames one at a time to avoid memory issues
        frame_results = []
        failed_frames = []
        
        for i, file in enumerate(files):
            try:
                # Validate file
                await self._validate_file(file)
                
                # Read file content
                file_content = await file.read()
                
                # Get file extension
                file_extension = os.path.splitext(file.filename)[1].lower()
                
                # Upload to MinIO
                upload_result = self.minio_service.upload_file(file_content, file_extension)
                file_id = upload_result['file_id']
                object_name = upload_result['object_name']
                
                # Analyze image
                file_data = self.minio_service.download_file(object_name)
                analysis_result = await self.analysis_service.analyze_image(file_data)
                
                # Schedule cleanup
                asyncio.create_task(self._cleanup_file_after_delay(file_id, object_name))
                
                # Store frame result
                frame_results.append({
                    'filename': file.filename,
                    'file_id': file_id,
                    'label': analysis_result['label'],
                    'confidence': analysis_result['confidence'],
                    'probabilities': analysis_result['probabilities'],
                    'processing_time': analysis_result['processing_time']
                })
                
                logger.info(f"Frame {i+1}/{len(files)} processed: {analysis_result['label']} ({analysis_result['confidence']:.4f})")
                
                # Clear from memory
                del file_content
                del file_data
                
            except HTTPException:
                raise
            except Exception as e:
                logger.error(f"Error processing frame {i+1} ({file.filename}): {e}")
                failed_frames.append({
                    'filename': file.filename,
                    'error': str(e)
                })
                # Continue with other frames
                continue
        
        # Check if we have any successful results
        if not frame_results:
            raise HTTPException(
                status_code=500,
                detail=f"All frames failed to process. Errors: {failed_frames}"
            )
        
        # Aggregate results using smart strategy
        aggregated_result = self.aggregation_service.aggregate_results(frame_results)
        
        total_processing_time = time.time() - start_time
        
        logger.info(f"=== Video Frame Processing Complete ===")
        logger.info(f"Total frames processed: {len(frame_results)}")
        logger.info(f"Failed frames: {len(failed_frames)}")
        logger.info(f"Valid frames (above threshold): {aggregated_result['valid_frame_count']}")
        logger.info(f"Final prediction: {aggregated_result['prediction']}")
        logger.info(f"Aggregated confidence: {aggregated_result['confidence']:.4f}")
        logger.info(f"Total processing time: {total_processing_time:.2f}s")
        
        return {
            'status': 'success',
            'prediction': aggregated_result['prediction'],
            'confidence': aggregated_result['confidence'],
            'frame_count': aggregated_result['frame_count'],
            'valid_frame_count': aggregated_result['valid_frame_count'],
            'aggregated_score': aggregated_result['aggregated_score'],
            'frames': aggregated_result['frames'],
            'label_distribution': aggregated_result['label_distribution'],
            'total_processing_time': total_processing_time,
            'failed_frames': failed_frames if failed_frames else None
        }
    
    async def _validate_file(self, file: UploadFile):
        """
        Validate uploaded file
        
        Args:
            file: Uploaded file
            
        Raises:
            HTTPException: If validation fails
        """
        # Check file size
        file.file.seek(0, 2)  # Seek to end
        file_size = file.file.tell()
        file.file.seek(0)  # Reset to beginning
        
        if file_size > self.max_file_size:
            raise HTTPException(
                status_code=400,
                detail=f"File size exceeds maximum limit of 20MB (current: {file_size / (1024*1024):.2f}MB)"
            )
        
        # Check file extension
        file_extension = os.path.splitext(file.filename)[1].lower()
        if file_extension not in self.allowed_extensions:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid file type. Allowed types: {', '.join(self.allowed_extensions)}"
            )
        
        # Check MIME type
        if file.content_type not in self.allowed_mime_types:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid MIME type. Allowed types: {', '.join(self.allowed_mime_types)}"
            )
        
        logger.info(f"File validated: {file.filename} ({file_size} bytes)")
    
    async def _process_file_background(self, file_id: str, object_name: str):
        """
        Process file in background
        
        Args:
            file_id: Unique file identifier
            object_name: MinIO object name
        """
        try:
            logger.info(f"Starting background analysis for file: {file_id}")
            
            # Download file from MinIO
            file_data = self.minio_service.download_file(object_name)
            
            # Analyze image
            analysis_result = await self.analysis_service.analyze_image(file_data)
            
            # Update result
            self.results_storage[file_id] = AnalysisResult(
                file_id=file_id,
                status=AnalysisStatus.COMPLETED,
                label=analysis_result['label'],
                confidence=analysis_result['confidence'],
                probabilities=analysis_result['probabilities'],
                processing_time=analysis_result['processing_time']
            )
            
            logger.info(f"Analysis completed for file: {file_id}")
            
            # Schedule file cleanup
            asyncio.create_task(self._cleanup_file_after_delay(file_id, object_name))
            
        except Exception as e:
            logger.error(f"Error processing file {file_id}: {e}")
            
            # Update result with error
            self.results_storage[file_id] = AnalysisResult(
                file_id=file_id,
                status=AnalysisStatus.FAILED,
                error=str(e)
            )
    
    async def _cleanup_file_after_delay(self, file_id: str, object_name: str):
        """
        Clean up file after TTL
        
        Args:
            file_id: Unique file identifier
            object_name: MinIO object name
        """
        try:
            # Wait for TTL
            await asyncio.sleep(self.file_ttl)
            
            # Delete file from MinIO
            self.minio_service.delete_file(object_name)
            logger.info(f"File cleaned up after TTL: {file_id}")
            
        except Exception as e:
            logger.error(f"Error cleaning up file {file_id}: {e}")
    
    async def get_result(self, file_id: str) -> AnalysisResult:
        """
        Get analysis result for file
        
        Args:
            file_id: Unique file identifier
            
        Returns:
            AnalysisResult with status and data
        """
        if file_id not in self.results_storage:
            raise HTTPException(
                status_code=404,
                detail=f"File ID not found: {file_id}"
            )
        
        result = self.results_storage[file_id]
        
        # Check if result has expired
        if result.status == AnalysisStatus.COMPLETED:
            # In production, check timestamp and expire if needed
            pass
        
        return result
    
    async def cleanup_expired_results(self):
        """Clean up expired results from memory"""
        try:
            # In production, implement proper TTL-based cleanup
            # For now, this is a placeholder
            logger.info("Cleanup expired results called")
        except Exception as e:
            logger.error(f"Error cleaning up expired results: {e}")
