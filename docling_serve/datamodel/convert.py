# Define the input options for the API
from enum import Enum
from typing import Annotated, Any, Optional

from pydantic import AnyUrl, BaseModel, Field, model_validator
from typing_extensions import Self

from docling.datamodel.base_models import InputFormat, OutputFormat
from docling.datamodel.pipeline_options import (
    EasyOcrOptions,
    PdfBackend,
    PictureDescriptionBaseOptions,
    ProcessingPipeline,
    TableFormerMode,
    TableStructureOptions,
)
from docling.datamodel.settings import (
    DEFAULT_PAGE_RANGE,
    PageRange,
)
from docling.models.factories import get_ocr_factory
from docling_core.types.doc import ImageRefMode
from docling_jobkit.datamodel.convert import ConvertDocumentsOptions as BaseConvertDocumentsOptions

from docling_serve.settings import docling_serve_settings

ocr_factory = get_ocr_factory(
    allow_external_plugins=docling_serve_settings.allow_external_plugins
)
ocr_engines_enum = ocr_factory.get_enum()


# Custom classes for picture description and annotation (your enhancements)
class PictureDescriptionLocal(BaseModel):
    repo_id: Annotated[
        str,
        Field(
            description="Repository id from the Hugging Face Hub.",
            examples=[
                "HuggingFaceTB/SmolVLM-256M-Instruct",
                "ibm-granite/granite-vision-3.2-2b",
            ],
        ),
    ]
    prompt: Annotated[
        str,
        Field(
            description="Prompt used when calling the vision-language model.",
            examples=[
                "Describe this image in a few sentences.",
                "This is a figure from a document. Provide a detailed description of it.",
            ],
        ),
    ] = "Describe this image in a few sentences."
    generation_config: Annotated[
        dict[str, Any],
        Field(
            description="Config from https://huggingface.co/docs/transformers/en/main_classes/text_generation#transformers.GenerationConfig",
            examples=[{"max_new_tokens": 200, "do_sample": False}],
        ),
    ] = {"max_new_tokens": 200, "do_sample": False}


class PictureDescriptionApi(BaseModel):
    url: Annotated[
        AnyUrl,
        Field(
            description="Endpoint which accepts openai-api compatible requests.",
            examples=[
                AnyUrl(
                    "http://localhost:8000/v1/chat/completions"
                ),  # example of a local vllm api
                AnyUrl(
                    "http://localhost:11434/v1/chat/completions"
                ),  # example of ollama
            ],
        ),
    ]
    headers: Annotated[
        dict[str, str],
        Field(
            description="Headers used for calling the API endpoint. For example, it could include authentication headers."
        ),
    ] = {}
    params: Annotated[
        dict[str, Any],
        Field(
            description="Model parameters.",
            examples=[
                {  # on vllm
                    "model": "HuggingFaceTB/SmolVLM-256M-Instruct",
                    "max_completion_tokens": 200,
                },
                {  # on vllm
                    "model": "ibm-granite/granite-vision-3.2-2b",
                    "max_completion_tokens": 200,
                },
                {  # on ollama
                    "model": "granite3.2-vision:2b"
                },
            ],
        ),
    ] = {}
    timeout: Annotated[float, Field(description="Timeout for the API request.")] = 20
    prompt: Annotated[
        str,
        Field(
            description="Prompt used when calling the vision-language model.",
            examples=[
                "Describe this image in a few sentences.",
                "This is a figures from a document. Provide a detailed description of it.",
            ],
        ),
    ] = "Describe this image in a few sentences."


class PictureAnnotationModelType(str, Enum):
    """Available picture annotation model types."""
    LOCAL = "local"
    RUNPOD = "runpod"
    OPENAI = "openai"


class RunPodAnnotationConfig(BaseModel):
    """Configuration for RunPod annotation model."""
    api_key: Annotated[
        str,
        Field(
            description="RunPod API key. Can be provided via RUNPOD_API_KEY environment variable.",
        ),
    ]
    worker_id: Annotated[
        str,
        Field(
            description="RunPod worker ID. Can be provided via RUNPOD_WORKER environment variable.",
        ),
    ]
    model: Annotated[
        str,
        Field(
            description="Model name to use.",
            examples=["Qwen/Qwen2.5-VL-3B-Instruct"],
        ),
    ] = "Qwen/Qwen2.5-VL-3B-Instruct"
    prompt: Annotated[
        str,
        Field(
            description="Prompt for image annotation.",
        ),
    ] = "اوصفلي الصورة دي وصف رياضي دقيق جداً جداً وخليك دقيق لاكتر درجه ممكنه"
    temperature: Annotated[
        float,
        Field(description="Temperature for model inference.", ge=0.0, le=2.0),
    ] = 0.6


class OpenAIAnnotationConfig(BaseModel):
    """Configuration for OpenAI annotation model."""
    api_key: Annotated[
        str,
        Field(
            description="OpenAI API key. Can be provided via OPENAI_API_KEY environment variable.",
        ),
    ]
    model: Annotated[
        str,
        Field(
            description="OpenAI model to use for image annotation.",
            examples=["gpt-4-vision-preview", "gpt-4o"],
        ),
    ] = "gpt-4-vision-preview"
    prompt: Annotated[
        str,
        Field(
            description="Prompt for image annotation.",
        ),
    ] = "Describe this image in detail with mathematical precision."
    temperature: Annotated[
        float,
        Field(description="Temperature for model inference.", ge=0.0, le=2.0),
    ] = 0.6


class PictureAnnotationOptions(BaseModel):
    """Options for picture annotation using various models."""
    model_type: Annotated[
        PictureAnnotationModelType,
        Field(
            description="Type of model to use for picture annotation.",
        ),
    ] = PictureAnnotationModelType.LOCAL
    
    runpod_config: Annotated[
        Optional[RunPodAnnotationConfig],
        Field(
            description="Configuration for RunPod model. Required when model_type is 'runpod'.",
        ),
    ] = None
    
    openai_config: Annotated[
        Optional[OpenAIAnnotationConfig],
        Field(
            description="Configuration for OpenAI model. Required when model_type is 'openai'.",
        ),
    ] = None

    @model_validator(mode="after")
    def validate_model_config(self) -> Self:
        if self.model_type == PictureAnnotationModelType.RUNPOD and self.runpod_config is None:
            raise ValueError("runpod_config is required when model_type is 'runpod'")
        if self.model_type == PictureAnnotationModelType.OPENAI and self.openai_config is None:
            raise ValueError("openai_config is required when model_type is 'openai'")
        return self


# Merged ConvertDocumentsOptions that extends the base class with your custom features
class ConvertDocumentsOptions(BaseConvertDocumentsOptions):
    """Extended options that include custom Arabic language support and enhancements."""
    
    # Override OCR engine to use the factory enum
    ocr_engine: Annotated[  # type: ignore
        ocr_engines_enum,
        Field(
            description=(
                "The OCR engine to use. String. "
                f"Allowed values: {', '.join([v.value for v in ocr_engines_enum])}. "
                "Optional, defaults to easyocr."
            ),
            examples=[EasyOcrOptions.kind],
        ),
    ] = ocr_engines_enum(EasyOcrOptions.kind)  # type: ignore

    # Document timeout with custom limit
    document_timeout: Annotated[
        float,
        Field(
            description="The timeout for processing each document, in seconds.",
            gt=0,
            le=docling_serve_settings.max_document_timeout,
        ),
    ] = docling_serve_settings.max_document_timeout

    # Your custom enhancements
    do_document_enhancement: Annotated[
        bool,
        Field(
            description=(
                "If enabled, apply document enhancement with OCR. "
                "Boolean. Optional, defaults to false."
            ),
            examples=[False],
        ),
    ] = False

    enable_character_encoding_fix: Annotated[
        bool,
        Field(
            description=(
                "If enabled, fix character encoding errors in text. "
                "Only works when do_document_enhancement is True. "
                "Boolean. Optional, defaults to false."
            ),
            examples=[False],
        ),
    ] = False

    picture_description_area_threshold: Annotated[
        float,
        Field(
            description="Minimum percentage of the area for a picture to be processed with the models.",
            examples=[PictureDescriptionBaseOptions().picture_area_threshold],
        ),
    ] = PictureDescriptionBaseOptions().picture_area_threshold

    picture_description_local: Annotated[
        Optional[PictureDescriptionLocal],
        Field(
            description="Options for running a local vision-language model in the picture description. The parameters refer to a model hosted on Hugging Face. This parameter is mutually exclusive with picture_description_api.",
            examples=[
                PictureDescriptionLocal(repo_id="ibm-granite/granite-vision-3.2-2b"),
                PictureDescriptionLocal(repo_id="HuggingFaceTB/SmolVLM-256M-Instruct"),
            ],
        ),
    ] = None

    picture_description_api: Annotated[
        Optional[PictureDescriptionApi],
        Field(
            description="API details for using a vision-language model in the picture description. This parameter is mutually exclusive with picture_description_local.",
            examples=[
                PictureDescriptionApi(
                    url="http://localhost:11434/v1/chat/completions",
                    params={"model": "granite3.2-vision:2b"},
                )
            ],
        ),
    ] = None

    picture_annotation: Annotated[
        Optional[PictureAnnotationOptions],
        Field(
            description="Options for picture annotation using various models.",
        ),
    ] = None

    @model_validator(mode="after")
    def picture_description_exclusivity(self) -> Self:
        # Validate picture description options
        if (
            self.picture_description_local is not None
            and self.picture_description_api is not None
        ):
            raise ValueError(
                "The parameters picture_description_local and picture_description_api are mutually exclusive, only one of them can be set."
            )

        return self


# For API requests, use the same class but with a different name for clarity
class ConvertDocumentsRequestOptions(ConvertDocumentsOptions):
    """Request options for document conversion API."""
    pass
