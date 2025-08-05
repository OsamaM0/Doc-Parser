ARG BASE_IMAGE=quay.io/sclorg/python-312-c9s:c9s

FROM ${BASE_IMAGE}

USER 0

###################################################################################################
# OS Layer                                                                                        #
###################################################################################################

RUN --mount=type=bind,source=os-packages.txt,target=/tmp/os-packages.txt \
    dnf -y install --best --nodocs --setopt=install_weak_deps=False dnf-plugins-core && \
    dnf config-manager --best --nodocs --setopt=install_weak_deps=False --save && \
    dnf config-manager --enable crb && \
    dnf -y update && \
    dnf install -y $(cat /tmp/os-packages.txt) && \
    dnf -y clean all && \
    rm -rf /var/cache/dnf

RUN /usr/bin/fix-permissions /opt/app-root/src/.cache

ENV TESSDATA_PREFIX=/usr/share/tesseract/tessdata/

###################################################################################################
# Docling layer                                                                                   #
###################################################################################################

USER 1001

WORKDIR /opt/app-root/src

ENV \
    # On container environments, always set a thread budget to avoid undesired thread congestion.
    OMP_NUM_THREADS=4 \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    PYTHONIOENCODING=utf-8 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PROJECT_ENVIRONMENT=/opt/app-root \
    DOCLING_SERVE_ARTIFACTS_PATH=/opt/app-root/src/.cache/docling/models

ARG UV_SYNC_EXTRA_ARGS=""

RUN --mount=from=ghcr.io/astral-sh/uv:0.7.13,source=/uv,target=/bin/uv \
    --mount=type=cache,target=/opt/app-root/src/.cache/uv,uid=1001 \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    umask 002 && \
    UV_SYNC_ARGS="--frozen --no-install-project --no-dev --all-extras" && \
    # Auto-detect environment and set appropriate UV_SYNC_EXTRA_ARGS if not provided \
    if [ -z "${UV_SYNC_EXTRA_ARGS}" ]; then \
        # Check if we have NVIDIA GPU support \
        if nvidia-smi >/dev/null 2>&1; then \
            echo "NVIDIA GPU detected, using CUDA 12.8 configuration" && \
            UV_SYNC_EXTRA_ARGS="--no-group pypi --group cu128"; \
        else \
            echo "No NVIDIA GPU detected, using CPU configuration" && \
            UV_SYNC_EXTRA_ARGS="--no-group pypi --group cpu --no-extra flash-attn"; \
        fi; \
    fi && \
    echo "Using UV_SYNC_EXTRA_ARGS: ${UV_SYNC_EXTRA_ARGS}" && \
    # Handle flash-attn installation based on configuration \
    if echo "${UV_SYNC_EXTRA_ARGS}" | grep -q "no-extra flash-attn"; then \
        echo "Installing without flash-attn" && \
        uv sync ${UV_SYNC_ARGS} ${UV_SYNC_EXTRA_ARGS}; \
    else \
        echo "Installing with flash-attn (GPU configuration)" && \
        uv sync ${UV_SYNC_ARGS} ${UV_SYNC_EXTRA_ARGS} --no-extra flash-attn && \
        FLASH_ATTENTION_SKIP_CUDA_BUILD=TRUE uv sync ${UV_SYNC_ARGS} ${UV_SYNC_EXTRA_ARGS} --no-build-isolation-package=flash-attn; \
    fi

ARG MODELS_LIST="layout tableformer picture_classifier easyocr"

RUN echo "Downloading models..." && \
    HF_HUB_DOWNLOAD_TIMEOUT="90" \
    HF_HUB_ETAG_TIMEOUT="90" \
    docling-tools models download -o "${DOCLING_SERVE_ARTIFACTS_PATH}" ${MODELS_LIST} && \
    chown -R 1001:0 ${DOCLING_SERVE_ARTIFACTS_PATH} && \
    chmod -R g=u ${DOCLING_SERVE_ARTIFACTS_PATH}

COPY --chown=1001:0 ./docling_serve ./docling_serve
RUN --mount=from=ghcr.io/astral-sh/uv:0.7.13,source=/uv,target=/bin/uv \
    --mount=type=cache,target=/opt/app-root/src/.cache/uv,uid=1001 \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    umask 002 && \
    # Auto-detect environment again for final sync \
    if [ -z "${UV_SYNC_EXTRA_ARGS}" ]; then \
        if nvidia-smi >/dev/null 2>&1; then \
            UV_SYNC_EXTRA_ARGS="--no-group pypi --group cu128"; \
        else \
            UV_SYNC_EXTRA_ARGS="--no-group pypi --group cpu --no-extra flash-attn"; \
        fi; \
    fi && \
    echo "Final sync with UV_SYNC_EXTRA_ARGS: ${UV_SYNC_EXTRA_ARGS}" && \
    uv sync --frozen --no-dev --all-extras ${UV_SYNC_EXTRA_ARGS}

EXPOSE 5001

CMD ["docling-serve", "run"]
