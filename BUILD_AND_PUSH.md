# Manual Build and Push Guide

This guide explains how to manually build and push the vast-hashtopolis-runner Docker image.

## Prerequisites

1. Docker installed and running
2. Docker Buildx (for multi-architecture builds)
3. Authentication tokens for registries you want to push to

## Setting Up Authentication

### GitHub Container Registry (GHCR)

1. Create a GitHub Personal Access Token:
   - Go to https://github.com/settings/tokens
   - Click "Generate new token (classic)"
   - Select scopes: `read:packages`, `write:packages`, `delete:packages`
   - Copy the token

2. Set environment variables:
   ```bash
   export GITHUB_USER=your-github-username
   export GITHUB_TOKEN=your-github-token
   ```

### Docker Hub

1. Create a Docker Hub Access Token:
   - Go to https://hub.docker.com/settings/security
   - Click "New Access Token"
   - Give it a name and appropriate permissions
   - Copy the token

2. Set environment variables:
   ```bash
   export DOCKERHUB_USER=your-dockerhub-username
   export DOCKERHUB_TOKEN=your-dockerhub-token
   ```

## Using the Build Script

The `scripts/build-and-push.sh` script handles building and pushing to multiple registries.

### Basic Usage

```bash
# Build and push to GitHub Container Registry
./scripts/build-and-push.sh --ghcr

# Build and push to Docker Hub
./scripts/build-and-push.sh --dockerhub

# Build and push to both registries
./scripts/build-and-push.sh --ghcr --dockerhub

# Build with version tag
./scripts/build-and-push.sh --ghcr --dockerhub --version 1.0.0

# Multi-architecture build (amd64 + arm64)
./scripts/build-and-push.sh --ghcr --dockerhub --multi-arch

# Dry run to see what would happen
./scripts/build-and-push.sh --ghcr --dockerhub --dry-run
```

### Script Options

- `-g, --ghcr`: Push to GitHub Container Registry
- `-d, --dockerhub`: Push to Docker Hub
- `-m, --multi-arch`: Build for multiple architectures (amd64 and arm64)
- `-v, --version VERSION`: Set version tag (e.g., 1.0.0)
- `-n, --dry-run`: Show what would be done without actually doing it
- `-h, --help`: Show help message

## Manual Build Commands

If you prefer to run Docker commands directly:

### Local Build

```bash
# Build for local testing
docker build -t vast-hashtopolis-runner:local .
```

### Build and Push to GHCR

```bash
# Login to GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u $GITHUB_USER --password-stdin

# Build and tag
docker build -t ghcr.io/$GITHUB_USER/vast-hashtopolis-runner:latest .

# Push
docker push ghcr.io/$GITHUB_USER/vast-hashtopolis-runner:latest
```

### Build and Push to Docker Hub

```bash
# Login to Docker Hub
echo $DOCKERHUB_TOKEN | docker login -u $DOCKERHUB_USER --password-stdin

# Build and tag
docker build -t $DOCKERHUB_USER/vast-hashtopolis-runner:latest .

# Push
docker push $DOCKERHUB_USER/vast-hashtopolis-runner:latest
```

### Multi-Architecture Build

```bash
# Create buildx builder
docker buildx create --name vast-builder --use

# Build and push multi-arch image
docker buildx build --platform linux/amd64,linux/arm64 \
  -t ghcr.io/$GITHUB_USER/vast-hashtopolis-runner:latest \
  -t $DOCKERHUB_USER/vast-hashtopolis-runner:latest \
  --push .
```

## Verifying the Build

After building, you can verify hashcat is properly installed:

```bash
# Run container and check hashcat
docker run --rm --gpus all vast-hashtopolis-runner:local hashcat -I

# This should show your NVIDIA GPU devices
```

## Troubleshooting

### Build Fails

- Ensure you have enough disk space
- Check Docker daemon is running
- For multi-arch builds, ensure buildx is installed

### Push Fails

- Verify your authentication tokens are valid
- Check you have push permissions to the repository
- Ensure the repository exists on the registry

### GPU Not Detected

- Ensure NVIDIA Container Toolkit is installed on host
- Use `--gpus all` flag when running container
- Check CUDA version compatibility