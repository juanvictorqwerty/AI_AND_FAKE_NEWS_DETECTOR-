import io
import time
import asyncio
from typing import Dict, Any, Optional
from PIL import Image
import torch
from transformers import pipeline
from loguru import logger
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

class AnalysisService:
    """Service for AI image analysis"""
    
    def __init__(self):
        """Initialize AI model"""
        self.model_name = os.getenv('AI_MODEL_NAME', 'Organika/sdxl-detector')
        self.model = None
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        
        # Load model
        self._load_model()
        
        logger.info(f"Analysis service initialized with model: {self.model_name}")
        logger.info(f"Using device: {self.device}")
    
    def _load_model(self):
        """Load the AI model"""
        try:
            logger.info(f"Loading AI model: {self.model_name}")
            
            # Load model using transformers pipeline
            self.model = pipeline(
                "image-classification",
                model=self.model_name,
                device=0 if self.device == "cuda" else -1
            )
            
            logger.info("AI model loaded successfully")
        except Exception as e:
            logger.error(f"Error loading AI model: {e}")
            raise Exception(f"Failed to load AI model: {str(e)}")
    
    async def analyze_image(self, image_data: bytes) -> Dict[str, Any]:
        """
        Analyze image using AI model
        
        Args:
            image_data: Image content as bytes
            
        Returns:
            Dictionary with analysis results
        """
        start_time = time.time()
        
        try:
            # Load image from bytes
            image = Image.open(io.BytesIO(image_data))
            
            # Convert to RGB if necessary
            if image.mode != 'RGB':
                image = image.convert('RGB')
            
            logger.info(f"Analyzing image: {image.size}")
            
            # Run inference
            # Note: pipeline is synchronous, so we run it in a thread pool
            loop = asyncio.get_event_loop()
            results = await loop.run_in_executor(
                None,
                lambda: self.model(image)
            )
            
            # Process results
            if results and len(results) > 0:
                # Get top result
                top_result = results[0]
                label = top_result['label']
                confidence = top_result['score']
                
                # Build probabilities dictionary
                probabilities = {result['label']: result['score'] for result in results}
                
                processing_time = time.time() - start_time
                
                logger.info(f"Analysis completed: {label} ({confidence:.4f}) in {processing_time:.2f}s")
                
                return {
                    'label': label,
                    'confidence': confidence,
                    'probabilities': probabilities,
                    'processing_time': processing_time
                }
            else:
                raise Exception("No results returned from model")
                
        except Exception as e:
            logger.error(f"Error analyzing image: {e}")
            raise Exception(f"Failed to analyze image: {str(e)}")
    
    def is_model_loaded(self) -> bool:
        """Check if model is loaded"""
        return self.model is not None
    
    def get_model_info(self) -> Dict[str, Any]:
        """Get model information"""
        return {
            'model_name': self.model_name,
            'device': self.device,
            'loaded': self.is_model_loaded()
        }
