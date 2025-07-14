# Vast.ai Hashtopolis Runner

A modern, optimized Docker container for running Hashtopolis agents on [Vast.ai](https://vast.ai/) cloud GPU instances. This container is specifically designed for interruptible instances and provides automatic retry logic, graceful shutdown handling, and enhanced vast.ai compatibility.

## 🚀 Features

- **Latest CUDA 12.8.0 Runtime**: Optimized for modern GPUs without development bloat
- **Vast.ai Optimized**: Built specifically for vast.ai's container environment
- **Interruptible Instance Support**: Handles instance interruptions gracefully with automatic restart
- **Multi-Architecture**: Supports both AMD64 and ARM64 platforms
- **Auto-retry Logic**: Robust error handling and automatic reconnection
- **Graceful Shutdown**: Proper signal handling for clean container stops
- **Multi-Registry Publishing**: Available on both GitHub Container Registry and DockerHub

## 📦 Container Images

The container is published to multiple registries for maximum availability:

- **GitHub Container Registry**: `ghcr.io/bcherb2/vast-hashtopolis-runner:latest`
- **DockerHub**: `bcherb2/vast-hashtopolis-runner:latest` *(coming soon)*

**Available Tags:**
- `latest` - Latest stable release
- `v0.4.0` - Specific version tags
- `main` - Latest development build

## 🚀 Quick Start on Vast.ai

### 🎯 One-Click Deployment (Easiest!)

Choose your deployment template and get started instantly:

#### **🧙‍♂️ Setup Wizard** (Recommended for beginners)

The interactive setup wizard guides you through the entire configuration process:

```bash
# Run the interactive setup wizard
docker run -it --rm ghcr.io/bcherb2/vast-hashtopolis-runner:latest /usr/local/bin/setup-wizard.sh
```

**What the wizard does:**
- ✅ Validates your Hashtopolis server connection
- ✅ Tests server reachability and API endpoints
- ✅ Generates one-click deployment URLs
- ✅ Creates Docker commands for local testing
- ✅ Saves configuration for future use
- ✅ Provides manual vast.ai setup instructions

#### **Budget Template** - Under $0.30/hr
**Perfect for: Basic hash cracking, testing, learning**
- GPUs: GTX 1660, RTX 3060, GTX 1070
- VRAM: 4GB+
- Reliability: 95%+

[🔗 **Deploy Budget Template**](https://vast.ai/console/create?image=ghcr.io/bcherb2/vast-hashtopolis-runner:latest&search=reliability%3E0.95%20dph_total%3C0.30%20gpu_ram%3E%3D4000)

#### **Balanced Template** - Under $0.60/hr  
**Perfect for: Most hash cracking scenarios, good performance/cost ratio**
- GPUs: RTX 3070, RTX 3080, RTX 4070
- VRAM: 8GB+
- Reliability: 98%+

[🔗 **Deploy Balanced Template**](https://vast.ai/console/create?image=ghcr.io/bcherb2/vast-hashtopolis-runner:latest&search=reliability%3E0.98%20dph_total%3C0.60%20gpu_ram%3E%3D8000)

#### **Performance Template** - Under $1.50/hr
**Perfect for: Intensive workloads, large hashfiles, time-critical tasks**
- GPUs: RTX 4090, RTX 3090, A100, RTX A6000
- VRAM: 16GB+
- Reliability: 99%+

[🔗 **Deploy Performance Template**](https://vast.ai/console/create?image=ghcr.io/bcherb2/vast-hashtopolis-runner:latest&search=reliability%3E0.99%20dph_total%3C1.50%20gpu_ram%3E%3D16000)

#### **Spot/Interruptible Template** - Under $0.25/hr (Save 50%+)
**Perfect for: Long-running tasks, maximum cost savings, fault-tolerant workloads**
- GPUs: Any available GPU
- VRAM: 4GB+
- Note: ⚠️ May be interrupted but will auto-restart

[🔗 **Deploy Spot Template**](https://vast.ai/console/create?image=ghcr.io/bcherb2/vast-hashtopolis-runner:latest&search=reliability%3E0.90%20dph_total%3C0.25%20gpu_ram%3E%3D4000%20interruptible%3Dtrue)

### ⚙️ Manual Configuration

If you prefer manual setup or the one-click links need customization:

**Image**: `ghcr.io/bcherb2/vast-hashtopolis-runner:latest`

**Required Environment Variables:**
```
-e HT_SERVER=https://your-hashtopolis-server.com
-e HT_VOUCHER=your_voucher_id_here
```

**Recommended Environment Variables:**
```
-e MAX_RETRIES=10
-e RETRY_DELAY=60
-e CONNECTION_TIMEOUT=15
```

### 🛠️ Template-Based Deployment

Use our deployment script for advanced configuration:

```bash
# Generate deployment configurations
./scripts/deploy-template.sh budget --server https://my-server.com --voucher abc123

# Options:
./scripts/deploy-template.sh performance --output docker
./scripts/deploy-template.sh spot --output env
./scripts/deploy-template.sh balanced --output json
```

## 🔧 Development & Building

### Requirements

- Docker CLI
- Container engine (Docker Desktop, Colima, etc.)
- GNU Make and GNU utils

### Local Build

```bash
# Basic build
make

# Verbose build
make VERBOSE=y

# Build with custom Docker args
make VERBOSE=y EXTRA_DOCKER_ARGS="--no-cache"

# Build and publish (requires registry access)
make PUBLISH=y
```

### Multi-Architecture Build

The GitHub Actions workflow automatically builds for both `linux/amd64` and `linux/arm64` platforms.

## 🏗️ Architecture

### Container Structure

```
/usr/local/bin/vast-startup.sh    # Main startup script with retry logic
/home/hashtopolis-user/htpclient/ # Working directory for Hashtopolis agent
/tmp/vast-startup.log             # Startup and runtime logs
```

### Key Features

1. **🔄 Automatic Agent Download**: Downloads the latest Hashtopolis agent if not present
2. **🛡️ Signal Handling**: Properly handles SIGTERM and SIGINT for graceful shutdown
3. **📊 Health Monitoring**: Logs GPU information and environment status
4. **👤 User Management**: Runs as non-root user for security
5. **☁️ Vast.ai Integration**: Optimized for vast.ai's container environment
6. **🔗 Smart URL Handling**: Automatically normalizes server URLs and adds API endpoints
7. **✅ Connection Validation**: Tests server connectivity before starting agent
8. **🎯 Smart Defaults**: Automatically optimizes settings for vast.ai environment
9. **🔄 Enhanced Retry Logic**: Configurable retry attempts with exponential backoff
10. **📝 Comprehensive Logging**: Detailed startup and runtime logs with timestamps

## 🔐 Hashtopolis Server Configuration

### Required Settings

1. **Enable Reusable Vouchers**: 
   - Go to `https://your-server.com/config.php?view=5`
   - Check "Allow vouchers to be used multiple times"

2. **Whitelist OpenCL Error** (if using vast.ai):
   - Go to Server Settings → `config.php`
   - Add to error whitelist: `clGetPlatformIDs(): CL_PLATFORM_NOT_FOUND_KHR`

3. **Auto-Trust Agents** (optional):
   ```bash
   # Create auto-trust script
   echo 'mysql -D your_hashtopolis_db -e "UPDATE Agent SET isTrusted = '\''1'\''"' > set_trust.sh
   chmod +x set_trust.sh
   
   # Add to crontab
   echo '* * * * * /path/to/set_trust.sh >/dev/null 2>&1' | crontab -
   ```

## 🐛 Troubleshooting

### Common Issues

1. **Agent Won't Connect**:
   - Verify `HT_SERVER` URL is accessible
   - Check voucher ID is valid and reusable
   - Ensure Hashtopolis server allows new agents

2. **GPU Not Detected**:
   - Confirm vast.ai instance has GPU allocated
   - Check NVIDIA drivers are available: `nvidia-smi`

3. **Container Keeps Restarting**:
   - Check environment variables are set correctly
   - Review logs: `docker logs <container_id>`
   - Verify Hashtopolis server is accessible

### Logs and Debugging

```bash
# View startup logs
docker exec <container_id> cat /tmp/vast-startup.log

# Check GPU status
docker exec <container_id> nvidia-smi

# Monitor container logs
docker logs -f <container_id>
```

## 🌟 Advanced Usage

### Running with Custom Parameters

```bash
# With custom hashcat parameters via Hashtopolis task configuration
# Add to task command line: --workload-profile 4 --optimized-kernel-enable
```

### Using with Screen/Tmux

The container includes `screen` and `tmux` for session management:

```bash
# Start in screen session
screen -S hashtopolis /usr/local/bin/vast-startup.sh

# Start in tmux session  
tmux new-session -d -s hashtopolis /usr/local/bin/vast-startup.sh
```

## 📊 Performance Optimization

### For Interruptible Instances

- Set `MAX_RETRIES=10` for more persistent reconnection
- Use `RETRY_DELAY=60` for longer delays between retries
- Monitor logs for connection patterns

### For High-Performance Tasks

- Use vast.ai instances with sufficient VRAM
- Configure Hashtopolis tasks with appropriate workload profiles
- Monitor GPU utilization: `watch -n 1 nvidia-smi`

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with vast.ai instances
5. Submit a pull request

### Development Workflow

```bash
# Make changes to Dockerfile or scripts
edit Dockerfile

# Test build locally
make

# Test on vast.ai
# (Deploy to vast.ai with your changes)

# Commit and push
git add .
git commit -m "feat: your improvement"
git push origin feature-branch
```

## 📜 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Original work by [Milz0](https://github.com/Milz0/hashtopolis-hashcat-vast)
- Fork by [Tjenaaaa](https://github.com/Tjenaaaa/hashtopolis-hashcat-vast)
- [Hashtopolis Project](https://github.com/hashtopolis/hashtopolis)
- [Vast.ai](https://vast.ai/) for cloud GPU infrastructure

## 📺 Demo

For a visual demonstration of the setup process, see the original demo video:

[![Demo](https://img.youtube.com/vi/A1QrUVy7UZ0/0.jpg)](https://www.youtube.com/watch?v=A1QrUVy7UZ0 "Hashtopolis Vast.ai Demo")

---

**Version**: 0.4.0  
**CUDA Version**: 12.8.0  
**Base Image**: `nvidia/cuda:12.8.0-runtime-ubuntu22.04`
