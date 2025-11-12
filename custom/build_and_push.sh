#!/bin/bash
set -e

# ==========================================
# LiteLLM Docker Image Build & Push Script
# ==========================================
# 
# Purpose: Build LiteLLM container image and push to GCP GCR
# Environment: macOS M4 with Colima docker daemon
# Target: us.gcr.io/liner-219011/litellm-proxy/omni:custom-1
#
# Usage:
#   ./build_and_push.sh                    # Build and push
#   ./build_and_push.sh --build-only       # Build only
#   ./build_and_push.sh --push-only        # Push only (assumes image exists)
#   ./build_and_push.sh --multi-platform   # Build for multiple platforms
#

# ==========================================
# Configuration
# ==========================================

# GCR configuration
GCR_REGISTRY="us.gcr.io"
GCP_PROJECT="liner-219011"
IMAGE_NAME="litellm-proxy/omni"
IMAGE_TAG="custom-5"
FULL_IMAGE_NAME="${GCR_REGISTRY}/${GCP_PROJECT}/${IMAGE_NAME}:${IMAGE_TAG}"

# Docker configuration
DOCKERFILE="Dockerfile"
BUILD_CONTEXT="../"  # Build from project root

# Platform configuration (M4 is ARM64)
DEFAULT_PLATFORM="linux/amd64"
MULTI_PLATFORM="linux/amd64,linux/arm64"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ==========================================
# Functions
# ==========================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if docker is installed and running
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    # Check if docker daemon is running
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running. Please start Colima:"
        echo "  colima start"
        exit 1
    fi
    
    # Check if gcloud is installed
    if ! command -v gcloud &> /dev/null; then
        log_error "gcloud CLI is not installed. Please install it:"
        echo "  https://cloud.google.com/sdk/docs/install"
        exit 1
    fi
    
    # Check if Dockerfile exists
    if [ ! -f "${BUILD_CONTEXT}/${DOCKERFILE}" ]; then
        log_error "Dockerfile not found at: ${BUILD_CONTEXT}/${DOCKERFILE}"
        exit 1
    fi
    
    log_success "All prerequisites met"
}

configure_docker_auth() {
    log_info "Configuring Docker authentication for GCR..."
    
    # Configure docker to use gcloud as credential helper
    gcloud auth configure-docker ${GCR_REGISTRY} --quiet
    
    if [ $? -eq 0 ]; then
        log_success "Docker authentication configured"
    else
        log_error "Failed to configure Docker authentication"
        exit 1
    fi
}

build_image() {
    local platform=$1
    
    log_info "Building Docker image..."
    log_info "Platform: ${platform}"
    log_info "Image: ${FULL_IMAGE_NAME}"
    log_info "Context: ${BUILD_CONTEXT}"
    
    # Build the image
    docker build \
        --platform ${platform} \
        -t ${FULL_IMAGE_NAME} \
        -f ${BUILD_CONTEXT}/${DOCKERFILE} \
        ${BUILD_CONTEXT}
    
    if [ $? -eq 0 ]; then
        log_success "Image built successfully"
    else
        log_error "Failed to build image"
        exit 1
    fi
}

build_multi_platform() {
    log_info "Building multi-platform Docker image..."
    log_info "Platforms: ${MULTI_PLATFORM}"
    log_info "Image: ${FULL_IMAGE_NAME}"
    
    # Check if buildx is available
    if ! docker buildx version &> /dev/null; then
        log_error "docker buildx is not available"
        exit 1
    fi
    
    # Create a new builder instance if it doesn't exist
    if ! docker buildx ls | grep -q "litellm-builder"; then
        log_info "Creating buildx builder instance..."
        docker buildx create --name litellm-builder --use
    else
        docker buildx use litellm-builder
    fi
    
    # Build and push multi-platform image
    docker buildx build \
        --platform ${MULTI_PLATFORM} \
        -t ${FULL_IMAGE_NAME} \
        -f ${BUILD_CONTEXT}/${DOCKERFILE} \
        ${BUILD_CONTEXT} \
        --push
    
    if [ $? -eq 0 ]; then
        log_success "Multi-platform image built and pushed successfully"
    else
        log_error "Failed to build multi-platform image"
        exit 1
    fi
}

push_image() {
    log_info "Pushing image to GCR..."
    log_info "Target: ${FULL_IMAGE_NAME}"
    
    docker push ${FULL_IMAGE_NAME}
    
    if [ $? -eq 0 ]; then
        log_success "Image pushed successfully"
    else
        log_error "Failed to push image"
        exit 1
    fi
}

show_image_info() {
    log_info "Image information:"
    echo "  Registry: ${GCR_REGISTRY}"
    echo "  Project: ${GCP_PROJECT}"
    echo "  Image: ${IMAGE_NAME}"
    echo "  Tag: ${IMAGE_TAG}"
    echo "  Full name: ${FULL_IMAGE_NAME}"
    echo ""
    
    # Show local image details
    if docker image inspect ${FULL_IMAGE_NAME} &> /dev/null; then
        log_info "Local image details:"
        # Get size in bytes and convert to MB using awk
        local size_bytes=$(docker image inspect ${FULL_IMAGE_NAME} --format '{{.Size}}')
        local size_mb=$(echo "$size_bytes" | awk '{printf "%.2f", $1/1048576}')
        echo "  Size: ${size_bytes} bytes (${size_mb} MB)"
        docker image inspect ${FULL_IMAGE_NAME} --format '  Created: {{.Created}}'
        docker image inspect ${FULL_IMAGE_NAME} --format '  Architecture: {{.Architecture}}'
        docker image inspect ${FULL_IMAGE_NAME} --format '  OS: {{.Os}}'
    fi
}

# ==========================================
# Main Script
# ==========================================

main() {
    echo ""
    log_info "LiteLLM Docker Build & Push Script"
    echo "======================================"
    echo ""
    
    # Parse arguments
    BUILD_ONLY=false
    PUSH_ONLY=false
    MULTI_PLATFORM_BUILD=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --build-only)
                BUILD_ONLY=true
                shift
                ;;
            --push-only)
                PUSH_ONLY=true
                shift
                ;;
            --multi-platform)
                MULTI_PLATFORM_BUILD=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --build-only        Build image only (don't push)"
                echo "  --push-only         Push existing image only (don't build)"
                echo "  --multi-platform    Build for multiple platforms (linux/amd64,linux/arm64)"
                echo "  -h, --help         Show this help message"
                echo ""
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Check prerequisites
    check_prerequisites
    
    # Configure authentication
    if [ "$PUSH_ONLY" = false ]; then
        configure_docker_auth
    fi
    
    # Build image
    if [ "$PUSH_ONLY" = false ]; then
        if [ "$MULTI_PLATFORM_BUILD" = true ]; then
            # Multi-platform build automatically pushes
            build_multi_platform
            show_image_info
            log_success "Complete! Image is available at: ${FULL_IMAGE_NAME}"
            exit 0
        else
            build_image ${DEFAULT_PLATFORM}
        fi
    fi
    
    # Push image
    if [ "$BUILD_ONLY" = false ]; then
        push_image
    fi
    
    # Show image info
    show_image_info
    
    echo ""
    log_success "Complete! Image is available at: ${FULL_IMAGE_NAME}"
    echo ""
    log_info "To pull this image:"
    echo "  docker pull ${FULL_IMAGE_NAME}"
    echo ""
    log_info "To run this image:"
    echo "  docker run -p 4000:4000 ${FULL_IMAGE_NAME}"
    echo ""
}

# Run main function
main "$@"

