import os
import io
import uuid
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from minio import Minio
from minio.error import S3Error
from loguru import logger
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

class MinIOService:
    """Service for handling MinIO operations"""
    
    def __init__(self):
        """Initialize MinIO client with environment configuration"""
        self.endpoint = os.getenv('MINIO_ENDPOINT', 'localhost:9000')
        self.access_key = os.getenv('MINIO_ACCESS_KEY', 'minioadmin')
        self.secret_key = os.getenv('MINIO_SECRET_KEY', 'minioadmin')
        self.secure = os.getenv('MINIO_SECURE', 'False').lower() == 'true'
        self.bucket_name = os.getenv('MINIO_BUCKET_NAME', 'ai-analysis')
        
        # Initialize MinIO client
        self.client = Minio(
            self.endpoint,
            access_key=self.access_key,
            secret_key=self.secret_key,
            secure=self.secure
        )
        
        # Ensure bucket exists
        self._ensure_bucket_exists()
        
        logger.info(f"MinIO service initialized with endpoint: {self.endpoint}")
    
    def _ensure_bucket_exists(self):
        """Create bucket if it doesn't exist"""
        try:
            if not self.client.bucket_exists(self.bucket_name):
                self.client.make_bucket(self.bucket_name)
                logger.info(f"Created bucket: {self.bucket_name}")
            else:
                logger.info(f"Bucket already exists: {self.bucket_name}")
        except S3Error as e:
            logger.error(f"Error creating bucket: {e}")
            raise
    
    def upload_file(self, file_data: bytes, file_extension: str) -> Dict[str, Any]:
        """
        Upload file to MinIO
        
        Args:
            file_data: File content as bytes
            file_extension: File extension (e.g., '.jpg', '.png')
            
        Returns:
            Dictionary with file_id and object_name
        """
        try:
            # Generate unique file ID
            file_id = str(uuid.uuid4())
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            object_name = f"uploads/{timestamp}_{file_id}{file_extension}"
            
            # Upload file
            self.client.put_object(
                self.bucket_name,
                object_name,
                io.BytesIO(file_data),
                length=len(file_data),
                content_type=f"image/{file_extension.lstrip('.')}"
            )
            
            logger.info(f"File uploaded successfully: {object_name}")
            
            return {
                'file_id': file_id,
                'object_name': object_name,
                'file_size': len(file_data)
            }
        except S3Error as e:
            logger.error(f"Error uploading file to MinIO: {e}")
            raise Exception(f"Failed to upload file: {str(e)}")
    
    def download_file(self, object_name: str) -> bytes:
        """
        Download file from MinIO
        
        Args:
            object_name: Name of the object in MinIO
            
        Returns:
            File content as bytes
        """
        try:
            response = self.client.get_object(self.bucket_name, object_name)
            file_data = response.read()
            response.close()
            response.release_conn()
            
            logger.info(f"File downloaded successfully: {object_name}")
            return file_data
        except S3Error as e:
            logger.error(f"Error downloading file from MinIO: {e}")
            raise Exception(f"Failed to download file: {str(e)}")
    
    def delete_file(self, object_name: str) -> bool:
        """
        Delete file from MinIO
        
        Args:
            object_name: Name of the object in MinIO
            
        Returns:
            True if deletion was successful
        """
        try:
            self.client.remove_object(self.bucket_name, object_name)
            logger.info(f"File deleted successfully: {object_name}")
            return True
        except S3Error as e:
            logger.error(f"Error deleting file from MinIO: {e}")
            return False
    
    def file_exists(self, object_name: str) -> bool:
        """
        Check if file exists in MinIO
        
        Args:
            object_name: Name of the object in MinIO
            
        Returns:
            True if file exists
        """
        try:
            self.client.stat_object(self.bucket_name, object_name)
            return True
        except S3Error:
            return False
    
    def get_file_url(self, object_name: str, expires: int = 3600) -> str:
        """
        Get presigned URL for file access
        
        Args:
            object_name: Name of the object in MinIO
            expires: URL expiration time in seconds
            
        Returns:
            Presigned URL
        """
        try:
            url = self.client.presigned_get_object(
                self.bucket_name,
                object_name,
                expires=timedelta(seconds=expires)
            )
            return url
        except S3Error as e:
            logger.error(f"Error generating presigned URL: {e}")
            raise Exception(f"Failed to generate URL: {str(e)}")
    
    def cleanup_expired_files(self, ttl_seconds: int = 3600):
        """
        Clean up expired files from MinIO
        
        Args:
            ttl_seconds: Time-to-live in seconds
        """
        try:
            cutoff_time = datetime.now() - timedelta(seconds=ttl_seconds)
            
            # List all objects in uploads folder
            objects = self.client.list_objects(self.bucket_name, prefix="uploads/")
            
            deleted_count = 0
            for obj in objects:
                if obj.last_modified < cutoff_time:
                    self.client.remove_object(self.bucket_name, obj.object_name)
                    deleted_count += 1
                    logger.info(f"Deleted expired file: {obj.object_name}")
            
            logger.info(f"Cleanup completed: {deleted_count} files deleted")
        except S3Error as e:
            logger.error(f"Error during cleanup: {e}")
    
    def check_connection(self) -> bool:
        """
        Check if MinIO connection is working
        
        Returns:
            True if connection is successful
        """
        try:
            self.client.bucket_exists(self.bucket_name)
            return True
        except Exception as e:
            logger.error(f"MinIO connection check failed: {e}")
            return False
