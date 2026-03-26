# AI Image Analysis Backend Service

FastAPI backend service for AI-powered image analysis with MinIO storage integration.

## Features

- **File Upload**: Upload images (PNG, JPG, JPEG) up to 20MB
- **AI Analysis**: Automatic image analysis using transformer models
- **MinIO Storage**: Temporary file storage with automatic cleanup
- **Async Processing**: Background AI analysis without blocking requests
- **Health Monitoring**: Health check endpoint for service status
- **CORS Support**: Configurable CORS for frontend access
- **Logging**: Comprehensive logging with loguru

## Architecture

```
analysis/
├── main.py                    # FastAPI application entry point
├── requirements.txt           # Python dependencies
├── .env                       # Environment configuration
├── models/
│   └── schemas.py            # Pydantic models for request/response
├── service/
│   ├── minio_service.py      # MinIO storage operations
│   └── analysis_service.py   # AI model inference
├── controller/
│   └── upload_controller.py  # Upload and analysis orchestration
└── logs/                     # Application logs
```

## API Endpoints

### 1. Health Check
```
GET /health
```
Returns service health status including MinIO connection and model loading status.

**Response:**
```json
{
  "status": "healthy",
  "minio_connected": true,
  "model_loaded": true
}
```

### 2. Upload File
```
POST /upload
```
Upload an image file for AI analysis.

**Request:**
- Content-Type: `multipart/form-data`
- Body: Image file (PNG, JPG, JPEG)
- Max size: 20MB

**Response:**
```json
{
  "success": true,
  "file_id": "550e8400-e29b-41d4-a716-446655440000",
  "message": "File uploaded successfully. Analysis started.",
  "file_size": 1024000,
  "file_type": "image"
}
```

**Error Responses:**
- `400`: File too large or invalid format
- `500`: Upload failed

### 3. Get Results
```
GET /results/{file_id}
```
Get analysis results for an uploaded file.

**Response (Processing):**
```json
{
  "file_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "processing"
}
```

**Response (Completed):**
```json
{
  "file_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "completed",
  "label": "AI",
  "confidence": 0.95,
  "probabilities": {
    "AI": 0.95,
    "Human": 0.05
  },
  "processing_time": 2.34
}
```

**Response (Failed):**
```json
{
  "file_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "failed",
  "error": "Error message"
}
```

**Error Responses:**
- `404`: File ID not found

### 4. Manual Cleanup
```
DELETE /cleanup
```
Manually trigger cleanup of expired files.

**Response:**
```json
{
  "message": "Cleanup completed successfully"
}
```

## Setup

### 1. Install Dependencies

```bash
cd analysis
pip install -r requirements.txt
```

### 2. Configure Environment

Edit `.env` file with your MinIO credentials:

```env
# MinIO Configuration
MINIO_ENDPOINT=localhost:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin
MINIO_SECURE=False
MINIO_BUCKET_NAME=ai-analysis

# AI Model Configuration
AI_MODEL_NAME=Ateeqq/ai-vs-human-image-detector

# Application Configuration
APP_HOST=0.0.0.0
APP_PORT=8000
APP_DEBUG=True

# TTL Configuration (in seconds)
FILE_TTL=3600  # 1 hour for file storage
RESULT_TTL=3600  # 1 hour for result storage

# CORS Configuration
CORS_ORIGINS=["http://localhost:3000", "http://localhost:8080", "http://localhost:5000"]
```

### 3. Start MinIO

Using Docker:
```bash
docker run -d \
  -p 9000:9000 \
  -p 9001:9001 \
  --name minio \
  -e "MINIO_ROOT_USER=minioadmin" \
  -e "MINIO_ROOT_PASSWORD=minioadmin" \
  minio/minio server /data --console-address ":9001"
```

### 4. Run Service

```bash
python main.py
```

Or using uvicorn:
```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### 5. Access API Documentation

Open browser to: http://localhost:8000/docs

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MINIO_ENDPOINT` | `localhost:9000` | MinIO server endpoint |
| `MINIO_ACCESS_KEY` | `minioadmin` | MinIO access key |
| `MINIO_SECRET_KEY` | `minioadmin` | MinIO secret key |
| `MINIO_SECURE` | `False` | Use HTTPS for MinIO |
| `MINIO_BUCKET_NAME` | `ai-analysis` | MinIO bucket name |
| `AI_MODEL_NAME` | `Ateeqq/ai-vs-human-image-detector` | HuggingFace model name |
| `APP_HOST` | `0.0.0.0` | Application host |
| `APP_PORT` | `8000` | Application port |
| `APP_DEBUG` | `True` | Enable debug mode |
| `FILE_TTL` | `3600` | File storage TTL (seconds) |
| `RESULT_TTL` | `3600` | Result storage TTL (seconds) |
| `CORS_ORIGINS` | `["http://localhost:3000", ...]` | Allowed CORS origins |

## Validation Rules

### File Upload
- **Max Size**: 20MB
- **Allowed Types**: PNG, JPG, JPEG
- **MIME Types**: image/jpeg, image/png, image/jpg

### AI Analysis
- **Model**: Ateeqq/ai-vs-human-image-detector
- **Output**: Label (AI/Human), Confidence score, Probabilities
- **Processing**: Asynchronous background task

## Error Handling

All endpoints return structured JSON responses:

**Success:**
```json
{
  "success": true,
  "data": {...}
}
```

**Error:**
```json
{
  "success": false,
  "error": "Error message",
  "detail": "Detailed error information"
}
```

## Logging

Logs are written to:
- Console (stdout)
- `logs/app.log` (rotated, 7 days retention)

Log levels: DEBUG, INFO, WARNING, ERROR

## Performance

- **Async Endpoints**: All endpoints are async
- **Background Processing**: AI analysis runs in background
- **Connection Pooling**: MinIO client uses connection pooling
- **Model Caching**: AI model loaded once at startup

## Security

- **CORS**: Configurable allowed origins
- **File Validation**: Extension and MIME type validation
- **Size Limits**: 20MB max file size
- **Temporary Storage**: Files auto-deleted after TTL

## Troubleshooting

### MinIO Connection Error
- Check MinIO is running: `docker ps`
- Verify credentials in `.env`
- Check network connectivity

### Model Loading Error
- Ensure sufficient memory (4GB+ recommended)
- Check internet connection for model download
- Verify transformers version compatibility

### Upload Fails
- Check file size (< 20MB)
- Verify file type (PNG, JPG, JPEG)
- Check MinIO bucket exists

### Analysis Timeout
- Check GPU availability (if using CUDA)
- Verify model loaded successfully
- Check logs for detailed errors

## Development

### Adding New Models

1. Update `AI_MODEL_NAME` in `.env`
2. Modify `analysis_service.py` if needed
3. Update response schema if output format changes

### Adding New Endpoints

1. Create controller in `controller/`
2. Add endpoint in `main.py`
3. Update models in `models/schemas.py`
4. Add documentation

## Production Deployment

### Docker

```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["python", "main.py"]
```

### Environment

- Set `APP_DEBUG=False`
- Use production MinIO credentials
- Configure proper CORS origins
- Set appropriate TTL values

## License

MIT License
