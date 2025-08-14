ARG BASE_IMAGE=quay.io/sclorg/python-312-c9s:c9s

ARG UV_VERSION=0.8.3

ARG UV_SYNC_EXTRA_ARGS=""

FROM ${BASE_IMAGE} AS docling-base

###################################################################################################
# OS Layer                                                                                        #
###################################################################################################

USER 0

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

FROM ghcr.io/astral-sh/uv:${UV_VERSION} AS uv_stage

###################################################################################################
# Docling layer                                                                                   #
###################################################################################################

FROM docling-base

USER 1001

WORKDIR /opt/app-root/src

ENV \
    OMP_NUM_THREADS=4 \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    PYTHONIOENCODING=utf-8 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PROJECT_ENVIRONMENT=/opt/app-root \
    DOCLING_SERVE_ARTIFACTS_PATH=/opt/app-root/src/.cache/docling/models \
    HF_HOME=/opt/app-root/src/.cache/huggingface \
    TRANSFORMERS_CACHE=/opt/app-root/src/.cache/huggingface/transformers \
    HUGGINGFACE_HUB_CACHE=/opt/app-root/src/.cache/huggingface/hub \
    DOCLING_SERVE_ENABLE_UI=1

ARG UV_SYNC_EXTRA_ARGS

RUN --mount=from=uv_stage,source=/uv,target=/bin/uv \
    --mount=type=cache,target=/tmp/uv-cache,uid=1001 \
    --mount=type=bind,source=uv.lock,target=/tmp/project/uv.lock \
    --mount=type=bind,source=pyproject.toml,target=/tmp/project/pyproject.toml \
    mkdir -p /tmp/project && cd /tmp/project && umask 002 && \
    UV_SYNC_ARGS="--frozen --no-install-project --no-dev" && \
    /bin/uv sync ${UV_SYNC_ARGS} --extra ui --extra easyocr --no-extra flash-attn && \
    FLASH_ATTENTION_SKIP_CUDA_BUILD=TRUE /bin/uv sync ${UV_SYNC_ARGS} --extra ui --extra easyocr --no-build-isolation-package=flash-attn && \
    chown -R 1001:0 /opt/app-root && chmod -R g+w /opt/app-root

ARG MODELS_LIST="layout tableformer picture_classifier easyocr code_formula smoldocling"

RUN echo "Downloading models..." && \
    HF_HUB_DOWNLOAD_TIMEOUT="90" \
    HF_HUB_ETAG_TIMEOUT="90" \
    docling-tools models download -o "${DOCLING_SERVE_ARTIFACTS_PATH}" ${MODELS_LIST} && \
    chown -R 1001:0 ${DOCLING_SERVE_ARTIFACTS_PATH} && \
    chmod -R g=u ${DOCLING_SERVE_ARTIFACTS_PATH}

COPY --chown=1001:0 ./docling_serve ./docling_serve

RUN --mount=from=uv_stage,source=/uv,target=/bin/uv \
    --mount=type=cache,target=/opt/app-root/src/.cache/uv,uid=1001 \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    umask 002 && /bin/uv sync --frozen --no-dev --extra ui --extra easyocr ${UV_SYNC_EXTRA_ARGS}

EXPOSE 5001

CMD ["docling-serve", "run", "--enable-ui"]
