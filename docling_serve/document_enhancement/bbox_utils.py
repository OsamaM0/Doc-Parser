from enum import Enum
from typing import Tuple

from docling.models.base_model import BoundingBox


class CoordOrigin(Enum):
    """Coordinate system origins for bounding box calculations."""
    TOPLEFT = 'TOPLEFT'
    TOPRIGHT = 'TOPRIGHT'
    BOTTOMLEFT = 'BOTTOMLEFT'
    BOTTOMRIGHT = 'BOTTOMRIGHT'
    CENTER = 'CENTER'


class BoundingBoxConverter:
    """Handles coordinate system conversions for bounding boxes."""

    @staticmethod
    def get_pixel_bbox(item, pdf_w: float, pdf_h: float, img_w: int, img_h: int) -> Tuple[int, int, int, int]:
        """Convert PDF coordinates to pixel coordinates based on coordinate origin."""
        # Extract bbox and origin from item - handle both direct bbox and provenance
        bbox = getattr(item.prov[0], 'bbox', None) if hasattr(item, 'prov') and item.prov else item.bbox
        origin = getattr(item.prov[0], 'coord_origin', CoordOrigin.BOTTOMLEFT) if hasattr(item, 'prov') and item.prov else item.bbox.coord_origin
        origin = origin.value if hasattr(origin, 'value') else origin

        # X coordinate conversion
        if origin in (CoordOrigin.TOPLEFT.value, CoordOrigin.BOTTOMLEFT.value, CoordOrigin.CENTER.value):
            x1 = int((bbox.l / pdf_w) * img_w)
            x2 = int((bbox.r / pdf_w) * img_w)
        else:  # RIGHT origins
            x1 = int(((pdf_w - bbox.r) / pdf_w) * img_w)
            x2 = int(((pdf_w - bbox.l) / pdf_w) * img_w)

        # Y coordinate conversion
        if origin in (CoordOrigin.TOPLEFT.value, CoordOrigin.TOPRIGHT.value):
            y1 = int((bbox.t / pdf_h) * img_h)
            y2 = int((bbox.b / pdf_h) * img_h)
        elif origin in (CoordOrigin.BOTTOMLEFT.value, CoordOrigin.BOTTOMRIGHT.value):
            y1 = int(((pdf_h - bbox.t) / pdf_h) * img_h)
            y2 = int(((pdf_h - bbox.b) / pdf_h) * img_h)
        else:  # CENTER
            cx, cy = pdf_w / 2, pdf_h / 2
            y1 = int(((cy - bbox.t) / pdf_h) * img_h + img_h/2)
            y2 = int(((cy - bbox.b) / pdf_h) * img_h + img_h/2)

        return x1, y1, x2, y2

    @staticmethod
    def calculate_overlap_ratio(boxA: Tuple[int, int, int, int], boxB: Tuple[int, int, int, int]) -> float:
        """Calculate the overlap ratio between two bounding boxes."""
        xA, yA = max(boxA[0], boxB[0]), max(boxA[1], boxB[1])
        xB, yB = min(boxA[2], boxB[2]), min(boxA[3], boxB[3])

        inter_width = max(0, xB - xA)
        inter_height = max(0, yB - yA)
        inter_area = inter_width * inter_height

        area_A = (boxA[2] - boxA[0]) * (boxA[3] - boxA[1])
        return inter_area / area_A if area_A > 0 else 0

    @staticmethod
    def update_cell_bbox(cell, surya_cell, table_bbox, page_dim, pdf_w: float, pdf_h: float):
        """Update cell bbox using corrected coordinate conversion."""
        tx1, ty1, tx2, ty2 = table_bbox
        img_w, img_h = page_dim

        # Get Surya cell bbox in table coordinates
        cx1, cy1, cx2, cy2 = surya_cell.bbox

        # Map to full page pixel coordinates
        full_px1 = tx1 + cx1
        full_py1 = ty1 + cy1
        full_px2 = tx1 + cx2
        full_py2 = ty1 + cy2

        # Convert back to PDF coordinates
        pdf_l = (full_px1 / img_w) * pdf_w
        pdf_t = (full_py1 / img_h) * pdf_h
        pdf_r = (full_px2 / img_w) * pdf_w
        pdf_b = (full_py2 / img_h) * pdf_h

        # Remove cell outlines
        thr = 4
        pdf_l += thr
        pdf_t += thr
        pdf_r -= thr
        pdf_b -= thr

        # Update cell bbox with corrected coordinates
        cell.bbox = BoundingBox(l=pdf_l, t=pdf_t, r=pdf_r, b=pdf_b, coord_origin=CoordOrigin.TOPLEFT)
