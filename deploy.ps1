# Docling Serve GPU Deployment Script for Windows
# This script helps deploy Docling Serve with GPU support, UI, and EasyOCR

param(
    [Parameter(Position=0)]
    [ValidateSet("check", "setup", "pull", "dev", "prod", "status", "test", "logs", "restart", "cleanup", "help")]
    [string]$Command = "help",
    
    [Parameter(Position=1)]
    [string]$Service = "docling-serve-gpu"
)

# Configuration
$DOCKER_HUB_USERNAME = $env:DOCKER_HUB_USERNAME
$IMAGE_NAME = "docling-serve"
$DEFAULT_TAG = "gpu-cu128"

# Helper functions
function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Blue }
function Write-Success { param($Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
function Write-Warning { param($Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }

function Show-Banner {
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Blue
    Write-Host "║                 Docling Serve GPU Deployment                ║" -ForegroundColor Blue
    Write-Host "║            With CUDA 12.8, UI, and EasyOCR Support         ║" -ForegroundColor Blue
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Blue
}

function Test-Requirements {
    Write-Info "Checking system requirements..."
    
    # Check Docker
    try {
        docker --version | Out-Null
        Write-Success "Docker found!"
    }
    catch {
        Write-Error "Docker is not installed. Please install Docker Desktop first."
        exit 1
    }
    
    # Check Docker Compose
    try {
        docker-compose --version | Out-Null
        Write-Success "Docker Compose found!"
    }
    catch {
        try {
            docker compose version | Out-Null
            Write-Success "Docker Compose (v2) found!"
        }
        catch {
            Write-Error "Docker Compose is not installed. Please install Docker Compose first."
            exit 1
        }
    }
    
    # Check NVIDIA Docker (for GPU support)
    try {
        docker run --rm --gpus all nvidia/cuda:12.8-base-ubuntu22.04 nvidia-smi | Out-Null
        Write-Success "NVIDIA Docker runtime detected!"
    }
    catch {
        Write-Warning "NVIDIA Docker runtime not detected. GPU support may not work."
        Write-Info "Install NVIDIA Container Toolkit for GPU support."
    }
    
    Write-Success "System requirements check completed!"
}

function Initialize-Directories {
    Write-Info "Setting up directories..."
    
    $directories = @("data", "logs", "cache", "nginx\ssl", "monitoring\grafana\provisioning")
    
    foreach ($dir in $directories) {
        if (!(Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
    
    Write-Success "Directories created successfully!"
}

function Deploy-Development {
    Write-Info "Deploying in development mode..."
    
    # Start GPU version
    docker-compose -f docker-compose.gpu.yml up -d docling-serve-gpu
    
    Write-Info "Waiting for service to be ready..."
    Start-Sleep -Seconds 30
    
    # Health check
    try {
        Invoke-RestMethod -Uri "http://localhost:5001/health" -Method Get | Out-Null
        Write-Success "Development deployment successful!"
        Write-Info "Services available at:"
        Write-Host "  - API: http://localhost:5001"
        Write-Host "  - Documentation: http://localhost:5001/docs"
        Write-Host "  - UI: http://localhost:5001/ui"
    }
    catch {
        Write-Error "Health check failed. Check logs with: docker-compose -f docker-compose.gpu.yml logs"
        exit 1
    }
}

function Deploy-Production {
    Write-Info "Deploying in production mode..."
    
    # Start all production services
    docker-compose -f docker-compose.gpu.yml --profile production up -d
    
    Write-Info "Waiting for services to be ready..."
    Start-Sleep -Seconds 60
    
    # Health check
    try {
        Invoke-RestMethod -Uri "http://localhost/health" -Method Get | Out-Null
        Write-Success "Production deployment successful!"
        Write-Info "Services available at:"
        Write-Host "  - Main site: http://localhost"
        Write-Host "  - API: http://localhost/v1/"
        Write-Host "  - Documentation: http://localhost/docs"
        Write-Host "  - UI: http://localhost/ui"
    }
    catch {
        Write-Error "Health check failed. Check logs with: docker-compose -f docker-compose.gpu.yml logs"
        exit 1
    }
}

function Get-LatestImages {
    Write-Info "Pulling latest Docker images..."
    
    if ($DOCKER_HUB_USERNAME) {
        try {
            docker pull "$DOCKER_HUB_USERNAME/$IMAGE_NAME`:$DEFAULT_TAG"
            Write-Success "Images pulled from Docker Hub!"
        }
        catch {
            Write-Warning "Failed to pull from Docker Hub. Building locally..."
            docker-compose -f docker-compose.gpu.yml build docling-serve-gpu
        }
    }
    else {
        Write-Info "Building images locally..."
        docker-compose -f docker-compose.gpu.yml build docling-serve-gpu
    }
    
    Write-Success "Images ready!"
}

function Show-Status {
    Write-Info "Service Status:"
    docker-compose -f docker-compose.gpu.yml ps
    
    Write-Host ""
    Write-Info "Resource Usage:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
}

function Test-Services {
    Write-Info "Running health tests..."
    
    $testsPassed = 0
    
    # Test API endpoint
    try {
        Invoke-RestMethod -Uri "http://localhost:5001/health" -Method Get | Out-Null
        Write-Success "✓ Health check passed"
        $testsPassed++
    }
    catch {
        Write-Error "✗ Health check failed"
    }
    
    # Test UI endpoint
    try {
        Invoke-WebRequest -Uri "http://localhost:5001/ui" -Method Get | Out-Null
        Write-Success "✓ UI accessible"
        $testsPassed++
    }
    catch {
        Write-Error "✗ UI not accessible"
    }
    
    # Test API documentation
    try {
        Invoke-WebRequest -Uri "http://localhost:5001/docs" -Method Get | Out-Null
        Write-Success "✓ API documentation accessible"
        $testsPassed++
    }
    catch {
        Write-Error "✗ API documentation not accessible"
    }
    
    if ($testsPassed -eq 3) {
        Write-Success "All tests passed!"
    }
    else {
        Write-Error "Some tests failed. Check the service status."
        return 1
    }
}

function Show-Logs {
    param($ServiceName = "docling-serve-gpu")
    Write-Info "Showing logs for $ServiceName..."
    docker-compose -f docker-compose.gpu.yml logs -f $ServiceName
}

function Remove-Services {
    Write-Info "Cleaning up..."
    docker-compose -f docker-compose.gpu.yml down
    docker system prune -f
    Write-Success "Cleanup completed!"
}

function Show-Help {
    Write-Host "Usage: .\deploy.ps1 [COMMAND] [SERVICE]"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  check       Check system requirements"
    Write-Host "  setup       Setup directories and configuration"
    Write-Host "  pull        Pull latest Docker images"
    Write-Host "  dev         Deploy in development mode"
    Write-Host "  prod        Deploy in production mode"
    Write-Host "  status      Show service status"
    Write-Host "  test        Run health tests"
    Write-Host "  logs        Show logs (optional: specify service name)"
    Write-Host "  restart     Restart services"
    Write-Host "  cleanup     Stop services and cleanup"
    Write-Host "  help        Show this help message"
    Write-Host ""
    Write-Host "Environment Variables:"
    Write-Host "  DOCKER_HUB_USERNAME   Your Docker Hub username (optional)"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\deploy.ps1 check"
    Write-Host "  .\deploy.ps1 dev"
    Write-Host "  .\deploy.ps1 logs docling-serve-gpu"
    Write-Host "  `$env:DOCKER_HUB_USERNAME='myuser'; .\deploy.ps1 pull"
}

# Main script logic
Show-Banner

switch ($Command) {
    "check" {
        Test-Requirements
    }
    "setup" {
        Initialize-Directories
    }
    "pull" {
        Get-LatestImages
    }
    "dev" {
        Test-Requirements
        Initialize-Directories
        Get-LatestImages
        Deploy-Development
    }
    "prod" {
        Test-Requirements
        Initialize-Directories
        Get-LatestImages
        Deploy-Production
    }
    "status" {
        Show-Status
    }
    "test" {
        Test-Services
    }
    "logs" {
        Show-Logs -ServiceName $Service
    }
    "restart" {
        Write-Info "Restarting services..."
        docker-compose -f docker-compose.gpu.yml restart
        Write-Success "Services restarted!"
    }
    "cleanup" {
        Remove-Services
    }
    default {
        Show-Help
    }
}
