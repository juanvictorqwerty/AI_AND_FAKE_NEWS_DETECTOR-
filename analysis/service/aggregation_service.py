from typing import List, Dict, Any, Optional
from loguru import logger
import os

class AggregationService:
    """Service for aggregating multiple frame analysis results using smart voting"""
    
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
        
        This strategy:
        1. Filters out low-confidence frames (below threshold)
        2. Sums confidence scores for each class across valid frames
        3. Selects the class with highest total confidence
        4. Calculates weighted average confidence for the selected class
        
        This is more accurate than simple averaging because it:
        - Reduces impact of ambiguous/noisy frames
        - Weights high-confidence predictions more heavily
        - Filters out irrelevant frames (black, blurred)
        
        Args:
            frame_results: List of individual frame analysis results
            
        Returns:
            Aggregated result with prediction, confidence, and per-frame data
        """
        if not frame_results:
            raise ValueError("No frame results to aggregate")
        
        # Filter out frames with errors
        valid_results = [
            frame for frame in frame_results 
            if frame.get('label') is not None and frame.get('error') is None
        ]
        
        if not valid_results:
            logger.warning("No valid frames to aggregate")
            # Return error result
            return {
                'prediction': None,
                'confidence': 0,
                'frame_count': len(frame_results),
                'valid_frame_count': 0,
                'aggregated_score': 0,
                'frames': self._prepare_frame_results(frame_results),
                'label_distribution': {},
                'error': 'No valid frames to aggregate'
            }
        
        # Filter out low-confidence frames
        high_confidence_frames = [
            frame for frame in valid_results 
            if frame.get('confidence', 0) >= self.confidence_threshold
        ]
        
        # Use high-confidence frames if available, otherwise use all valid frames
        frames_to_aggregate = high_confidence_frames if high_confidence_frames else valid_results
        
        if not high_confidence_frames:
            logger.warning(f"All frames below confidence threshold ({self.confidence_threshold}), using all valid frames")
        
        logger.info(f"Aggregating {len(frames_to_aggregate)} frames out of {len(frame_results)} total")
        
        # Group by label and sum confidence scores
        label_confidence_sums = {}
        label_counts = {}
        
        for frame in frames_to_aggregate:
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
        frames = self._prepare_frame_results(frame_results)
        
        # Prepare label distribution
        label_distribution = {
            label: {
                'count': label_counts[label],
                'total_confidence': label_confidence_sums[label],
                'avg_confidence': label_confidence_sums[label] / label_counts[label]
            }
            for label in label_counts
        }
        
        logger.info(f"Aggregation complete: {best_label} with confidence {aggregated_confidence:.4f}")
        
        return {
            'prediction': best_label,
            'confidence': aggregated_confidence,
            'frame_count': len(frame_results),
            'valid_frame_count': len(valid_results),
            'aggregated_score': aggregated_confidence,
            'frames': frames,
            'label_distribution': label_distribution
        }
    
    def _prepare_frame_results(self, frame_results: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Prepare frame results for output
        
        Args:
            frame_results: Raw frame results
            
        Returns:
            Formatted frame results
        """
        frames = []
        for i, frame in enumerate(frame_results):
            frames.append({
                'filename': frame.get('filename', f'frame_{i}'),
                'prediction': frame.get('label'),
                'confidence': frame.get('confidence')
            })
        return frames
