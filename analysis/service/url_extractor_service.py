"""
URL Extractor Service for extracting media URLs from various platforms.

Supports Instagram, Facebook, Google Share, and generic image URLs.
"""

import os
import re
import httpx
import asyncio
from typing import Optional, Dict, Any, Tuple
from urllib.parse import urlparse, urljoin, parse_qs
from loguru import logger
from dotenv import load_dotenv

load_dotenv()


class URLExtractorError(Exception):
    """Base exception for URL extraction errors"""
    pass


class ContentNotAccessibleError(URLExtractorError):
    """Raised when content is private or not accessible"""
    pass


class InvalidURLError(URLExtractorError):
    """Raised for invalid or unsupported URLs"""
    pass


class VideoContentError(URLExtractorError):
    """Raised when URL contains video content"""
    pass


class BaseURLExtractor:
    """Base class for URL extractors"""

    def __init__(self):
        self.timeout = httpx.Timeout(10.0, read=30.0)
        self.max_redirects = 5
        self.user_agent = "Mozilla/5.0 (compatible; AI Media Analyzer/1.0)"

    async def extract_image_url(self, url: str) -> Optional[str]:
        """
        Extract image URL from the given URL.
        Returns the direct image URL or None if not found.
        """
        raise NotImplementedError

    def is_video_url(self, url: str) -> bool:
        """Check if URL likely contains video content"""
        video_extensions = ['.mp4', '.mov', '.avi', '.mkv', '.webm', '.m3u8', '.ts']
        url_lower = url.lower()
        return any(url_lower.endswith(ext) for ext in video_extensions)

    async def download_image(self, image_url: str) -> Tuple[bytes, str]:
        """
        Download image from URL and return (content_bytes, content_type).
        Raises URLExtractorError on failure.
        """
        try:
            async with httpx.AsyncClient(timeout=self.timeout, follow_redirects=True, max_redirects=self.max_redirects) as client:
                headers = {
                    'User-Agent': self.user_agent,
                    'Accept': 'image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
                }

                response = await client.get(image_url, headers=headers)
                response.raise_for_status()

                content_type = response.headers.get('content-type', 'application/octet-stream')
                
                # Verify it's actually an image
                if not content_type.startswith('image/'):
                    # Some servers return wrong content-type, check magic bytes
                    content = response.content
                    if not self._is_image_content(content):
                        raise URLExtractorError(f"URL does not point to an image. Content-Type: {content_type}")
                    return content, 'image/jpeg'  # Default assumption
                
                return response.content, content_type

        except httpx.HTTPStatusError as e:
            raise ContentNotAccessibleError(f"Failed to download image: HTTP {e.response.status_code}")
        except httpx.RequestError as e:
            raise URLExtractorError(f"Network error downloading image: {str(e)}")
        except Exception as e:
            logger.error(f"Error downloading image from {image_url}: {e}")
            raise URLExtractorError(f"Failed to download image: {str(e)}")

    def _is_image_content(self, content: bytes) -> bool:
        """Check if content bytes represent an image using magic numbers"""
        # JPEG
        if content.startswith(b'\xff\xd8\xff'):
            return True
        # PNG
        if content.startswith(b'\x89PNG\r\n\x1a\n'):
            return True
        # GIF
        if content.startswith(b'GIF87a') or content.startswith(b'GIF89a'):
            return True
        # WebP
        if content.startswith(b'RIFF') and content[8:12] == b'WEBP':
            return True
        # BMP
        if content.startswith(b'BM'):
            return True
        return False


class InstagramExtractor(BaseURLExtractor):
    """Extractor for Instagram URLs"""

    async def extract_image_url(self, url: str) -> Optional[str]:
        try:
            async with httpx.AsyncClient(timeout=self.timeout, follow_redirects=True, max_redirects=self.max_redirects) as client:
                headers = {
                    'User-Agent': self.user_agent,
                    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                    'Accept-Language': 'en-US,en;q=0.5',
                }

                response = await client.get(url, headers=headers)
                response.raise_for_status()

                html_content = response.text

                # Check for og:video first - if present, it's a video
                video_match = re.search(r'<meta\s+property=["\']og:video["\']\s+content=["\']([^"\']+)["\']', html_content, re.IGNORECASE)
                if video_match:
                    raise VideoContentError("Instagram URL contains video content")

                # Look for og:image
                image_match = re.search(r'<meta\s+property=["\']og:image["\']\s+content=["\']([^"\']+)["\']', html_content, re.IGNORECASE)
                if image_match:
                    image_url = image_match.group(1)
                    # Ensure it's a full URL
                    if image_url.startswith('//'):
                        image_url = 'https:' + image_url
                    elif not image_url.startswith('http'):
                        image_url = urljoin(url, image_url)
                    return image_url

                return None

        except httpx.HTTPStatusError as e:
            if e.response.status_code == 404:
                raise ContentNotAccessibleError("Instagram post not found or is private")
            raise ContentNotAccessibleError(f"Instagram content not accessible: {e.response.status_code}")
        except Exception as e:
            logger.error(f"Error extracting from Instagram URL {url}: {e}")
            raise URLExtractorError(f"Failed to extract from Instagram: {str(e)}")


class FacebookExtractor(BaseURLExtractor):
    """Extractor for Facebook URLs"""

    async def extract_image_url(self, url: str) -> Optional[str]:
        try:
            async with httpx.AsyncClient(timeout=self.timeout, follow_redirects=True, max_redirects=self.max_redirects) as client:
                headers = {
                    'User-Agent': self.user_agent,
                    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                    'Accept-Language': 'en-US,en;q=0.5',
                }

                response = await client.get(url, headers=headers)
                response.raise_for_status()

                html_content = response.text

                # Check for og:video first - if present, it's a video
                video_match = re.search(r'<meta\s+property=["\']og:video["\']\s+content=["\']([^"\']+)["\']', html_content, re.IGNORECASE)
                if video_match:
                    raise VideoContentError("Facebook URL contains video content")

                # Look for og:image
                image_match = re.search(r'<meta\s+property=["\']og:image["\']\s+content=["\']([^"\']+)["\']', html_content, re.IGNORECASE)
                if image_match:
                    image_url = image_match.group(1)
                    # Ensure it's a full URL
                    if image_url.startswith('//'):
                        image_url = 'https:' + image_url
                    elif not image_url.startswith('http'):
                        image_url = urljoin(url, image_url)
                    return image_url

                return None

        except httpx.HTTPStatusError as e:
            if e.response.status_code in [403, 404]:
                raise ContentNotAccessibleError("Facebook post not found or is private")
            raise ContentNotAccessibleError(f"Facebook content not accessible: {e.response.status_code}")
        except Exception as e:
            logger.error(f"Error extracting from Facebook URL {url}: {e}")
            raise URLExtractorError(f"Failed to extract from Facebook: {str(e)}")


class GoogleShareExtractor(BaseURLExtractor):
    """Extractor for Google Share URLs (share.google/...)"""

    async def extract_image_url(self, url: str) -> Optional[str]:
        try:
            async with httpx.AsyncClient(timeout=self.timeout, follow_redirects=True, max_redirects=self.max_redirects) as client:
                headers = {
                    'User-Agent': self.user_agent,
                    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                }

                logger.debug(f"Fetching Google Share URL: {url}")
                response = await client.get(url, headers=headers)
                response.raise_for_status()

                final_url = str(response.url)
                logger.debug(f"Google Share redirected to: {final_url}")

                # Handle Google Images search results redirect
                if 'google.com/imgres' in final_url or 'google.com/search' in final_url:
                    parsed = urlparse(final_url)
                    params = parse_qs(parsed.query)
                    if 'imgurl' in params:
                        return params['imgurl'][0]
                    # Try tbs parameter for encrypted image URLs
                    if 'tbs' in params:
                        # This is a Google Images result without direct URL
                        raise URLExtractorError("Cannot extract direct image URL from Google Images search result")

                html_content = response.text

                # Check for video content
                video_match = re.search(r'<meta\s+property=["\']og:video["\']\s+content=["\']([^"\']+)["\']', html_content, re.IGNORECASE)
                if video_match:
                    raise VideoContentError("URL contains video content")

                # Look for og:image
                image_match = re.search(r'<meta\s+property=["\']og:image["\']\s+content=["\']([^"\']+)["\']', html_content, re.IGNORECASE)
                if image_match:
                    image_url = image_match.group(1)
                    if image_url.startswith('//'):
                        image_url = 'https:' + image_url
                    elif not image_url.startswith('http'):
                        image_url = urljoin(url, image_url)
                    return image_url

                # Try other common meta tags
                image_match = re.search(r'<meta\s+name=["\']twitter:image["\']\s+content=["\']([^"\']+)["\']', html_content, re.IGNORECASE)
                if image_match:
                    image_url = image_match.group(1)
                    if image_url.startswith('//'):
                        image_url = 'https:' + image_url
                    return image_url

                # Try to find any image URL in the page as fallback
                img_matches = re.findall(r'https?://[^\s"\']+\.(?:jpg|jpeg|png|gif|webp)', html_content, re.IGNORECASE)
                if img_matches:
                    return img_matches[0]

                logger.warning(f"No image found in Google Share page. Final URL: {final_url}")
                return None

        except httpx.HTTPStatusError as e:
            logger.error(f"HTTP error accessing Google Share URL: {e.response.status_code}")
            raise ContentNotAccessibleError(f"Content not accessible: {e.response.status_code}")
        except Exception as e:
            logger.error(f"Error extracting from Google Share URL {url}: {type(e).__name__}: {e}")
            raise URLExtractorError(f"Failed to extract from Google Share URL: {type(e).__name__}: {str(e)}")


class GenericExtractor(BaseURLExtractor):
    """Generic extractor for direct image URLs and web pages"""

    async def extract_image_url(self, url: str) -> Optional[str]:
        parsed = urlparse(url)
        path_lower = parsed.path.lower()

        if self.is_video_url(url):
            raise VideoContentError("URL contains video content")

        # Check if it's already a direct image URL
        image_extensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp']
        if any(path_lower.endswith(ext) for ext in image_extensions):
            return url

        try:
            async with httpx.AsyncClient(timeout=self.timeout, follow_redirects=True, max_redirects=self.max_redirects) as client:
                headers = {
                    'User-Agent': self.user_agent,
                    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                }

                response = await client.get(url, headers=headers)
                response.raise_for_status()

                final_url = str(response.url)

                # Check if redirected to Google Images search results
                if 'google.com/imgres' in final_url or 'google.com/search' in final_url:
                    parsed_redirect = urlparse(final_url)
                    params = parse_qs(parsed_redirect.query)
                    if 'imgurl' in params:
                        return params['imgurl'][0]

                html_content = response.text

                video_match = re.search(r'<meta\s+property=["\']og:video["\']\s+content=["\']([^"\']+)["\']', html_content, re.IGNORECASE)
                if video_match:
                    raise VideoContentError("URL contains video content")

                image_match = re.search(r'<meta\s+property=["\']og:image["\']\s+content=["\']([^"\']+)["\']', html_content, re.IGNORECASE)
                if image_match:
                    image_url = image_match.group(1)
                    if image_url.startswith('//'):
                        image_url = 'https:' + image_url
                    elif not image_url.startswith('http'):
                        image_url = urljoin(url, image_url)
                    return image_url

                # Try Twitter card image
                image_match = re.search(r'<meta\s+name=["\']twitter:image["\']\s+content=["\']([^"\']+)["\']', html_content, re.IGNORECASE)
                if image_match:
                    image_url = image_match.group(1)
                    if image_url.startswith('//'):
                        image_url = 'https:' + image_url
                    return image_url

                return None

        except httpx.HTTPStatusError as e:
            raise ContentNotAccessibleError(f"Content not accessible: {e.response.status_code}")
        except Exception as e:
            logger.error(f"Error extracting from generic URL {url}: {e}")
            raise URLExtractorError(f"Failed to extract from URL: {str(e)}")


class URLExtractorService:
    """Main service for extracting media URLs from various platforms"""

    def __init__(self):
        self.extractors = {
            'instagram.com': InstagramExtractor(),
            'facebook.com': FacebookExtractor(),
            'share.google': GoogleShareExtractor(),
            'generic': GenericExtractor()
        }

    def _get_extractor(self, url: str) -> BaseURLExtractor:
        """Get the appropriate extractor for the URL"""
        domain = urlparse(url).netloc.lower()
        if 'instagram.com' in domain:
            return self.extractors['instagram.com']
        elif 'facebook.com' in domain:
            return self.extractors['facebook.com']
        elif 'share.google' in domain or domain == 'share.google':
            return self.extractors['share.google']
        else:
            return self.extractors['generic']

    def validate_url(self, url: str) -> bool:
        """Validate that the URL is properly formatted and safe"""
        try:
            parsed = urlparse(url)
            # Must have scheme and netloc
            if not parsed.scheme or not parsed.netloc:
                return False

            # Must be http or https
            if parsed.scheme not in ['http', 'https']:
                return False

            # Block localhost and private IPs for SSRF protection
            hostname = parsed.hostname
            if hostname in ['localhost', '127.0.0.1', '0.0.0.0', '::1']:
                return False

            # Block private IP ranges
            if hostname:
                import ipaddress
                try:
                    ip = ipaddress.ip_address(hostname)
                    if ip.is_private or ip.is_loopback or ip.is_link_local:
                        return False
                except ValueError:
                    pass  # Not an IP address, continue

            return True

        except Exception:
            return False

    async def extract_image_url(self, url: str) -> str:
        """
        Extract the direct image URL from the given URL.
        Raises appropriate exceptions for errors.
        """
        if not self.validate_url(url):
            raise InvalidURLError("Invalid or unsafe URL")

        # Check for video extensions early
        extractor = self._get_extractor(url)
        if extractor.is_video_url(url):
            raise VideoContentError("Video URLs are not supported")

        image_url = await extractor.extract_image_url(url)
        if not image_url:
            raise URLExtractorError("No image found in the provided URL")

        return image_url

    async def extract_and_download(self, url: str) -> Tuple[str, bytes, str]:
        """
        Extract image URL from web link and download the image.
        
        Returns:
            Tuple of (image_url, image_bytes, content_type)
        
        Raises:
            InvalidURLError: If URL is invalid
            ContentNotAccessibleError: If content is private/inaccessible  
            VideoContentError: If URL contains video
            URLExtractorError: For other extraction failures
        """
        # Step 1: Extract the direct image URL from the web link
        image_url = await self.extract_image_url(url)
        logger.info(f"Extracted image URL: {image_url}")
        
        # Step 2: Download the actual image
        extractor = self._get_extractor(url)
        image_bytes, content_type = await extractor.download_image(image_url)
        logger.info(f"Downloaded image: {len(image_bytes)} bytes, type: {content_type}")
        
        return image_url, image_bytes, content_type