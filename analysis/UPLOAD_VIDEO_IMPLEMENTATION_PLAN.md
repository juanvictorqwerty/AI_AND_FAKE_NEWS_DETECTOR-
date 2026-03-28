# Implementation Plan: `/upload/video` Endpoint with Smart Aggregation

## Overview

This document outlines the implementation plan for adding a `/upload/video` endpoint to the FastAPI backend service. The endpoint will accept multiple video frames (up to 60 images), process each frame using the existing AI analysis pipeline, and aggregate results using a confidence-weighted majority voting strategy.

## Current Architecture Analysis

### Existing Components

1. **`main.py`**: FastAPI application entry point with `/upload` and `/results/{file_id}` endpoints
2. **`controller/upload_controller.py`**: Handles single file uploads and background analysis
3. **`service/analysis_service.py`**: AI model inference using HuggingFace transformers
4. **`service/minio_service.py`**: MinIO storage operations
5. **`models/schemas.py`**: Pydantic models (already includes batch-related models)

### Key Observations

- The existing `/upload` endpoint processes single images
- Analysis runs asynchronously in background tasks
- Results are stored in-memory (suitable for development, needs Redis for production)
- The `schemas.py` already has batch-related models: `BatchUploadResponse`, `FrameAnalysisResult`, `BatchAnalysisResult`, `TemporalConsistencyResult`
- The AI model pipeline is synchronous but runs in a thread pool executor

## Implementation Plan

### Phase 1: Refactor Existing Code for Reusability

#### 1.1 Extract Image Analysis Logic

**File**: `analysis/controller/upload_controller.py`

Create a reusable method `analyze_single_image()` that encapsulates the core image analysis logic:

```python
async def analyze_single_image(
    self, 
    file: UploadFile, 
    background_tasks: BackgroundTasks = None
) -> Dict[str, Any]:
    """
    Analyze a single image file
    
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
```

#### 1.2 Update Existing `/upload` Endpoint

Refactor the existing `upload_file()` method to use the new `analyze_single_image()` method:

```python
async def upload_file(self, file: UploadFile, background_tasks: BackgroundTasks) -> UploadResponse:
    """Upload file and start analysis"""
    result = await self.analyze_single_image(file, background_tasks)
    
    return UploadResponse(
        success=True,
        file_id=result['file_id'],
        message="File uploaded successfully. Analysis started.",
        file_size=result['file_size'],
        file_type="image"
    )
```

### Phase 2: Implement Smart Aggregation Strategy

#### 2.1 Create Aggregation Service

**File**: `analysis/service/aggregation_service.py` (new file)

```python
from typing import List, Dict, Any, Optional
from loguru import logger
import os

class AggregationService:
    """Service for aggregating multiple frame analysis results"""
    
    def __init__(self, confidence_threshold: float = 0.5):
        """
        Initialize aggregation service
        
        Args:
            confidence_threshold: Minimum confidence to consider a frame valid
        """
        self.confidence_threshold = confidence_threshold
        logger.info(f"Aggregation service initialized with threshold: {confidence_threshold}")
    
    def aggregate_results(
        self, 
        frame_results: List[Dict[str, Any]]
    ) -> Dict[str, Any]:
        """
        Aggregate frame results using confidence-weighted majority voting
        
        Args:
            frame_results: List of individual frame analysis results
            
        Returns:
            Aggregated result with prediction, confidence, and per-frame data
        """
        if not frame_results:
            raise ValueError("No frame results to aggregate")
        
        # Filter out low-confidence frames
        valid_frames = [
            frame for frame in frame_results 
            if frame.get('confidence', 0) >= self.confidence_threshold
        ]
        
        if not valid_frames:
            logger.warning("All frames below confidence threshold, using all frames")
            valid_frames = frame_results
        
        logger.info(f"Aggregating {len(valid_frames)} valid frames out of {len(frame_results)} total")
        
        # Group by label and sum confidence scores
        label_confidence_sums = {}
        label_counts = {}
        
        for frame in valid_frames:
            label = frame.get('label')
            confidence = frame.get('confidence', 0)
            
            if label not in label_confidence_sums:
                label_confidence_sums[label] = 0
                label_counts[label] = 0
            
            label_confidence_sums[label] += confidence
            label_counts[label] += 1
        
        # Find label with highest total confidence
        best_label = max(label_confidence_sums.items(), key=lambda x: x[1])[0]
        total_confidence = label_confidence_sums[best_label]
        frame_count = label_counts[best_label]
        
        # Calculate weighted average confidence
        aggregated_confidence = total_confidence / frame_count if frame_count > 0 else 0
        
        # Prepare per-frame results
        frames = []
        for i, frame in enumerate(frame_results):
            frames.append({
                'filename': frame.get('filename', f'frame_{i}'),
                'prediction': frame.get('label'),
                'confidence': frame.get('confidence')
            })
        
        logger.info(f"Aggregation complete: {best_label} with confidence {aggregated_confidence:.4f}")
        
        return {
            'prediction': best_label,
            'confidence': aggregated_confidence,
            'frame_count': len(frame_results),
            'valid_frame_count': len(valid_frames),
            'aggregated_score': aggregated_confidence,
            'frames': frames,
            'label_distribution': {
                label: {
                    'count': label_counts[label],
                    'total_confidence': label_confidence_sums[label],
                    'avg_confidence': label_confidence_sums[label] / label_counts[label]
                }
                for label in label_counts
            }
        }
```

#### 2.2 Add Configuration for Aggregation

**File**: `analysis/.env`

Add configuration for aggregation threshold:

```env
# Aggregation Configuration
AGGREGATION_CONFIDENCE_THRESHOLD=0.5
```

### Phase 3: Implement `/upload/video` Endpoint

#### 3.1 Add Video Upload Method to Controller

**File**: `analysis/controller/upload_controller.py`

```python
async def upload_video_frames(
    self, 
    files: List[UploadFile], 
    background_tasks: BackgroundTasks = None
) -> Dict[str, Any]:
    """
    Upload and analyze multiple video frames
    
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
    
    logger.info(f"Processing {len(files)} video frames")
    
    # Process each frame
    frame_results = []
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
            
            # Analyze image synchronously for batch processing
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
            
        except Exception as e:
            logger.error(f"Error processing frame {i+1}: {e}")
            # Continue with other frames even if one fails
            frame_results.append({
                'filename': file.filename,
                'file_id': None,
                'label': None,
                'confidence': 0,
                'probabilities': {},
                'processing_time': 0,
                'error': str(e)
            })
    
    # Aggregate results using smart strategy
    aggregated_result = self.aggregation_service.aggregate_results(frame_results)
    
    total_processing_time = time.time() - start_time
    
    logger.info(f"Video frame processing complete: {len(frame_results)} frames in {total_processing_time:.2f}s")
    
    return {
        'status': 'success',
        'prediction': aggregated_result['prediction'],
        'confidence': aggregated_result['confidence'],
        'frame_count': aggregated_result['frame_count'],
        'valid_frame_count': aggregated_result['valid_frame_count'],
        'aggregated_score': aggregated_result['aggregated_score'],
        'frames': aggregated_result['frames'],
        'label_distribution': aggregated_result['label_distribution'],
        'total_processing_time': total_processing_time
    }
```

#### 3.2 Update Controller Constructor

**File**: `analysis/controller/upload_controller.py`

```python
from service.aggregation_service import AggregationService

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
        self.results_storage: Dict[str, AnalysisResult] = {}
        
        # Configuration
        self.max_file_size = 20 * 1024 * 1024  # 20MB
        self.allowed_extensions = {'.jpg', '.jpeg', '.png', '.webp', '.bmp'}
        self.allowed_mime_types = {'image/jpeg', 'image/png', 'image/jpg', 'image/webp', 'image/bmp'}
        
        # TTL configuration
        self.file_ttl = int(os.getenv('FILE_TTL', 3600))  # 1 hour
        self.result_ttl = int(os.getenv('RESULT_TTL', 3600))  # 1 hour
        
        logger.info("Upload controller initialized")
```

#### 3.3 Add Response Schema for Video Upload

**File**: `analysis/models/schemas.py`

```python
class VideoFrameResult(BaseModel):
    """Model for individual video frame result"""
    filename: str = Field(..., description="Original filename of the frame")
    prediction: Optional[str] = Field(None, description="AI prediction label")
    confidence: Optional[float] = Field(None, description="Confidence score (0-1)")

class VideoUploadResponse(BaseModel):
    """Response model for video frame upload"""
    status: str = Field(..., description="Status of the operation")
    prediction: str = Field(..., description="Aggregated prediction label")
    confidence: float = Field(..., description="Aggregated confidence score")
    frame_count: int = Field(..., description="Total number of frames processed")
    valid_frame_count: int = Field(..., description="Number of frames above confidence threshold")
    aggregated_score: float = Field(..., description="Weighted average confidence")
    frames: List[VideoFrameResult] = Field(..., description="Per-frame analysis results")
    label_distribution: Optional[Dict[str, Any]] = Field(None, description="Distribution of labels across frames")
    total_processing_time: Optional[float] = Field(None, description="Total processing time in seconds")
```

#### 3.4 Add Endpoint to Main Application

**File**: `analysis/main.py`

```python
from models.schemas import VideoUploadResponse

@app.post("/upload/video", response_model=VideoUploadResponse, tags=["Upload"])
async def upload_video_frames(
    files: List[UploadFile] = File(...),
    background_tasks: BackgroundTasks = None
):
    """
    Upload and analyze multiple video frames
    
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
```

### Phase 4: Performance Optimizations

#### 4.1 Batch Processing for GPU Inference

**File**: `analysis/service/analysis_service.py`

Add batch processing capability:

```python
async def analyze_images_batch(
    self, 
    images_data: List[bytes]
) -> List[Dict[str, Any]]:
    """
    Analyze multiple images in batch for better GPU utilization
    
    Args:
        images_data: List of image data as bytes
        
    Returns:
        List of analysis results
    """
    start_time = time.time()
    
    try:
        # Load all images
        images = []
        for image_data in images_data:
            image = Image.open(io.BytesIO(image_data))
            if image.mode != 'RGB':
                image = image.convert('RGB')
            images.append(image)
        
        logger.info(f"Analyzing batch of {len(images)} images")
        
        # Run batch inference
        loop = asyncio.get_event_loop()
        batch_results = await loop.run_in_executor(
            None,
            lambda: self.model(images)
        )
        
        # Process results
        results = []
        for i, result in enumerate(batch_results):
            if result and len(result) > 0:
                top_result = result[0]
                results.append({
                    'label': top_result['label'],
                    'confidence': top_result['score'],
                    'probabilities': {r['label']: r['score'] for r in result},
                    'processing_time': (time.time() - start_time) / len(images)
                })
            else:
                results.append({
                    'label': None,
                    'confidence': 0,
                    'probabilities': {},
                    'processing_time': 0,
                    'error': 'No results returned'
                })
        
        total_time = time.time() - start_time
        logger.info(f"Batch analysis completed: {len(images)} images in {total_time:.2f}s")
        
        return results
        
    except Exception as e:
        logger.error(f"Error in batch analysis: {e}")
        raise Exception(f"Failed to analyze images batch: {str(e)}")
```

#### 4.2 Memory-Efficient Processing

Process images one at a time to avoid loading all into memory:

```python
async def upload_video_frames(
    self, 
    files: List[UploadFile], 
    background_tasks: BackgroundTasks = None
) -> Dict[str, Any]:
    """
    Upload and analyze multiple video frames (memory-efficient)
    """
    start_time = time.time()
    
    # Validate number of files
    if not files:
        raise HTTPException(status_code=400, detail="No files provided")
    
    if len(files) > 60:
        raise HTTPException(
            status_code=400,
            detail=f"Too many files. Maximum allowed: 60, provided: {len(files)}"
        )
    
    logger.info(f"Processing {len(files)} video frames")
    
    # Process frames one at a time to avoid memory issues
    frame_results = []
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
            
            # Clear file content from memory
            del file_content
            del file_data
            
        except Exception as e:
            logger.error(f"Error processing frame {i+1}: {e}")
            frame_results.append({
                'filename': file.filename,
                'file_id': None,
                'label': None,
                'confidence': 0,
                'probabilities': {},
                'processing_time': 0,
                'error': str(e)
            })
    
    # Aggregate results
    aggregated_result = self.aggregation_service.aggregate_results(frame_results)
    
    total_processing_time = time.time() - start_time
    
    logger.info(f"Video frame processing complete: {len(frame_results)} frames in {total_processing_time:.2f}s")
    
    return {
        'status': 'success',
        'prediction': aggregated_result['prediction'],
        'confidence': aggregated_result['confidence'],
        'frame_count': aggregated_result['frame_count'],
        'valid_frame_count': aggregated_result['valid_frame_count'],
        'aggregated_score': aggregated_result['aggregated_score'],
        'frames': aggregated_result['frames'],
        'label_distribution': aggregated_result['label_distribution'],
        'total_processing_time': total_processing_time
    }
```

### Phase 5: Error Handling and Logging

#### 5.1 Enhanced Error Handling

```python
async def upload_video_frames(
    self, 
    files: List[UploadFile], 
    background_tasks: BackgroundTasks = None
) -> Dict[str, Any]:
    """
    Upload and analyze multiple video frames with comprehensive error handling
    """
    try:
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
        
        logger.info(f"Processing {len(files)} video frames")
        
        # Process frames
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
        
        # Aggregate results
        aggregated_result = self.aggregation_service.aggregate_results(frame_results)
        
        total_processing_time = time.time() - start_time
        
        logger.info(f"Video frame processing complete: {len(frame_results)} frames in {total_processing_time:.2f}s")
        
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
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in video frame upload: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Internal processing error: {str(e)}"
        )
```

#### 5.2 Enhanced Logging

```python
# Add to upload_video_frames method
logger.info(f"=== Video Frame Processing Started ===")
logger.info(f"Total frames: {len(files)}")
logger.info(f"Confidence threshold: {self.aggregation_service.confidence_threshold}")

# After processing
logger.info(f"=== Video Frame Processing Complete ===")
logger.info(f"Total frames processed: {len(frame_results)}")
logger.info(f"Failed frames: {len(failed_frames)}")
logger.info(f"Valid frames (above threshold): {aggregated_result['valid_frame_count']}")
logger.info(f"Final prediction: {aggregated_result['prediction']}")
logger.info(f"Aggregated confidence: {aggregated_result['confidence']:.4f}")
logger.info(f"Total processing time: {total_processing_time:.2f}s")
```

## File Structure

```
analysis/
├── main.py                          # Add /upload/video endpoint
├── controller/
│   └── upload_controller.py         # Add upload_video_frames method
├── service/
│   ├── analysis_service.py          # Add batch processing (optional)
│   ├── aggregation_service.py       # NEW: Smart aggregation logic
│   └── minio_service.py             # No changes needed
├── models/
│   └── schemas.py                   # Add VideoUploadResponse schema
├── .env                             # Add AGGREGATION_CONFIDENCE_THRESHOLD
└── requirements.txt                 # No changes needed
```

## API Specification

### Endpoint

```
POST /upload/video
```

### Request

- **Content-Type**: `multipart/form-data`
- **Body**: Multiple image files (field name: `files`)
- **Supported formats**: JPG, JPEG, PNG, WEBP, BMP
- **Maximum files**: 60

### Response

```json
{
  "status": "success",
  "prediction": "AI-generated",
  "confidence": 0.91,
  "frame_count": 24,
  "valid_frame_count": 22,
  "aggregated_score": 0.88,
  "frames": [
    {
      "filename": "frame_0.png",
      "prediction": "AI-generated",
      "confidence": 0.89
    },
    {
      "filename": "frame_1.png",
      "prediction": "Human",
      "confidence": 0.75
    }
  ],
  "label_distribution": {
    "AI-generated": {
      "count": 20,
      "total_confidence": 17.6,
      "avg_confidence": 0.88
    },
    "Human": {
      "count": 4,
      "total_confidence": 2.8,
      "avg_confidence": 0.70
    }
  },
  "total_processing_time": 12.45,
  "failed_frames": null
}
```

### Error Responses

#### 400 Bad Request - No Files
```json
{
  "detail": "No files provided"
}
```

#### 400 Bad Request - Too Many Files
```json
{
  "detail": "Too many files. Maximum allowed: 60, provided: 75"
}
```

#### 400 Bad Request - Invalid File Type
```json
{
  "detail": "Invalid file type. Allowed types: .jpg, .jpeg, .png, .webp, .bmp"
}
```

#### 500 Internal Server Error
```json
{
  "detail": "Internal processing error: <error message>"
}
```

## Testing Strategy

### Unit Tests

1. **Test aggregation logic**:
   - Test with valid frames above threshold
   - Test with frames below threshold
   - Test with mixed confidence levels
   - Test with empty frame list

2. **Test validation**:
   - Test with no files
   - Test with too many files
   - Test with invalid file types
   - Test with oversized files

### Integration Tests

1. **Test full workflow**:
   - Upload multiple frames
   - Verify aggregation
   - Check response format

2. **Test error handling**:
   - Test with corrupted files
   - Test with network errors
   - Test with model errors

### Performance Tests

1. **Test with maximum frames (60)**:
   - Measure processing time
   - Monitor memory usage
   - Check GPU utilization

2. **Test with various frame counts**:
   - 1 frame
   - 10 frames
   - 30 frames
   - 60 frames

## Deployment Considerations

### Environment Variables

Add to `.env`:

```env
# Aggregation Configuration
AGGREGATION_CONFIDENCE_THRESHOLD=0.5
```

### Resource Requirements

- **Memory**: Sufficient for processing up to 60 images
- **GPU**: Recommended for faster inference
- **Storage**: MinIO storage for temporary file storage

### Monitoring

- Log number of frames processed
- Log processing time
- Log aggregation results
- Monitor error rates

## Future Enhancements

1. **Background Processing**: Process frames asynchronously with job queue
2. **Batch GPU Inference**: Process multiple frames simultaneously on GPU
3. **Result Caching**: Cache aggregation results for repeated requests
4. **Webhook Support**: Notify client when processing completes
5. **Progress Tracking**: Real-time progress updates for long-running jobs
6. **Temporal Analysis**: Analyze frame sequences for temporal consistency
7. **Anomaly Detection**: Detect and flag anomalous frames
8. **Custom Thresholds**: Allow clients to specify confidence thresholds

## Summary

This implementation provides:

1. **Reusable code**: Refactored analysis logic for use in both endpoints
2. **Smart aggregation**: Confidence-weighted majority voting with configurable threshold
3. **Robust error handling**: Comprehensive validation and error messages
4. **Performance optimization**: Memory-efficient processing and optional batch inference
5. **Detailed logging**: Track processing metrics and errors
6. **Modular architecture**: Easy to extend with future features

The `/upload/video` endpoint will process up to 60 video frames, aggregate results using a sophisticated voting strategy, and return detailed per-frame analysis along with the aggregated prediction.
