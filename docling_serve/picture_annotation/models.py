"""Data models for picture annotation."""

from typing import Optional
from pydantic import BaseModel


class AnnotationResult(BaseModel):
    """Result from picture annotation."""
    text: str
    provenance: str
    confidence: Optional[float] = None
    error: Optional[str] = None
