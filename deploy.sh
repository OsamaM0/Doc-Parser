#!/bin/bash

# Docling Serve GPU Deployment Script
# This script helps deploy Docling Serve with GPU support, UI, and EasyOCR

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOCKER_HUB_USERNAME="${DOCKER_HUB_USERNAME:-}"
IMAGE_NAME="docling-serve"
DEFAULT_TAG="gpu-cu128"

# Helper functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

print_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                 Docling Serve GPU Deployment                ║"
    echo "║            With CUDA 12.8, UI, and EasyOCR Support         ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_requirements() {
    log_info "Checking system requirements..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    # Check NVIDIA Docker (for GPU support)
    if ! docker run --rm --gpus all nvidia/cuda:12.8-base-ubuntu22.04 nvidia-smi &> /dev/null; then
        log_warning "NVIDIA Docker runtime not detected. GPU support may not work."
        log_info "Install nvidia-container-toolkit for GPU support."
    else
        log_success "NVIDIA Docker runtime detected!"
    fi
    
    log_success "System requirements check completed!"
}

setup_directories() {
    log_info "Setting up directories..."
    
    mkdir -p data logs cache nginx/ssl monitoring/grafana/provisioning
    chmod 755 data logs cache
    
    log_success "Directories created successfully!"
}

deploy_development() {
    log_info "Deploying in development mode..."
    
    # Start GPU version
    docker-compose -f docker-compose.gpu.yml up -d docling-serve-gpu
    
    log_info "Waiting for service to be ready..."
    sleep 30
    
    # Health check
    if curl -f http://localhost:5001/health > /dev/null 2>&1; then
        log_success "Development deployment successful!"
        log_info "Services available at:"
        echo "  - API: http://localhost:5001"
        echo "  - Documentation: http://localhost:5001/docs"
        echo "  - UI: http://localhost:5001/ui"
    else
        log_error "Health check failed. Check logs with: docker-compose -f docker-compose.gpu.yml logs"
        exit 1
    fi
}

deploy_production() {
    log_info "Deploying in production mode..."
    
    # Start all production services
    docker-compose -f docker-compose.gpu.yml --profile production up -d
    
    log_info "Waiting for services to be ready..."
    sleep 60
    
    # Health check
    if curl -f http://localhost/health > /dev/null 2>&1; then
        log_success "Production deployment successful!"
        log_info "Services available at:"
        echo "  - Main site: http://localhost"
        echo "  - API: http://localhost/v1/"
        echo "  - Documentation: http://localhost/docs"
        echo "  - UI: http://localhost/ui"
    else
        log_error "Health check failed. Check logs with: docker-compose -f docker-compose.gpu.yml logs"
        exit 1
    fi
}

pull_latest_images() {
    log_info "Pulling latest Docker images..."
    
    if [ -n "$DOCKER_HUB_USERNAME" ]; then
        docker pull "$DOCKER_HUB_USERNAME/$IMAGE_NAME:$DEFAULT_TAG" || {
            log_warning "Failed to pull from Docker Hub. Building locally..."
            docker build -f Containerfile.gpu --build-arg UV_SYNC_EXTRA_ARGS="--group cu128 --extra ui --extra easyocr" -t docling-serve-gpu .
        }
    else
        log_info "Building images locally..."
        docker build -f Containerfile.gpu --build-arg UV_SYNC_EXTRA_ARGS="--group cu128 --extra ui --extra easyocr" -t docling-serve-gpu .
    fi
    
    log_success "Images ready!"
}

show_status() {
    log_info "Service Status:"
    docker-compose -f docker-compose.gpu.yml ps
    
    echo ""
    log_info "Resource Usage:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
}

run_tests() {
    log_info "Running health tests..."
    
    # Test API endpoint
    if curl -f http://localhost:5001/health > /dev/null 2>&1; then
        log_success "✓ Health check passed"
    else
        log_error "✗ Health check failed"
        return 1
    fi
    
    # Test UI endpoint
    if curl -f http://localhost:5001/ui > /dev/null 2>&1; then
        log_success "✓ UI accessible"
    else
        log_error "✗ UI not accessible"
        return 1
    fi
    
    # Test API documentation
    if curl -f http://localhost:5001/docs > /dev/null 2>&1; then
        log_success "✓ API documentation accessible"
    else
        log_error "✗ API documentation not accessible"
        return 1
    fi
    
    log_success "All tests passed!"
}

show_logs() {
    local service="${1:-docling-serve-gpu}"
    log_info "Showing logs for $service..."
    docker-compose -f docker-compose.gpu.yml logs -f "$service"
}

cleanup() {
    log_info "Cleaning up..."
    docker-compose -f docker-compose.gpu.yml down
    docker system prune -f
    log_success "Cleanup completed!"
}

show_help() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  check       Check system requirements"
    echo "  setup       Setup directories and configuration"
    echo "  pull        Pull latest Docker images"
    echo "  dev         Deploy in development mode"
    echo "  prod        Deploy in production mode"
    echo "  status      Show service status"
    echo "  test        Run health tests"
    echo "  logs        Show logs (optional: specify service name)"
    echo "  restart     Restart services"
    echo "  cleanup     Stop services and cleanup"
    echo "  help        Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  DOCKER_HUB_USERNAME   Your Docker Hub username (optional)"
    echo ""
    echo "Examples:"
    echo "  $0 check"
    echo "  $0 dev"
    echo "  $0 logs docling-serve-gpu"
    echo "  DOCKER_HUB_USERNAME=myuser $0 pull"
}

# Main script logic
main() {
    print_banner
    
    case "${1:-help}" in
        "check")
            check_requirements
            ;;
        "setup")
            setup_directories
            ;;
        "pull")
            pull_latest_images
            ;;
        "dev")
            check_requirements
            setup_directories
            pull_latest_images
            deploy_development
            ;;
        "prod")
            check_requirements
            setup_directories
            pull_latest_images
            deploy_production
            ;;
        "status")
            show_status
            ;;
        "test")
            run_tests
            ;;
        "logs")
            show_logs "${2:-docling-serve-gpu}"
            ;;
        "restart")
            log_info "Restarting services..."
            docker-compose -f docker-compose.gpu.yml restart
            log_success "Services restarted!"
            ;;
        "cleanup")
            cleanup
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# Run main function with all arguments
main "$@"
