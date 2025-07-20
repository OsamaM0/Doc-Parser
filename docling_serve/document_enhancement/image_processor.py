import base64
import logging
from io import BytesIO
from typing import Optional

import cv2
import numpy as np
from PIL import Image

_log = logging.getLogger(__name__)


class ImageProcessor:
    """Handles image processing operations for document enhancement."""

    @staticmethod
    def preprocess_image(image: Image.Image, enhance_for_arabic: bool = True) -> Image.Image:
        """
        Preprocess image for better OCR results, especially for Arabic text.

        Args:
            image: Input PIL Image
            enhance_for_arabic: Whether to apply Arabic-specific enhancements

        Returns:
            Preprocessed PIL Image
        """
        try:
            # Convert to numpy array for OpenCV processing
            img_array = np.array(image)
            if img_array is None or img_array.size == 0:
                return image

            # Convert to grayscale if needed
            if len(img_array.shape) == 3:
                gray = cv2.cvtColor(img_array, cv2.COLOR_RGB2GRAY)
            else:
                gray = img_array

            processed_image = Image.fromarray(gray)
            return processed_image

        except Exception as e:
            _log.warning(f"Error preprocessing image: {e}")
            return image

    @staticmethod
    def extract_page_image_from_data_uri(data_uri: str) -> Optional[Image.Image]:
        """Extract page image from Docling's processed data using base64 URI."""
        if not str(data_uri).startswith('data:'):
            _log.warning(f"Page image URI is not a data URL: {data_uri}")
            return None

        try:
            # Split the header and base64 data
            header, base64_data = str(data_uri).split(",", 1)

            # Decode the base64 image data
            image_bytes = base64.b64decode(base64_data)

            # Create PIL Image from bytes
            image = Image.open(BytesIO(image_bytes))
            return image

        except Exception as e:
            _log.error(f"Error decoding page image: {e}")
            return None
