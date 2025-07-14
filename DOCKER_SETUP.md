# Docker Registry Setup

This document explains how to set up Docker registry publishing for both GitHub Container Registry and DockerHub.

## GitHub Container Registry (Already Configured)

The repository is already configured to publish to GitHub Container Registry using the built-in `GITHUB_TOKEN`.

**Image URL**: `ghcr.io/bcherb2/vast-hashtopolis-runner:latest`

## DockerHub Setup (Optional)

To enable DockerHub publishing, you need to add repository secrets:

### Required Secrets

1. **DOCKERHUB_USERNAME**: Your DockerHub username
2. **DOCKERHUB_TOKEN**: DockerHub access token (not password)

### Setting Up DockerHub Secrets

1. Go to your repository on GitHub
2. Navigate to Settings → Secrets and variables → Actions
3. Click "New repository secret"
4. Add the following secrets:

#### DOCKERHUB_USERNAME
- Name: `DOCKERHUB_USERNAME`
- Secret: Your DockerHub username (e.g., `bcherb2`)

#### DOCKERHUB_TOKEN
- Name: `DOCKERHUB_TOKEN`
- Secret: Your DockerHub access token

### Creating a DockerHub Access Token

1. Log in to [hub.docker.com](https://hub.docker.com)
2. Go to Account Settings → Security
3. Click "New Access Token"
4. Give it a descriptive name (e.g., "GitHub Actions - vast-hashtopolis-runner")
5. Select appropriate permissions (Read, Write, Delete)
6. Copy the generated token (you won't see it again)
7. Use this token as the `DOCKERHUB_TOKEN` secret

### Repository Setup

Create a repository on DockerHub:
1. Go to [hub.docker.com](https://hub.docker.com)
2. Click "Create Repository"
3. Name: `vast-hashtopolis-runner`
4. Description: "Vast.ai optimized Hashtopolis agent runner with interruptible instance support"
5. Set to Public
6. Click "Create"

## Workflow Behavior

### With DockerHub Secrets Configured
- Publishes to both GHCR and DockerHub
- Multi-platform builds (AMD64 + ARM64)
- Automatic versioning with tags

### Without DockerHub Secrets
- Publishes only to GitHub Container Registry
- Workflow will fail on DockerHub login step

## Testing

### Local Testing
```bash
# Build locally
make

# Test the image
docker run --rm vast-hashtopolis-runner:test /usr/local/bin/setup-wizard.sh --help
```

### Production Build
```bash
# Build and tag for production
docker build -t ghcr.io/bcherb2/vast-hashtopolis-runner:latest .

# Test production image
docker run --rm ghcr.io/bcherb2/vast-hashtopolis-runner:latest /usr/local/bin/setup-wizard.sh --help
```

## Image Sizes

- Base CUDA runtime: ~5.5GB
- Final image: ~8.4GB
- Includes all tools needed for vast.ai deployment

## Registry URLs


- **GitHub Container Registry**: `ghcr.io/bcherb2/vast-hashtopolis-runner:latest`
- **DockerHub** (when configured): `bcherb2/vast-hashtopolis-runner:latest`