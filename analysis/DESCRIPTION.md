# Analysis Service - Python Backend

## Overview

The AI analysis engine for the AI and Fake News Detector system. This Python FastAPI service handles machine learning model inference, image analysis, video processing, and provides real-time analysis capabilities for the entire platform.

## Purpose

This service provides:
- **Image Analysis**: Detect AI-generated images, authenticate media, analyze content
- **Video Processing**: Extract frames, analyze video content, generate thumbnails
- **Text Analysis**: Perform linguistic analysis and fact-checking support
- **Model Inference**: Run transformer models and deep learning models
- **File Management**: Handle uploads, storage, and cleanup via MinIO
- **Async Processing**: Non-blocking background task processing
- **Result Caching**: Cache analysis results for performance

## Key Responsibilities

### Image Analysis
- Authenticity detection (real vs. AI-generated)
- Content classification
- Sensitivity/explicit content detection
- Face detection and recognition
- Object detection and recognition
- Confidence score calculation

### Video Processing
- Frame extraction from video files
- Thumbnail generation
- Video metadata extraction
- Duration calculation
- Resolution and codec detection
- Frame-by-frame analysis

### File Handling
- Secure file upload validation
- Temporary file storage in MinIO
- Automatic cleanup of old files
- File format and size validation
- Virus/malware scanning support

### Model Management
- Load and cache ML models in memory
- Manage model versions
- Model hot-reloading
- GPU acceleration support
- Model performance monitoring

## Technology Stack

| Technology | Purpose |
|-----------|---------|
| **Python 3.9+** | Programming language |
| **FastAPI** | Web framework |
| **PyTorch** | Deep learning framework |
| **Transformers** | Hugging Face models |
| **OpenCV** | Computer vision |
| **Pillow** | Image processing |
| **MinIO** | Object storage |
| **Pydantic** | Data validation |
| **Uvicorn** | ASGI server |
| **Docker** | Containerization |

## Project Structure

```
analysis/
├── main.py                      # FastAPI application entry point
│
├── models/
│   ├── schemas.py              # Pydantic models for API
│   ├── image_model.py          # Image analysis models
│   ├── video_model.py          # Video processing models
│   └── text_model.py           # Text analysis models
│
├── service/
│   ├── analysis_service.py     # Core analysis logic
│   ├── minio_service.py        # MinIO file operations
│   ├── model_service.py        # Model loading and inference
│   ├── preprocessing_service.py # Data preprocessing
│   └── cache_service.py        # Result caching
│
├── controller/
│   ├── upload_controller.py    # File upload handling
│   ├── analysis_controller.py  # Analysis endpoints
│   └── health_controller.py    # Health check endpoints
│
├── middleware/
│   ├── auth_middleware.py      # Request authentication
│   ├── error_handler.py        # Exception handling
│   └── logging_middleware.py   # Request logging
│
├── utils/
│   ├── config.py               # Configuration management
│   ├── constants.py            # Application constants
│   ├── validators.py           # Input validation
│   └── helpers.py              # Utility functions
│
├── logs/                        # Application logs
├── requirements.txt             # Python dependencies
├── .env.example                # Environment template
├── Dockerfile                  # Container configuration
└── README.md                   # Quick start guide
```

## Core Components

### Analysis Service (`service/analysis_service.py`)
**Handles**: Main analysis logic
- Image analysis pipeline
- Video frame extraction and analysis
- Result aggregation
- Confidence score calculation
- Error handling

### MinIO Service (`service/minio_service.py`)
**Handles**: File storage operations
- File upload to MinIO
- File retrieval
- Temporary file management
- Automatic cleanup with TTL
- Access control and permissions

### Model Service (`service/model_service.py`)
**Handles**: ML model operations
- Model loading and initialization
- Model caching in memory
- Inference execution
- GPU/CPU selection
- Model version management

### Preprocessing Service (`service/preprocessing_service.py`)
**Handles**: Data preparation
- Image normalization
- Format conversion
- Resize and crop operations
- Video frame extraction
- Data augmentation

## Key Endpoints

### Health & Status
```
GET  /health                    Overall health check
GET  /health/deep              Deep health check with dependencies
GET  /status                   Service status and model info
```

### Image Analysis
```
POST /analyze/image             Analyze uploaded image
POST /analyze/image/url         Analyze image from URL
POST /analyze/batch            Batch analyze multiple images
GET  /analyze/image/:id        Get stored image analysis
```

### Video Processing
```
POST /analyze/video             Analyze video file
POST /analyze/video/frames      Extract and analyze frames
POST /analyze/video/thumbnail   Generate video thumbnail
GET  /analyze/video/:id        Get video analysis result
```

### File Management
```
POST /upload/image              Upload and store image
POST /upload/video              Upload and store video
DELETE /files/:id               Delete temporary file
GET  /files/status/:id         Get file storage status
```

### Model Management
```
GET  /models                    List loaded models
GET  /models/:name             Get model information
POST /models/reload            Reload models
GET  /models/performance       Model performance metrics
```

## Request/Response Examples

### Image Analysis Request
```json
{
  "image_data": "base64_encoded_image",
  "analysis_type": "authenticity",
  "confidence_threshold": 0.7,
  "return_details": true
}
```

### Image Analysis Response
```json
{
  "id": "analysis_12345",
  "status": "completed",
  "analysis_type": "authenticity",
  "results": {
    "is_ai_generated": false,
    "confidence": 0.92,
    "class": "authentic",
    "details": {
      "texture_analysis": 0.88,
      "artifact_detection": 0.95,
      "metadata_analysis": 0.89
    }
  },
  "processing_time_ms": 342,
  "timestamp": "2026-05-21T10:30:00Z"
}
```

### Video Analysis Request
```json
{
  "video_id": "video_file_id",
  "frame_sampling": 5,
  "analyze_frames": true,
  "generate_thumbnail": true
}
```

## Environment Configuration

Create `.env`:
```env
# Application
DEBUG=False
ENVIRONMENT=production

# Server
HOST=0.0.0.0
PORT=7860
WORKERS=4

# Models
MODEL_CACHE_DIR=/models
GPU_ENABLED=True
DEVICE=cuda  # or cpu

# MinIO
MINIO_ENDPOINT=localhost:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin
MINIO_BUCKET=analysis-files
MINIO_USE_SSL=False

# Logging
LOG_LEVEL=INFO
LOG_FILE=/logs/analysis.log

# Performance
MAX_UPLOAD_SIZE=52428800  # 50MB
REQUEST_TIMEOUT=300
CACHE_TTL=3600
```

## Development Workflow

### Setup
```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Create necessary directories
mkdir -p models logs
```

### Running
```bash
# Development with hot reload
uvicorn main:app --reload --host 0.0.0.0 --port 7860

# Production
gunicorn main:app -w 4 -k uvicorn.workers.UvicornWorker

# Docker
docker build -t analysis-service .
docker run -p 7860:7860 \
  -e MINIO_ENDPOINT=... \
  -e GPU_ENABLED=False \
  analysis-service
```

### Testing
```bash
# Run all tests
pytest

# Run specific test
pytest tests/test_analysis.py

# Test with coverage
pytest --cov=./ tests/
```

## ML Models Used

### Image Analysis Models
- **ResNet-50/152**: Feature extraction and classification
- **EfficientNet**: Lightweight authenticity detection
- **Inception-v3**: Image quality assessment
- **YOLO**: Object detection
- **Face Recognition Model**: Face detection and analysis

### Text Analysis Models
- **BERT**: Semantic analysis
- **RoBERTa**: Classification tasks
- **DistilBERT**: Lightweight text processing

### Detection Capabilities
- AI-generated image detection
- Deepfake detection
- Tampered/edited image detection
- Inappropriate content detection
- Metadata analysis

## Performance Considerations

### Optimization
- Model batching for multiple requests
- GPU acceleration for inference
- Model caching to avoid reloading
- Response caching for identical requests
- Async processing for I/O operations

### Scalability
- Stateless design for horizontal scaling
- Load balancing support
- Queue-based processing for heavy tasks
- Database connection pooling

### Resource Management
- Memory-efficient model loading
- Automatic garbage collection
- File cleanup with TTL
- Request timeout management

## Error Handling

- **400 Bad Request**: Invalid input format
- **413 Payload Too Large**: File exceeds size limit
- **415 Unsupported Media Type**: Unsupported file format
- **429 Too Many Requests**: Rate limit exceeded
- **500 Internal Server Error**: Model inference failure
- **503 Service Unavailable**: Models not loaded or GPU unavailable

## Security Features

- Request authentication via API keys
- Rate limiting per client
- File upload validation
- Malware scanning support
- HTTPS/TLS support
- CORS configuration
- Request/response logging for audit

## Monitoring & Logging

- Structured JSON logging
- Request/response tracking
- Model inference timing
- GPU/CPU usage monitoring
- Memory consumption tracking
- Error rate monitoring
- Health check endpoints

## Integration with NestJS Backend

```
NestJS Backend
    ↓
HTTP POST /analyze/image
    ↓
Analysis Service
    ↓
Load Models
    ↓
Process Image
    ↓
Return Results
    ↓
NestJS Backend (caches & stores)
    ↓
Flutter App
```

## Deployment Options

### Docker Compose
```yaml
services:
  analysis:
    build: ./analysis
    ports:
      - "7860:7860"
    environment:
      - MINIO_ENDPOINT=minio:9000
      - GPU_ENABLED=false
    depends_on:
      - minio
```

### Kubernetes
- CPU/GPU node selection
- Resource limits and requests
- Health probes
- Auto-scaling policies

### Cloud Platforms
- AWS: EC2 with GPU or SageMaker
- Google Cloud: Vertex AI or Compute Engine
- Azure: Virtual Machines with GPU
- Heroku: Docker container deployment

## Related Documentation

- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [PyTorch Documentation](https://pytorch.org/docs/)
- [Transformers Library](https://huggingface.co/transformers/)
- [OpenCV Documentation](https://docs.opencv.org/)

---

**Last Updated**: May 2026
**Version**: 1.0.0
**Framework**: FastAPI
**Python Version**: 3.9+
