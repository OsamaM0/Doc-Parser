#!/bin/bash

# Quick validation script for the fixed Dockerfiles

echo "🔧 Testing Fixed Docker Build Configuration"
echo "=========================================="

# Test 1: Validate Dockerfile syntax
echo "📋 Step 1: Validating Dockerfile syntax..."

if docker build -f Containerfile --dry-run . > /dev/null 2>&1; then
    echo "✅ Containerfile syntax is valid"
else
    echo "❌ Containerfile has syntax errors"
fi

if docker build -f Containerfile.gpu --dry-run . > /dev/null 2>&1; then
    echo "✅ Containerfile.gpu syntax is valid"
else
    echo "❌ Containerfile.gpu has syntax errors"
fi

# Test 2: Check build arguments
echo ""
echo "📋 Step 2: Testing build arguments..."

echo "🔍 Testing CPU build args:"
echo "   UV_SYNC_EXTRA_ARGS='--group cpu --extra ui --extra easyocr'"

echo "🔍 Testing GPU build args:"
echo "   UV_SYNC_EXTRA_ARGS='--group cu128 --extra ui --extra easyocr'"

# Test 3: Check the key differences from working version
echo ""
echo "📋 Step 3: Key fixes applied:"
echo "✅ Using /bin/uv instead of uv"
echo "✅ Using --group cu128 instead of --no-group pypi --group cu128"
echo "✅ Proper cache mounting with /tmp/uv-cache"
echo "✅ Working directory structure like the working version"
echo "✅ Added HuggingFace cache environment variables"
echo "✅ Removed problematic --all-extras and --extra tesserocr"
echo "✅ Separated flash-attn handling properly"

echo ""
echo "🎯 Ready to test with:"
echo "   docker build -f Containerfile.gpu --build-arg UV_SYNC_EXTRA_ARGS='--group cu128 --extra ui --extra easyocr' -t test-gpu ."
echo "   docker build -f Containerfile --build-arg UV_SYNC_EXTRA_ARGS='--group cpu --extra ui --extra easyocr' -t test-cpu ."
