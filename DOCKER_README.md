# Docling Serve Docker Deployment Guide

🚀 **Production-ready Docker deployment for Docling Serve with GPU CUDA 12.8, UI, and EasyOCR support**

## 🎯 Overview

This repository provides a complete CI/CD pipeline and deployment solution for Docling Serve with:

- **GPU Support**: NVIDIA CUDA 12.8 for accelerated document processing
- **Enhanced UI**: Gradio-based web interface for easy document conversion
- **EasyOCR Integration**: Advanced OCR capabilities for multiple languages (English, Arabic)
- **Multi-Registry Support**: Automated builds for Docker Hub (primary), GHCR, and Quay.io
- **Production Ready**: Load balancing, monitoring, and security features

## 📦 Available Docker Images

### Docker Hub (Primary - Built First)

| Image | Description | Size | Platforms |
|-------|-------------|------|-----------|
| `your-username/docling-serve:latest` | Latest with UI and EasyOCR | ~12GB | amd64, arm64 |
| `your-username/docling-serve:gpu-cu128` | CUDA 12.8 with UI and EasyOCR | ~14GB | amd64 |
| `your-username/docling-serve:cpu` | CPU-only with UI and EasyOCR | ~8GB | amd64, arm64 |

### GHCR (Secondary)

| Image | Description |
|-------|-------------|
| `ghcr.io/your-org/doc-parser:latest` | Mirror of latest |
| `ghcr.io/your-org/doc-parser:gpu-cu128` | Mirror of GPU version |
| `ghcr.io/your-org/doc-parser:cpu` | Mirror of CPU version |

### Quay.io (Tertiary)

| Image | Description |
|-------|-------------|
| `quay.io/your-username/docling-serve:latest` | Mirror of latest |
| `quay.io/your-username/docling-serve:gpu-cu128` | Mirror of GPU version |

## 🚀 Quick Start

### Prerequisites

1. **Docker & Docker Compose**
   ```bash
   # Ubuntu/Debian
   curl -fsSL https://get.docker.com -o get-docker.sh
   sh get-docker.sh
   sudo apt-get install docker-compose-plugin
   
   # Windows: Install Docker Desktop
   # macOS: Install Docker Desktop
   ```

2. **NVIDIA Docker (for GPU support)**
   ```bash
   # Ubuntu/Debian
   distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
   curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
   curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
   sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
   sudo systemctl restart docker
   ```

### Development Deployment

1. **Clone and setup**
   ```bash
   git clone https://github.com/OsamaM0/Doc-Parser.git
   cd Doc-Parser
   chmod +x deploy.sh
   ```

2. **Deploy development environment**
   ```bash
   # Linux/macOS
   ./deploy.sh dev
   
   # Windows PowerShell
   .\deploy.ps1 dev
   ```

3. **Access services**
   - API: http://localhost:5001
   - Documentation: http://localhost:5001/docs
   - UI: http://localhost:5001/ui

### Production Deployment

1. **Setup environment variables**
   ```bash
   export DOCKER_HUB_USERNAME=your-username
   ```

2. **Deploy production environment**
   ```bash
   # Linux/macOS
   ./deploy.sh prod
   
   # Windows PowerShell
   $env:DOCKER_HUB_USERNAME="your-username"
   .\deploy.ps1 prod
   ```

3. **Access services**
   - Main site: http://localhost
   - API: http://localhost/v1/
   - Documentation: http://localhost/docs
   - UI: http://localhost/ui

## 🔧 Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DOCLING_SERVE_ENABLE_UI` | `1` | Enable Gradio UI |
| `DOCLING_SERVE_HOST` | `0.0.0.0` | Host to bind to |
| `DOCLING_SERVE_PORT` | `5001` | Port to bind to |
| `CUDA_VISIBLE_DEVICES` | `all` | GPU devices to use |
| `OMP_NUM_THREADS` | `4` | OpenMP threads |

### Docker Compose Profiles

| Profile | Services | Use Case |
|---------|----------|----------|
| default | docling-serve-gpu | Development |
| cpu-fallback | docling-serve-cpu | CPU-only mode |
| production | nginx, docling-serve-gpu | Production with load balancer |
| caching | redis | Enable caching |
| monitoring | prometheus, grafana | Monitoring stack |

## 📋 Usage Examples

### Basic Document Conversion

```bash
# Convert a PDF from URL
curl -X POST "http://localhost:5001/v1/convert/source" \
  -H "Content-Type: application/json" \
  -d '{
    "sources": [{"kind": "http", "url": "https://arxiv.org/pdf/2501.17887"}]
  }'

# Upload and convert a file
curl -X POST "http://localhost:5001/v1/convert/upload" \
  -F "file=@document.pdf" \
  -F "options={\"format\": \"markdown\"}"
```

### Using the UI

1. Navigate to http://localhost:5001/ui
2. Upload your document or provide a URL
3. Select conversion options
4. Download the converted document

### API Documentation

Interactive API documentation is available at http://localhost:5001/docs

## 🛠️ Development

### Building Custom Images

```bash
# Build GPU image
docker build -f Containerfile.gpu -t my-docling-serve:gpu-cu128 \
  --build-arg UV_SYNC_EXTRA_ARGS="--no-group pypi --group cu128 --all-extras" .

# Build CPU image
docker build -f Containerfile -t my-docling-serve:cpu \
  --build-arg UV_SYNC_EXTRA_ARGS="--no-group pypi --group cpu --all-extras --no-extra flash-attn" .
```

### Local Development

```bash
# Start development environment
docker-compose -f docker-compose.gpu.yml up -d docling-serve-gpu

# View logs
docker-compose -f docker-compose.gpu.yml logs -f docling-serve-gpu

# Restart service
docker-compose -f docker-compose.gpu.yml restart docling-serve-gpu
```

## 🔍 Monitoring

### Health Checks

```bash
# Check service health
curl http://localhost:5001/health

# Check with deployment script
./deploy.sh test
```

### Logs

```bash
# View logs
./deploy.sh logs

# View specific service logs
./deploy.sh logs docling-serve-gpu
```

### Resource Monitoring

```bash
# View resource usage
./deploy.sh status

# Enable monitoring stack
docker-compose -f docker-compose.gpu.yml --profile monitoring up -d
# Access Grafana: http://localhost:3000 (admin/admin123)
```

## 🚀 CI/CD Pipeline

The repository includes a comprehensive GitHub Actions CI/CD pipeline that:

1. **Builds Docker images** for multiple variants (latest, gpu-cu128, cpu)
2. **Pushes to Docker Hub first** (primary registry)
3. **Mirrors to GHCR and Quay.io** (secondary/tertiary)
4. **Runs security scans** with Trivy
5. **Performs health tests** on built images
6. **Creates releases** with detailed notes

### Required Secrets

Set these in your GitHub repository settings:

| Secret | Description |
|--------|-------------|
| `DOCKER_HUB_USERNAME` | Your Docker Hub username |
| `DOCKER_HUB_TOKEN` | Docker Hub access token |
| `QUAY_USERNAME` | Quay.io username |
| `QUAY_TOKEN` | Quay.io access token |

### Workflow Triggers

- **Push to main/develop**: Builds and pushes images
- **Tags (v*)**: Creates releases
- **Pull requests**: Builds without pushing
- **Manual dispatch**: Force build all images

## 📊 Performance Tuning

### GPU Configuration

```yaml
# For multiple GPUs
environment:
  - CUDA_VISIBLE_DEVICES=0,1
  - OMP_NUM_THREADS=8

deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          device_ids: ['0', '1']
          capabilities: [gpu]
```

### Memory Optimization

```yaml
# Increase shared memory for large documents
services:
  docling-serve-gpu:
    shm_size: 2gb
    ulimits:
      memlock: -1
      stack: 67108864
```

## 🔒 Security

### SSL/TLS Configuration

1. **Generate certificates**
   ```bash
   mkdir -p nginx/ssl
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
     -keyout nginx/ssl/key.pem \
     -out nginx/ssl/cert.pem
   ```

2. **Update nginx.conf** to enable HTTPS server block

### Security Headers

The Nginx configuration includes security headers:
- X-Content-Type-Options
- X-Frame-Options
- X-XSS-Protection
- Referrer-Policy

## 🐛 Troubleshooting

### Common Issues

1. **GPU not detected**
   ```bash
   # Verify NVIDIA Docker
   docker run --rm --gpus all nvidia/cuda:12.8-base-ubuntu22.04 nvidia-smi
   ```

2. **Out of memory**
   ```bash
   # Reduce batch size or use CPU version
   docker-compose -f docker-compose.gpu.yml --profile cpu-fallback up -d
   ```

3. **Port conflicts**
   ```bash
   # Change ports in docker-compose.gpu.yml
   ports:
     - "5002:5001"  # Use different host port
   ```

### Logs and Debugging

```bash
# View all logs
docker-compose -f docker-compose.gpu.yml logs

# Debug specific service
docker-compose -f docker-compose.gpu.yml exec docling-serve-gpu bash

# Check resource usage
docker stats
```

## 📚 Additional Resources

- [Docling Documentation](https://github.com/docling-project/docling)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with `./deploy.sh test`
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Docling Project](https://github.com/docling-project/docling) for the core technology
- [EasyOCR](https://github.com/JaidedAI/EasyOCR) for OCR capabilities
- [NVIDIA](https://developer.nvidia.com/cuda-toolkit) for CUDA support
