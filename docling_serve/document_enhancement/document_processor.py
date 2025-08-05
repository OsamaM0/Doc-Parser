import logging
from typing import Dict, List, Optional, Tuple

from PIL import Image

from docling.datamodel.document import ConversionResult

from .bbox_utils import BoundingBoxConverter
from .image_processor import ImageProcessor
from .ocr_enhancer import OCREnhancer
from .text_quality_analyzer import TextQualityAnalyzer

_log = logging.getLogger(__name__)


class DocumentProcessor:
    """Main processor that orchestrates the document enhancement workflow."""

    def __init__(self, enable_formula_enhancement: bool = False, enable_character_encoding_fix: bool = False):
        self.enable_formula_enhancement = enable_formula_enhancement
        self.enable_character_encoding_fix = enable_character_encoding_fix
        self.text_analyzer = TextQualityAnalyzer()
        self.bbox_converter = BoundingBoxConverter()
        self.image_processor = ImageProcessor()
        self.ocr_enhancer = OCREnhancer()

    def process_conversion_result(self, conversion_result: ConversionResult) -> ConversionResult:
        """
        Process and enhance a ConversionResult with OCR improvements.
        
        Args:
            conversion_result: The conversion result from docling
            
        Returns:
            Enhanced conversion result
        """
        if not conversion_result or not conversion_result.document:
            return conversion_result

        # Only process if at least one enhancement is enabled
        if not (self.enable_formula_enhancement or self.enable_character_encoding_fix):
            return conversion_result

        document = conversion_result.document

        # Process each page
        for page_num, page in document.pages.items():
            _log.info(f"Processing page {page_num} for document enhancement...")
            
            # Get page image from Docling
            page_image = self._get_page_image(page)
            if page_image is None:
                _log.warning(f"Could not get image for page {page_num}")
                continue

            page_image = self.image_processor.preprocess_image(page_image)
            
            # Process page elements
            self._process_page_elements(page, page_image, page_num, document)

        return conversion_result

    def _get_page_image(self, page) -> Optional[Image.Image]:
        """Extract page image from Docling's processed data using base64 URI."""
        if hasattr(page, 'image') and page.image and hasattr(page.image, 'uri'):
            return self.image_processor.extract_page_image_from_data_uri(page.image.uri)
        return None

    def _process_page_elements(self, page, page_image: Image.Image, page_num: int, document):
        """Process all elements on a page for OCR enhancement."""
        img_w, img_h = page_image.size
        pdf_w, pdf_h = page.size.width, page.size.height

        # Collect non-text bounding boxes to avoid overlap (including pictures/images)
        non_text_bboxes = self._collect_non_text_bboxes(page_num, pdf_w, pdf_h, img_w, img_h, document)

        # Process tables with enhanced structure recognition
        self._process_tables(page_num, page_image, pdf_w, pdf_h, img_w, img_h, document)

        # Process text elements, excluding those overlapping with images and other non-text elements
        self._process_text_elements(page_num, page_image, pdf_w, pdf_h, img_w, img_h, non_text_bboxes, document)

    def _collect_non_text_bboxes(self, page_num: int, pdf_w: float, pdf_h: float, 
                                 img_w: int, img_h: int, document) -> List[Tuple[int, int, int, int]]:
        """Collect non-text bounding boxes to avoid overlap during text processing."""
        non_text_bboxes = []
        # Include pictures/images, form items, key-value items, and tables
        # This prevents enhancement of text inside images
        non_text_attrs = ["pictures", "form_items", "key_value_items", "tables"]

        for attr in non_text_attrs:
            items = getattr(document, attr, []) or []
            for item in items:
                if hasattr(item, 'prov') and item.prov and item.prov[0].page_no == page_num:
                    bbox = self.bbox_converter.get_pixel_bbox(item, pdf_w, pdf_h, img_w, img_h)
                    non_text_bboxes.append(bbox)

        return non_text_bboxes

    def _process_tables(self, page_num: int, page_image: Image.Image, pdf_w: float, 
                       pdf_h: float, img_w: int, img_h: int, document):
        """Process tables for enhanced structure and text."""
        tables = getattr(document, 'tables', []) or []

        for table in tables:
            if not (hasattr(table, 'prov') and table.prov and table.prov[0].page_no == page_num):
                continue

            # Get table bounding box and crop image
            table_bbox = self.bbox_converter.get_pixel_bbox(table, pdf_w, pdf_h, img_w, img_h)
            table_image = page_image.crop(table_bbox)

            # Enhance table structure
            self.ocr_enhancer.enhance_table_structure(
                table_image, (img_w, img_h), table, table_bbox, pdf_w, pdf_h
            )

            # Process individual cells
            for cell in table.data.table_cells:
                if True in self._should_enhance_text(cell.text).values():
                    need_formula_enhancement = self._should_enhance_text(cell.text).get('formula', False)
                    cell_bbox = self.bbox_converter.get_pixel_bbox(cell, pdf_w, pdf_h, img_w, img_h)
                    enhanced_text = self.ocr_enhancer.extract_text_from_region(page_image, cell_bbox, cell.text, math_mode=need_formula_enhancement)
                    if enhanced_text and enhanced_text != cell.text:
                        _log.info(f"Enhanced cell text: '{cell.text}' -> '{enhanced_text}'")
                        cell.text = enhanced_text

    def _process_text_elements(self, page_num: int, page_image: Image.Image, pdf_w: float,
                              pdf_h: float, img_w: int, img_h: int, 
                              non_text_bboxes: List[Tuple[int, int, int, int]], document):
        """
        Process text elements for OCR enhancement, excluding those overlapping with 
        images and other non-text elements.
        """
        texts = getattr(document, 'texts', []) or []

        for text in texts:
            if not (hasattr(text, 'prov') and text.prov and text.prov[0].page_no == page_num):
                continue

            text_bbox = self.bbox_converter.get_pixel_bbox(text, pdf_w, pdf_h, img_w, img_h)

            # Check for overlap with non-text elements (including images)
            # This prevents applying enhancement to text inside images
            has_overlap = any(self.bbox_converter.calculate_overlap_ratio(text_bbox, other_bbox) > 0.05
                            for other_bbox in non_text_bboxes)

            if has_overlap:
                _log.info(f"Skipping text enhancement due to overlap with non-text element: '{text.text[:50]}...'")
                continue

            # Enhance text if needed
            if True in self._should_enhance_text(text.text).values():
                need_formula_enhancement = self._should_enhance_text(text.text).get('formula', False)
                enhanced_text = self.ocr_enhancer.extract_text_from_region(page_image, text_bbox, text.text, math_mode=need_formula_enhancement)
                if enhanced_text and enhanced_text != text.text:
                    _log.info(f"Enhanced text: '{text.text}' -> '{enhanced_text}'")
                    text.text = enhanced_text

    def _should_enhance_text(self, text: str) -> Dict[str, bool]:
        """Determine if text should be enhanced based on enabled options."""
        return self.text_analyzer.needs_ocr_enhancement(
            text,
            check_formula=self.enable_formula_enhancement,
            check_encoding=self.enable_character_encoding_fix
        )
