from pydantic import BaseModel, Field
from typing import Optional, Dict, Any, List
from enum import Enum

class AnalysisStatus(str, Enum):
    """Status of the analysis process"""
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"

class UploadResponse(BaseModel):
    """Response model for file upload"""
    success: bool = Field(..., description="Whether upload was successful")
    file_id: str = Field(..., description="Unique identifier for the uploaded file")
    message: str = Field(..., description="Status message")
    file_size: Optional[int] = Field(None, description="File size in bytes")
    file_type: Optional[str] = Field(None, description="Type of file (image)")
    prediction: Optional[str] = Field(None, description="AI prediction label (e.g., 'AI' or 'Human')")
    confidence: Optional[float] = Field(None, description="Confidence score (0-1)")
    analysis_id: Optional[str] = Field(None, description="Database analysis record ID")

class AnalysisResult(BaseModel):
    """Model for AI analysis result"""
    file_id: str = Field(..., description="Unique identifier for the file")
    status: AnalysisStatus = Field(..., description="Current status of analysis")
    label: Optional[str] = Field(None, description="AI prediction label (e.g., 'AI' or 'Human')")
    confidence: Optional[float] = Field(None, description="Confidence score (0-1)")
    probabilities: Optional[Dict[str, float]] = Field(None, description="Probability for each class")
    error: Optional[str] = Field(None, description="Error message if analysis failed")
    processing_time: Optional[float] = Field(None, description="Time taken for analysis in seconds")

class ErrorResponse(BaseModel):
    """Error response model"""
    success: bool = Field(False, description="Always false for errors")
    error: str = Field(..., description="Error message")
    detail: Optional[str] = Field(None, description="Detailed error information")

class HealthResponse(BaseModel):
    """Health check response"""
    status: str = Field(..., description="Service status")
    model_loaded: bool = Field(..., description="Whether AI model is loaded")


class BatchUploadResponse(BaseModel):
    """Response model for batch file upload"""
    success: bool = Field(..., description="Whether upload was successful")
    session_id: str = Field(..., description="Unique session identifier for the batch")
    message: str = Field(..., description="Status message")
    frame_count: int = Field(..., description="Number of frames uploaded")
    file_type: Optional[str] = Field(None, description="Type of file (video)")


class FrameAnalysisResult(BaseModel):
    """Model for individual frame analysis result"""
    frame_index: int = Field(..., description="Index of the frame in the sequence")
    file_id: str = Field(..., description="Unique identifier for the frame file")
    label: Optional[str] = Field(None, description="AI prediction label (e.g., 'AI' or 'Human')")
    confidence: Optional[float] = Field(None, description="Confidence score (0-1)")
    probabilities: Optional[Dict[str, float]] = Field(None, description="Probability for each class")
    error: Optional[str] = Field(None, description="Error message if analysis failed")
    processing_time: Optional[float] = Field(None, description="Time taken for analysis in seconds")


class TemporalConsistencyResult(BaseModel):
    """Model for temporal consistency analysis result"""
    consistency_score: float = Field(..., description="Overall temporal consistency score (0-1)")
    label_consistency: float = Field(..., description="Consistency of labels across frames (0-1)")
    confidence_stability: float = Field(..., description="Stability of confidence scores across frames (0-1)")
    transition_smoothness: float = Field(..., description="Smoothness of transitions between frames (0-1)")
    anomaly_detected: bool = Field(..., description="Whether any anomalies were detected")
    anomaly_details: Optional[List[str]] = Field(None, description="Details of detected anomalies")


class BatchAnalysisResult(BaseModel):
    """Model for batch analysis result with temporal consistency"""
    session_id: str = Field(..., description="Unique session identifier")
    status: AnalysisStatus = Field(..., description="Current status of batch analysis")
    final_label: Optional[str] = Field(None, description="Final aggregated AI prediction label")
    confidence: Optional[float] = Field(None, description="Aggregated confidence score (0-1)")
    temporal_consistency: Optional[TemporalConsistencyResult] = Field(None, description="Temporal consistency analysis result")
    frame_results: Optional[List[FrameAnalysisResult]] = Field(None, description="Individual frame analysis results")
    error: Optional[str] = Field(None, description="Error message if batch analysis failed")
    processing_time: Optional[float] = Field(None, description="Total time taken for batch analysis in seconds")


class VideoFrameResult(BaseModel):
    """Model for individual video frame result"""
    filename: str = Field(..., description="Original filename of the frame")
    prediction: Optional[str] = Field(None, description="AI prediction label")
    confidence: Optional[float] = Field(None, description="Confidence score (0-1)")


class LabelDistribution(BaseModel):
    """Model for label distribution statistics"""
    count: int = Field(..., description="Number of frames with this label")
    total_confidence: float = Field(..., description="Sum of confidence scores for this label")
    avg_confidence: float = Field(..., description="Average confidence score for this label")


class VideoUploadResponse(BaseModel):
    """Response model for video frame upload with smart aggregation"""
    status: str = Field(..., description="Status of the operation (success/error)")
    prediction: Optional[str] = Field(None, description="Aggregated prediction label")
    confidence: float = Field(..., description="Aggregated confidence score (0-1)")
    frame_count: int = Field(..., description="Total number of frames processed")
    valid_frame_count: int = Field(..., description="Number of frames above confidence threshold")
    aggregated_score: float = Field(..., description="Weighted average confidence of selected class")
    frames: List[VideoFrameResult] = Field(..., description="Per-frame analysis results")
    label_distribution: Optional[Dict[str, LabelDistribution]] = Field(None, description="Distribution of labels across frames")
    total_processing_time: Optional[float] = Field(None, description="Total processing time in seconds")
    analysis_id: Optional[str] = Field(None, description="Database analysis record ID")
    error: Optional[str] = Field(None, description="Error message if processing failed")