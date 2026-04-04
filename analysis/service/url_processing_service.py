"""
URL Processing Service for downloading and validating images from URLs.
"""

import os
import io
import httpx
import asyncio
from typing import Optional, Tuple
from PIL import Image
from loguru import logger
from dotenv import load_dotenv

load_dotenv()


class URLProcessingError(Exception):
    """Base exception for URL processing errors"""
    pass


class ImageDownloadError(URLProcessingError):
    """Raised when image download fails"""
    pass


class InvalidImageError(URLProcessingError):
    """Raised when downloaded content is not a valid image"""
    pass


class ImageSizeError(URLProcessingError):
    """Raised when image exceeds size limits"""
    pass


class URLProcessingService:
    """Service for downloading and validating images from URLs"""

    def __init__(self):
        self.timeout = httpx.Timeout(30.0, read=60.0)  # Longer timeout for downloads
        self.max_redirects = 5
        self.user_agent = "Mozilla/5.0 (compatible; AI Media Analyzer/1.0)"
        self.max_image_size = int(os.getenv('MAX_IMAGE_SIZE_MB', '20')) * 1024 * 1024  # Default 20MB
        self.allowed_mime_types = {'image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/bmp'}

    async def download_image(self, image_url: str) -> Tuple[bytes, str]:
        """
        Download image from URL and return image data and MIME type.

        Args:
            image_url: Direct URL to the image

        Returns:
            Tuple of (image_bytes, mime_type)

        Raises:
            ImageDownloadError: If download fails
            ImageSizeError: If image is too large
            InvalidImageError: If content is not a valid image
        """
        try:
            async with httpx.AsyncClient(timeout=self.timeout, follow_redirects=True, max_redirects=self.max_redirects) as client:
                headers = {
                    'User-Agent': self.user_agent,
                    'Accept': 'image/*,*/*;q=0.8',
                }

                logger.info(f"Downloading image from: {image_url}")

                async with client.stream('GET', image_url, headers=headers) as response:
                    response.raise_for_status()

                    # Check content type
                    content_type = response.headers.get('content-type', '').lower()
                    if not content_type.startswith('image/'):
                        raise InvalidImageError(f"URL does not contain image content: {content_type}")

                    if content_type not in self.allowed_mime_types:
                        raise InvalidImageError(f"Unsupported image type: {content_type}")

                    # Check content length if available
                    content_length = response.headers.get('content-length')
                    if content_length:
                        size = int(content_length)
                        if size > self.max_image_size:
                            raise ImageSizeError(f"Image too large: {size} bytes (max: {self.max_image_size})")

                    # Download image data
                    image_data = b''
                    async for chunk in response.aiter_bytes():
                        image_data += chunk

                        # Check size limit during download
                        if len(image_data) > self.max_image_size:
                            raise ImageSizeError(f"Image too large: exceeds {self.max_image_size} bytes")

                    if not image_data:
                        raise ImageDownloadError("Downloaded empty content")

                    # Validate image by trying to open it
                    try:
                        image = Image.open(io.BytesIO(image_data))
                        image.verify()  # Verify it's a valid image
                        image.close()
                    except Exception as e:
                        raise InvalidImageError(f"Invalid image data: {str(e)}")

                    logger.info(f"Successfully downloaded image: {len(image_data)} bytes, type: {content_type}")

                    return image_data, content_type

        except httpx.HTTPStatusError as e:
            raise ImageDownloadError(f"HTTP error {e.response.status_code}: {e.response.reason_phrase}")
        except httpx.TimeoutException:
            raise ImageDownloadError("Download timeout")
        except httpx.RequestError as e:
            raise ImageDownloadError(f"Network error: {str(e)}")
        except Exception as e:
            logger.error(f"Unexpected error downloading image from {image_url}: {e}")
            raise URLProcessingError(f"Failed to download image: {str(e)}")

    async def validate_and_process_image(self, image_url: str) -> Tuple[bytes, str]:
        """
        Validate URL and download image.

        Args:
            image_url: URL to download image from

        Returns:
            Tuple of (image_bytes, mime_type)
        """
        # Basic URL validation
        if not image_url or not image_url.startswith(('http://', 'https://')):
            raise InvalidImageError("Invalid image URL")

        return await self.download_image(image_url)