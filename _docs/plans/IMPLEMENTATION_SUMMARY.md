# Authenticated Media Upload Service - Implementation Summary

## Overview

This document summarizes the implementation of the authenticated media upload service that sends image and video files to a FastAPI backend using JWT authentication tokens stored locally.

## Implementation Status

### ✅ Completed Components

#### 1. Flutter Service Layer

**File**: [`ai_fake_news_detector/lib/models/media_upload_result.dart`](ai_fake_news_detector/lib/models/media_upload_result.dart)

- Created `MediaUploadResult` model class
- Fields: success, prediction, confidence, mediaType, analysisId, errorMessage, statusCode
- Factory constructors for JSON parsing, error cases, and success cases
- Helper methods: isFake, isReal, hasError, isAuthError, isNetworkError, confidencePercentage

**File**: [`ai_fake_news_detector/lib/services/authenticated_media_upload_service.dart`](ai_fake_news_detector/lib/services/authenticated_media_upload_service.dart)

- Created `AuthenticatedMediaUploadService` class extending GetxService
- Token retrieval from AuthController
- Multipart/form-data request construction with Authorization header
- Upload progress tracking
- Error handling for 401, network errors, timeouts
- Retry mechanism with exponential backoff (max 3 attempts)

#### 2. Kotlin Service Layer (Background Compatible)

**File**: [`ai_fake_news_detector/android/app/src/main/kotlin/com/example/ai_fake_news_detector/MediaUploadService.kt`](ai_fake_news_detector/android/app/src/main/kotlin/com/example/ai_fake_news_detector/MediaUploadService.kt)

- Added `getAuthToken()` method to retrieve JWT from ConfigManager
- Added `uploadMediaWithAuth()` method for authenticated uploads
- Authorization header: `Bearer <token>`
- Endpoint: `POST /analyze/media`
- Retry mechanism with exponential backoff
- Error handling for authentication failures

#### 3. FastAPI Backend

**File**: [`analysis/middleware/auth_middleware.py`](analysis/middleware/auth_middleware.py)

- JWT validation middleware
- Token signature verification
- Token expiration checking
- User payload extraction (user_id, email)
- HTTPBearer security scheme

**File**: [`analysis/models/database.py`](analysis/models/database.py)

- `IndexTable` model: id, user_id, media_type, created_at
- `MediaAnalysisTable` model: id, index_id, prediction, confidence, file_path, analysis_details, created_at
- Relationships and indexes for efficient queries

**File**: [`analysis/service/database_service.py`](analysis/service/database_service.py)

- Async database operations with SQLAlchemy
- `store_analysis_result()`: Transaction-based storage in both tables
- `get_analysis_result()`: Retrieve by analysis_id
- `get_user_analyses()`: Retrieve all analyses for a user
- `delete_analysis()`: Delete analysis (with ownership check)

**File**: [`analysis/controller/authenticated_upload_controller.py`](analysis/controller/authenticated_upload_controller.py)

- `POST /analyze/media`: Authenticated media upload endpoint
  - JWT validation via dependency injection
  - File validation (type, size)
  - AI analysis processing
  - Database storage
  - JSON response with prediction, confidence, media_type, analysis_id
- `GET /results/{analysis_id}`: Get analysis results by ID
- `GET /history`: Get analysis history for current user
- `DELETE /results/{analysis_id}`: Delete analysis by ID

**File**: [`analysis/main.py`](analysis/main.py)

- Added authenticated router import
- Included authenticated router in app
- Database initialization on startup
- Database connection cleanup on shutdown

## API Endpoints

### Authenticated Endpoints

#### POST /analyze/media
Upload media file with JWT authentication

**Request**:
- Headers: `Authorization: Bearer <token>`
- Body: multipart/form-data
  - `file`: Media file (image or video)
  - `type`: "image" or "video"

**Response**:
```json
{
  "status": "success",
  "data": {
    "prediction": "fake",
    "confidence": 0.92,
    "media_type": "image",
    "analysis_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

**Error Responses**:
- 401: Invalid or expired token
- 400: Invalid file type or size
- 500: Processing error

#### GET /results/{analysis_id}
Get analysis results by ID

**Request**:
- Headers: `Authorization: Bearer <token>`
- Path: `analysis_id` (UUID)

**Response**:
```json
{
  "status": "success",
  "data": {
    "analysis_id": "550e8400-e29b-41d4-a716-446655440000",
    "user_id": "123e4567-e89b-12d3-a456-426614174000",
    "media_type": "image",
    "prediction": "fake",
    "confidence": 0.92,
    "file_path": null,
    "analysis_details": {
      "probabilities": {"fake": 0.92, "real": 0.08},
      "processing_time": 1.23,
      "filename": "image.jpg",
      "file_size": 1024000
    },
    "created_at": "2026-03-29T12:00:00"
  }
}
```

#### GET /history
Get analysis history for current user

**Request**:
- Headers: `Authorization: Bearer <token>`
- Query: `limit` (default: 50), `offset` (default: 0)

**Response**:
```json
{
  "status": "success",
  "data": {
    "analyses": [...],
    "count": 10,
    "limit": 50,
    "offset": 0
  }
}
```

#### DELETE /results/{analysis_id}
Delete analysis by ID

**Request**:
- Headers: `Authorization: Bearer <token>`
- Path: `analysis_id` (UUID)

**Response**:
```json
{
  "status": "success",
  "message": "Analysis deleted: 550e8400-e29b-41d4-a716-446655440000"
}
```

## Database Schema

### index_table
```sql
CREATE TABLE index_table (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  media_type VARCHAR(50) NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_index_table_user_id ON index_table(user_id);
CREATE INDEX idx_index_table_created_at ON index_table(created_at);
```

### media_analysis_table
```sql
CREATE TABLE media_analysis_table (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  index_id UUID NOT NULL REFERENCES index_table(id) ON DELETE CASCADE,
  prediction VARCHAR(50) NOT NULL,
  confidence FLOAT NOT NULL,
  file_path VARCHAR(500),
  analysis_details JSONB,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_media_analysis_table_index_id ON media_analysis_table(index_id);
CREATE INDEX idx_media_analysis_table_created_at ON media_analysis_table(created_at);
```

## Authentication Flow

1. **Flutter App**: User logs in → JWT token stored in SharedPreferences
2. **Kotlin Service**: Retrieves token from ConfigManager (reads from SharedPreferences)
3. **Kotlin Service**: Sends multipart request with `Authorization: Bearer <token>` header
4. **FastAPI Backend**: JWT middleware validates token signature and expiration
5. **FastAPI Backend**: Extracts user_id from token payload
6. **FastAPI Backend**: Processes media using AI analysis
7. **FastAPI Backend**: Stores results in database (index_table + media_analysis_table)
8. **FastAPI Backend**: Returns JSON response with prediction, confidence, analysis_id
9. **Kotlin Service**: Parses response and returns to Flutter
10. **Flutter App**: Displays result to user

## Error Handling

### Authentication Errors (401)
- Invalid token signature
- Expired token
- Missing token
- **Action**: Redirect to login screen

### Validation Errors (400)
- Invalid file type
- File too large (>20MB)
- Missing required fields
- **Action**: Show user-friendly error message

### Network Errors
- Connection timeout
- Server unavailable
- DNS resolution failure
- **Action**: Show retry button with exponential backoff

### Processing Errors (500)
- AI model error
- Database error
- File processing error
- **Action**: Show error message with retry option

## Security Considerations

1. **Token Storage**: Uses SharedPreferences (same as Flutter's AuthController)
2. **Token Validation**: Verifies signature and expiration on backend
3. **File Validation**: Checks file type and size before processing
4. **Database Security**: Uses parameterized queries to prevent SQL injection
5. **CORS Configuration**: Allows only trusted origins
6. **Request Logging**: Logs all requests for debugging and security auditing

## Performance Optimizations

1. **Upload Progress**: Tracks and displays upload progress for large files
2. **Timeout Handling**: Configurable timeouts for large file uploads
3. **Retry Logic**: Exponential backoff for transient failures
4. **Database Indexing**: Indexes on user_id and created_at for fast queries
5. **Connection Pooling**: Uses connection pooling for database connections
6. **Async Processing**: Uses async/await for non-blocking operations

## Next Steps

### Pending Tasks

1. **Update MediaPickerPage**: Integrate new authenticated upload service
2. **Create Upload Progress Widget**: Display upload progress indicator
3. **Create Error Display Widget**: Show error messages with retry option
4. **Integration Testing**: Test end-to-end flow

### Future Enhancements

1. **Video Support**: Add video frame extraction and analysis
2. **Batch Upload**: Support multiple file uploads
3. **Offline Support**: Queue uploads when offline
4. **Analytics**: Track upload success rates and performance metrics
5. **Rate Limiting**: Implement rate limiting to prevent abuse

## Conclusion

The authenticated media upload service has been successfully implemented with:

- ✅ JWT token authentication
- ✅ Multipart/form-data file uploads
- ✅ Database storage with transaction support
- ✅ Error handling and retry logic
- ✅ Upload progress tracking
- ✅ Security best practices

The service is ready for integration with the Flutter app and can be extended to support video analysis and additional features.
