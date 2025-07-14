#!/bin/bash

# Vast.ai optimized startup script for Hashtopolis runner
# Handles interruptible instances and provides graceful restart capability

set -euo pipefail

# Configure logging
exec > >(tee -a /tmp/vast-startup.log)
exec 2>&1

echo "$(date): Starting Vast.ai optimized Hashtopolis runner..."

# Environment variables with smart defaults
HT_SERVER="${HT_SERVER:-}"
HT_VOUCHER="${HT_VOUCHER:-}"
WORK_DIR="${WORK_DIR:-/home/hashtopolis-user/htpclient}"
MAX_RETRIES="${MAX_RETRIES:-5}"
RETRY_DELAY="${RETRY_DELAY:-30}"
CONNECTION_TIMEOUT="${CONNECTION_TIMEOUT:-10}"
SETUP_MODE="${SETUP_MODE:-false}"

# Vast.ai optimized defaults
if [[ "${VAST_AI_OPTIMIZED:-true}" == "true" ]]; then
    MAX_RETRIES="${MAX_RETRIES:-10}"  # More retries for vast.ai environment
    RETRY_DELAY="${RETRY_DELAY:-60}"  # Longer delays for stability
fi

# Smart server URL normalization
normalize_server_url() {
    local url="$1"
    
    # Add https:// if no protocol specified
    if [[ ! "$url" =~ ^https?:// ]]; then
        url="https://$url"
    fi
    
    # Remove trailing slash
    url="${url%/}"
    
    # Add API endpoint if not present
    if [[ ! "$url" =~ /api/server\.php$ ]]; then
        if [[ "$url" =~ /api/?$ ]]; then
            url="${url%/api*}/api/server.php"
        else
            url="$url/api/server.php"
        fi
    fi
    
    echo "$url"
}

# Connection validation function
validate_connection() {
    local server_url="$1"
    local timeout="${CONNECTION_TIMEOUT:-10}"
    
    echo "$(date): Validating connection to Hashtopolis server..."
    echo "$(date): Testing URL: $server_url"
    
    # Test basic connectivity
    if ! curl -s --connect-timeout "$timeout" --max-time "$((timeout * 2))" \
         -H "Content-Type: application/json" \
         -X POST \
         -d '{"action":"TEST_CONNECTION","token":"test"}' \
         "$server_url" >/dev/null 2>&1; then
        echo "$(date): WARNING: Cannot connect to Hashtopolis server at $server_url"
        echo "$(date): This might be normal if the server requires authentication"
        return 1
    fi
    
    echo "$(date): ✅ Server is reachable"
    return 0
}

# Setup mode for interactive configuration
interactive_setup() {
    echo "$(date): ========================================="
    echo "$(date): 🚀 Vast.ai Hashtopolis Setup Wizard"
    echo "$(date): ========================================="
    
    if [[ -z "$HT_SERVER" ]]; then
        echo -n "Enter Hashtopolis server URL: "
        read -r HT_SERVER
        export HT_SERVER
    fi
    
    if [[ -z "$HT_VOUCHER" ]]; then
        echo -n "Enter voucher ID: "
        read -r HT_VOUCHER
        export HT_VOUCHER
    fi
    
    echo "$(date): Configuration:"
    echo "$(date):   Server: $HT_SERVER"
    echo "$(date):   Voucher: ${HT_VOUCHER:0:8}..."
    echo "$(date): ========================================="
}

# Handle setup mode
if [[ "$SETUP_MODE" == "true" ]] || [[ "${1:-}" == "--setup" ]]; then
    interactive_setup
fi

# Validate required environment variables
if [[ -z "$HT_SERVER" ]]; then
    echo "$(date): ❌ ERROR: HT_SERVER environment variable is required"
    echo "$(date): Examples:"
    echo "$(date):   -e HT_SERVER=https://your-server.com"
    echo "$(date):   -e HT_SERVER=your-server.com (https:// will be added automatically)"
    echo "$(date): Or run with --setup for interactive configuration"
    exit 1
fi

if [[ -z "$HT_VOUCHER" ]]; then
    echo "$(date): ❌ ERROR: HT_VOUCHER environment variable is required"
    echo "$(date): Get your voucher from: $HT_SERVER/agents.php"
    echo "$(date): Or run with --setup for interactive configuration"
    exit 1
fi

# Normalize server URL
HT_SERVER="$(normalize_server_url "$HT_SERVER")"
echo "$(date): Using server URL: $HT_SERVER"

# Validate connection (non-blocking)
validate_connection "$HT_SERVER" || echo "$(date): Proceeding anyway..."

# Function to handle graceful shutdown
graceful_shutdown() {
    echo "$(date): Received shutdown signal, attempting graceful shutdown..."
    if [[ -n "${HT_PID:-}" ]] && kill -0 "$HT_PID" 2>/dev/null; then
        echo "$(date): Sending SIGTERM to Hashtopolis agent (PID: $HT_PID)"
        kill -TERM "$HT_PID" 2>/dev/null || true
        
        # Wait up to 30 seconds for graceful shutdown
        for i in {1..30}; do
            if ! kill -0 "$HT_PID" 2>/dev/null; then
                echo "$(date): Hashtopolis agent shutdown gracefully"
                break
            fi
            sleep 1
        done
        
        # Force kill if still running
        if kill -0 "$HT_PID" 2>/dev/null; then
            echo "$(date): Force killing Hashtopolis agent"
            kill -KILL "$HT_PID" 2>/dev/null || true
        fi
    fi
    exit 0
}

# Set up signal handlers for graceful shutdown
trap graceful_shutdown SIGTERM SIGINT

# Function to check if hashtopolis.zip exists and download if needed
ensure_hashtopolis_agent() {
    if [[ ! -f "$WORK_DIR/hashtopolis.zip" ]]; then
        echo "$(date): Hashtopolis agent not found, downloading..."
        mkdir -p "$WORK_DIR"
        cd "$WORK_DIR"
        
        # Download latest agent
        if ! curl -L -o hashtopolis.zip "https://github.com/hashtopolis/agent-python/releases/latest/download/hashtopolis.zip"; then
            echo "ERROR: Failed to download Hashtopolis agent"
            return 1
        fi
        
        echo "$(date): Hashtopolis agent downloaded successfully"
    fi
}

# Function to run hashtopolis with retry logic
run_hashtopolis() {
    local retry_count=0
    
    while [[ $retry_count -lt $MAX_RETRIES ]]; do
        echo "$(date): Starting Hashtopolis agent (attempt $((retry_count + 1))/$MAX_RETRIES)..."
        
        # Ensure agent is available
        if ! ensure_hashtopolis_agent; then
            echo "$(date): Failed to ensure Hashtopolis agent is available"
            ((retry_count++))
            sleep "$RETRY_DELAY"
            continue
        fi
        
        cd "$WORK_DIR"
        
        # Start hashtopolis in background and capture PID
        python3 hashtopolis.zip --url "$HT_SERVER" --voucher "$HT_VOUCHER" &
        HT_PID=$!
        
        echo "$(date): Hashtopolis agent started with PID: $HT_PID"
        
        # Wait for the process and handle exit codes
        if wait "$HT_PID"; then
            echo "$(date): Hashtopolis agent completed successfully"
            return 0
        else
            local exit_code=$?
            echo "$(date): Hashtopolis agent exited with code: $exit_code"
            
            # Check if it's a retriable error
            if [[ $exit_code -eq 1 ]] || [[ $exit_code -eq 130 ]] || [[ $exit_code -eq 143 ]]; then
                echo "$(date): Non-retriable exit code, stopping retries"
                return $exit_code
            fi
        fi
        
        ((retry_count++))
        if [[ $retry_count -lt $MAX_RETRIES ]]; then
            echo "$(date): Retrying in $RETRY_DELAY seconds..."
            sleep "$RETRY_DELAY"
        fi
    done
    
    echo "$(date): Max retries reached, giving up"
    return 1
}

# Function to check vast.ai specific environment
check_vast_environment() {
    echo "$(date): Checking Vast.ai environment..."
    
    # Check GPU availability
    if command -v nvidia-smi >/dev/null 2>&1; then
        echo "$(date): GPU information:"
        nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader,nounits
    else
        echo "$(date): WARNING: nvidia-smi not available"
    fi
    
    # Log vast.ai specific environment variables
    for var in CONTAINER_ID PUBLIC_IPADDR GPU_COUNT CONTAINER_API_KEY; do
        if [[ -n "${!var:-}" ]]; then
            echo "$(date): $var is set"
        fi
    done
    
    # Check disk space
    echo "$(date): Disk usage:"
    df -h /
}

# Main execution
main() {
    echo "$(date): Vast.ai Hashtopolis Runner v0.4.0 starting..."
    
    # Check environment
    check_vast_environment
    
    # Create work directory if it doesn't exist
    mkdir -p "$WORK_DIR"
    chown -R hashtopolis-user:hashtopolis-user "$WORK_DIR" 2>/dev/null || true
    
    # Switch to hashtopolis user if running as root
    if [[ $EUID -eq 0 ]]; then
        echo "$(date): Switching to hashtopolis-user..."
        exec su - hashtopolis-user -c "HT_SERVER='$HT_SERVER' HT_VOUCHER='$HT_VOUCHER' WORK_DIR='$WORK_DIR' MAX_RETRIES='$MAX_RETRIES' RETRY_DELAY='$RETRY_DELAY' $0"
    fi
    
    # Run hashtopolis
    run_hashtopolis
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi