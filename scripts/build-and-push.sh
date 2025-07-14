#!/usr/bin/env bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEFAULT_PLATFORMS="linux/amd64"
GHCR_REPO="ghcr.io"
DOCKERHUB_REPO="docker.io"
IMAGE_NAME="vast-hashtopolis-runner"
VERSION=""
PUSH_GHCR=false
PUSH_DOCKERHUB=false
MULTI_ARCH=false
DRY_RUN=false

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} ✓ $*"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} ⚠ $*"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} ✗ $*"
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Build and push vast-hashtopolis-runner Docker image to GitHub Container Registry and/or Docker Hub.

OPTIONS:
    -g, --ghcr              Push to GitHub Container Registry
    -d, --dockerhub         Push to Docker Hub
    -m, --multi-arch        Build for multiple architectures (amd64 and arm64)
    -v, --version VERSION   Set version tag (e.g., 1.0.0)
    -n, --dry-run          Show what would be done without actually doing it
    -h, --help             Show this help message

ENVIRONMENT VARIABLES:
    GITHUB_USER             GitHub username (required for GHCR)
    GITHUB_TOKEN            GitHub personal access token (required for GHCR)
    DOCKERHUB_USER          Docker Hub username (required for Docker Hub)
    DOCKERHUB_TOKEN         Docker Hub access token (required for Docker Hub)

EXAMPLES:
    # Build and push to GHCR only
    $0 --ghcr

    # Build and push to both registries with version
    $0 --ghcr --dockerhub --version 1.0.0

    # Multi-arch build to Docker Hub
    $0 --dockerhub --multi-arch

    # Dry run to see what would happen
    $0 --ghcr --dockerhub --multi-arch --dry-run

EOF
    exit 1
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
        exit 1
    fi
}

check_buildx() {
    if ! docker buildx version &> /dev/null; then
        log_error "Docker Buildx is required for multi-arch builds"
        log_error "Install it with: docker buildx install"
        exit 1
    fi
    
    # Create and use a new builder instance for multi-arch
    if [[ "$DRY_RUN" == false ]]; then
        if ! docker buildx inspect vast-builder &> /dev/null; then
            log "Creating buildx builder instance..."
            docker buildx create --name vast-builder --use
        else
            docker buildx use vast-builder
        fi
    fi
}

check_ghcr_auth() {
    if [[ -z "${GITHUB_USER:-}" ]]; then
        log_error "GITHUB_USER environment variable is not set"
        log_error "Export it with: export GITHUB_USER=your-github-username"
        return 1
    fi
    
    if [[ -z "${GITHUB_TOKEN:-}" ]]; then
        log_error "GITHUB_TOKEN environment variable is not set"
        log_error "Create a token at: https://github.com/settings/tokens"
        log_error "Export it with: export GITHUB_TOKEN=your-token"
        return 1
    fi
    
    log "Logging into GitHub Container Registry..."
    if [[ "$DRY_RUN" == false ]]; then
        echo "${GITHUB_TOKEN}" | docker login "${GHCR_REPO}" -u "${GITHUB_USER}" --password-stdin
    else
        log "Would login to GHCR as ${GITHUB_USER}"
    fi
}

check_dockerhub_auth() {
    if [[ -z "${DOCKERHUB_USER:-}" ]]; then
        log_error "DOCKERHUB_USER environment variable is not set"
        log_error "Export it with: export DOCKERHUB_USER=your-dockerhub-username"
        return 1
    fi
    
    if [[ -z "${DOCKERHUB_TOKEN:-}" ]]; then
        log_error "DOCKERHUB_TOKEN environment variable is not set"
        log_error "Create a token at: https://hub.docker.com/settings/security"
        log_error "Export it with: export DOCKERHUB_TOKEN=your-token"
        return 1
    fi
    
    log "Logging into Docker Hub..."
    if [[ "$DRY_RUN" == false ]]; then
        echo "${DOCKERHUB_TOKEN}" | docker login -u "${DOCKERHUB_USER}" --password-stdin
    else
        log "Would login to Docker Hub as ${DOCKERHUB_USER}"
    fi
}

build_image() {
    local tags=""
    local platforms=""
    local build_cmd=""
    
    # Set platforms
    if [[ "$MULTI_ARCH" == true ]]; then
        platforms="--platform linux/amd64,linux/arm64"
        check_buildx
    fi
    
    # Build tag list
    if [[ "$PUSH_GHCR" == true ]]; then
        tags="${tags} -t ${GHCR_REPO}/${GITHUB_USER}/${IMAGE_NAME}:latest"
        if [[ -n "$VERSION" ]]; then
            tags="${tags} -t ${GHCR_REPO}/${GITHUB_USER}/${IMAGE_NAME}:v${VERSION}"
        fi
    fi
    
    if [[ "$PUSH_DOCKERHUB" == true ]]; then
        tags="${tags} -t ${DOCKERHUB_USER}/${IMAGE_NAME}:latest"
        if [[ -n "$VERSION" ]]; then
            tags="${tags} -t ${DOCKERHUB_USER}/${IMAGE_NAME}:v${VERSION}"
        fi
    fi
    
    # If no push targets, just build locally
    if [[ -z "$tags" ]]; then
        tags="-t ${IMAGE_NAME}:local"
        log_warning "No push targets specified, building local image only"
    fi
    
    # Construct build command
    if [[ "$MULTI_ARCH" == true ]]; then
        # Multi-arch requires buildx
        build_cmd="docker buildx build ${platforms} ${tags}"
        if [[ "$PUSH_GHCR" == true || "$PUSH_DOCKERHUB" == true ]]; then
            build_cmd="${build_cmd} --push"
        fi
    else
        # Single arch can use regular build
        build_cmd="docker build ${tags}"
    fi
    
    build_cmd="${build_cmd} ."
    
    log "Building Docker image..."
    log "Command: ${build_cmd}"
    
    if [[ "$DRY_RUN" == false ]]; then
        eval "${build_cmd}"
        log_success "Image built successfully"
    else
        log "Would execute: ${build_cmd}"
    fi
    
    # For single-arch builds, push separately
    if [[ "$MULTI_ARCH" == false && "$DRY_RUN" == false ]]; then
        if [[ "$PUSH_GHCR" == true ]]; then
            log "Pushing to GitHub Container Registry..."
            docker push "${GHCR_REPO}/${GITHUB_USER}/${IMAGE_NAME}:latest"
            if [[ -n "$VERSION" ]]; then
                docker push "${GHCR_REPO}/${GITHUB_USER}/${IMAGE_NAME}:v${VERSION}"
            fi
            log_success "Pushed to GHCR"
        fi
        
        if [[ "$PUSH_DOCKERHUB" == true ]]; then
            log "Pushing to Docker Hub..."
            docker push "${DOCKERHUB_USER}/${IMAGE_NAME}:latest"
            if [[ -n "$VERSION" ]]; then
                docker push "${DOCKERHUB_USER}/${IMAGE_NAME}:v${VERSION}"
            fi
            log_success "Pushed to Docker Hub"
        fi
    fi
}

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -g|--ghcr)
                PUSH_GHCR=true
                shift
                ;;
            -d|--dockerhub)
                PUSH_DOCKERHUB=true
                shift
                ;;
            -m|--multi-arch)
                MULTI_ARCH=true
                shift
                ;;
            -v|--version)
                VERSION="$2"
                shift 2
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done
    
    # Check Docker
    check_docker
    
    # Authenticate if needed
    if [[ "$PUSH_GHCR" == true ]]; then
        check_ghcr_auth || exit 1
    fi
    
    if [[ "$PUSH_DOCKERHUB" == true ]]; then
        check_dockerhub_auth || exit 1
    fi
    
    # Build and push
    build_image
    
    log_success "Build and push completed successfully!"
    
    # Show image locations
    echo
    log "Images available at:"
    if [[ "$PUSH_GHCR" == true ]]; then
        log "  GitHub: ${GHCR_REPO}/${GITHUB_USER}/${IMAGE_NAME}:latest"
        if [[ -n "$VERSION" ]]; then
            log "          ${GHCR_REPO}/${GITHUB_USER}/${IMAGE_NAME}:v${VERSION}"
        fi
    fi
    if [[ "$PUSH_DOCKERHUB" == true ]]; then
        log "  Docker Hub: ${DOCKERHUB_USER}/${IMAGE_NAME}:latest"
        if [[ -n "$VERSION" ]]; then
            log "              ${DOCKERHUB_USER}/${IMAGE_NAME}:v${VERSION}"
        fi
    fi
}

main "$@"