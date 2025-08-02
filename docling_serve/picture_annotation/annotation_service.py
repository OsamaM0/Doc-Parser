"""Picture annotation service that supports multiple models."""

import base64
import logging
import os
from io import BytesIO
from typing import Optional

from openai import OpenAI
from PIL import Image as PILImage

from docling_serve.datamodel.convert import (
    OpenAIAnnotationConfig,
    PictureAnnotationModelType,
    PictureAnnotationOptions,
    RunPodAnnotationConfig,
)
from .models import AnnotationResult

_log = logging.getLogger(__name__)


class PictureAnnotationService:
    """Service for annotating pictures using various models."""

    def __init__(self, options: Optional[PictureAnnotationOptions] = None):
        self.options = options or PictureAnnotationOptions()
        self._validate_configuration()

    def _validate_configuration(self):
        """Validate the configuration for the selected model type."""
        if self.options.model_type == PictureAnnotationModelType.RUNPOD:
            if not self.options.runpod_config:
                # Try to get from environment variables
                api_key = os.getenv("RUNPOD_API_KEY")
                worker_id = os.getenv("RUNPOD_WORKER") 
                model = os.getenv("RUNPOD_MODEL", "Qwen/Qwen2.5-VL-3B-Instruct")
                
                if not api_key or not worker_id:
                    raise ValueError(
                        "RunPod configuration missing. Either provide runpod_config "
                        "or set RUNPOD_API_KEY and RUNPOD_WORKER environment variables."
                    )
                
                from docling_serve.datamodel.convert import RunPodAnnotationConfig
                self.options.runpod_config = RunPodAnnotationConfig(
                    api_key=api_key,
                    worker_id=worker_id,
                    model=model
                )

        elif self.options.model_type == PictureAnnotationModelType.OPENAI:
            if not self.options.openai_config:
                # Try to get from environment variables
                api_key = os.getenv("OPENAI_API_KEY")
                
                if not api_key:
                    raise ValueError(
                        "OpenAI configuration missing. Either provide openai_config "
                        "or set OPENAI_API_KEY environment variable."
                    )
                
                from docling_serve.datamodel.convert import OpenAIAnnotationConfig
                self.options.openai_config = OpenAIAnnotationConfig(api_key=api_key)

    def annotate_image(self, image: PILImage.Image) -> AnnotationResult:
        """Annotate an image using the configured model."""
        try:
            if self.options.model_type == PictureAnnotationModelType.LOCAL:
                return self._annotate_with_local_model(image)
            elif self.options.model_type == PictureAnnotationModelType.RUNPOD:
                return self._annotate_with_runpod(image)
            elif self.options.model_type == PictureAnnotationModelType.OPENAI:
                return self._annotate_with_openai(image)
            else:
                raise ValueError(f"Unsupported model type: {self.options.model_type}")

        except Exception as e:
            _log.error(f"Error during image annotation: {e}")
            return AnnotationResult(
                text="",
                provenance=self.options.model_type.value,
                error=str(e)
            )

    def _annotate_with_local_model(self, image: PILImage.Image) -> AnnotationResult:
        """Annotate using the default local model."""
        # This would integrate with the existing local model logic
        # For now, return a placeholder
        return AnnotationResult(
            text="Local model annotation placeholder",
            provenance="local_model"
        )

    def _annotate_with_runpod(self, image: PILImage.Image) -> AnnotationResult:
        """Annotate using RunPod model."""
        config = self.options.runpod_config
        if not config:
            raise ValueError("RunPod configuration not available")

        # Convert image to base64
        buffered = BytesIO()
        image.save(buffered, format="PNG")
        img_str = base64.b64encode(buffered.getvalue()).decode("utf-8")

        # Create OpenAI client for RunPod
        base_url = f"https://api.runpod.ai/v2/{config.worker_id}/openai/v1"
        client = OpenAI(base_url=base_url, api_key=config.api_key)

        response = client.chat.completions.create(
            model=config.model,
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:image/png;base64,{img_str}",
                                "detail": "low",
                            },
                        },
                        {
                            "type": "text",
                            "text": config.prompt,
                        },
                    ],
                }
            ],
            temperature=config.temperature,
        )

        return AnnotationResult(
            text=response.choices[0].message.content or "",
            provenance=f"runpod:{config.model}"
        )

    def _annotate_with_openai(self, image: PILImage.Image) -> AnnotationResult:
        """Annotate using OpenAI model."""
        config = self.options.openai_config
        if not config:
            raise ValueError("OpenAI configuration not available")

        # Convert image to base64
        buffered = BytesIO()
        image.save(buffered, format="PNG")
        img_str = base64.b64encode(buffered.getvalue()).decode("utf-8")

        # Create OpenAI client
        client = OpenAI(api_key=config.api_key)

        response = client.chat.completions.create(
            model=config.model,
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:image/png;base64,{img_str}",
                                "detail": "high",
                            },
                        },
                        {
                            "type": "text",
                            "text": config.prompt,
                        },
                    ],
                }
            ],
            temperature=config.temperature,
        )

        return AnnotationResult(
            text=response.choices[0].message.content or "",
            provenance=f"openai:{config.model}"
        )
