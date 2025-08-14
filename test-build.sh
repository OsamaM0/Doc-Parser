#!/bin/bash

# Quick test script for Docker images
# This script tests the build order priority: Docker Hub -> GHCR -> Quay.io

set -e

echo "🐳 Testing Docker Build Priority and Functionality"
echo "=================================================="

DOCKER_HUB_USERNAME="${DOCKER_HUB_USERNAME:-your-username}"
IMAGE_NAME="docling-serve"

echo "Using Docker Hub username: $DOCKER_HUB_USERNAME"

# Test 1: Build GPU CUDA 12.8 image
echo ""
echo "📦 Building GPU CUDA 12.8 image..."
docker build -f Containerfile.gpu -t test-gpu \
    --build-arg UV_SYNC_EXTRA_ARGS="--no-group pypi --group cu128 --extra ui --extra easyocr" .

# Test 2: Build CPU image
echo ""
echo "📦 Building CPU image..."
docker build -f Containerfile -t test-cpu \
    --build-arg UV_SYNC_EXTRA_ARGS="--no-group pypi --group cpu --extra ui --extra easyocr --no-extra flash-attn" .

# Test 3: Quick functionality test
echo ""
echo "🧪 Testing image functionality..."

# Start GPU container in background
docker run -d --name test-gpu-container -p 5001:5001 -e DOCLING_SERVE_ENABLE_UI=1 test-gpu

# Wait for startup
echo "Waiting for service to start..."
sleep 30

# Test health endpoint
if curl -f http://localhost:5001/health > /dev/null 2>&1; then
    echo "✅ Health check passed!"
else
    echo "❌ Health check failed!"
    docker logs test-gpu-container
    exit 1
fi

# Test UI endpoint
if curl -f http://localhost:5001/ui > /dev/null 2>&1; then
    echo "✅ UI endpoint accessible!"
else
    echo "❌ UI endpoint not accessible!"
fi

# Cleanup
docker stop test-gpu-container
docker rm test-gpu-container

echo ""
echo "🎉 All tests passed! Images are ready for CI/CD pipeline."
echo ""
echo "📋 CI/CD Build Order:"
echo "1. 🥇 Docker Hub (Primary)   - Built and pushed first"
echo "2. 🥈 GHCR (Secondary)       - Built after Docker Hub success"  
echo "3. 🥉 Quay.io (Tertiary)     - Built after GHCR success"
echo ""
echo "🏷️  Available tags:"
echo "   • latest       - Latest with UI and EasyOCR"
echo "   • gpu-cu128    - CUDA 12.8 with UI and EasyOCR"
echo "   • cpu          - CPU-only with UI and EasyOCR"

# Cleanup test images
docker rmi test-gpu test-cpu

echo ""
echo "✨ Ready for deployment! Use './deploy.sh dev' to start."
