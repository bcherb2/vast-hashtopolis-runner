#!/bin/bash

# Vast.ai Hashtopolis Setup Wizard
# Interactive configuration generator for easy deployment

set -euo pipefail

# Compatible with older bash versions

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Emojis for better UX
ROCKET="🚀"
CHECK="✅"
WARNING="⚠️"
ERROR="❌"
INFO="ℹ️"
GEAR="⚙️"

print_banner() {
    echo -e "${CYAN}"
    echo "  ╔══════════════════════════════════════════════════════════════╗"
    echo "  ║                    ${ROCKET} VAST.AI HASHTOPOLIS RUNNER ${ROCKET}                   ║"
    echo "  ║                         Setup Wizard v0.4.0                  ║"
    echo "  ╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "${BLUE}${INFO} $1${NC}"
}

print_success() {
    echo -e "${GREEN}${CHECK} $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}${WARNING} $1${NC}"
}

print_error() {
    echo -e "${RED}${ERROR} $1${NC}"
}

print_info() {
    echo -e "${PURPLE}${GEAR} $1${NC}"
}

# Configuration variables
HT_SERVER=""
HT_VOUCHER=""
INSTANCE_TYPE=""
BUDGET=""
DOCKER_IMAGE="ghcr.io/bcherb2/vast-hashtopolis-runner:latest"

# Instance type configurations
get_instance_config() {
    case "$1" in
        "budget") echo "reliability>0.95 dph_total<0.30 gpu_ram>=4000" ;;
        "balanced") echo "reliability>0.98 dph_total<0.60 gpu_ram>=8000" ;;
        "performance") echo "reliability>0.99 dph_total<1.50 gpu_ram>=16000" ;;
        "spot") echo "reliability>0.90 dph_total<0.25 gpu_ram>=4000 interruptible=true" ;;
        *) echo "" ;;
    esac
}

get_instance_description() {
    case "$1" in
        "budget") echo "Budget-friendly instances under \$0.30/hr with 4GB+ VRAM" ;;
        "balanced") echo "Balanced performance/cost under \$0.60/hr with 8GB+ VRAM" ;;
        "performance") echo "High-performance instances under \$1.50/hr with 16GB+ VRAM" ;;
        "spot") echo "Cheapest interruptible instances under \$0.25/hr (may be stopped)" ;;
        *) echo "Unknown instance type" ;;
    esac
}

normalize_url() {
    local url="$1"
    
    # Add https:// if no protocol specified
    if [[ ! "$url" =~ ^https?:// ]]; then
        url="https://$url"
    fi
    
    # Remove trailing slash and /api/server.php if present
    url="${url%/}"
    url="${url%/api/server.php}"
    url="${url%/api}"
    
    echo "$url"
}

validate_server() {
    local server_url="$1"
    local test_url="${server_url}/api/server.php"
    
    print_step "Testing connection to $test_url..."
    
    if curl -s --connect-timeout 10 --max-time 20 \
       -H "Content-Type: application/json" \
       -X POST \
       -d '{"action":"TEST_CONNECTION","token":"test"}' \
       "$test_url" >/dev/null 2>&1; then
        print_success "Server is reachable!"
        return 0
    else
        print_warning "Cannot reach server (this might be normal if authentication is required)"
        return 1
    fi
}

collect_server_info() {
    print_step "Setting up Hashtopolis server connection..."
    echo
    
    while [[ -z "$HT_SERVER" ]]; do
        echo -n "Enter your Hashtopolis server URL: "
        read -r server_input
        
        if [[ -n "$server_input" ]]; then
            HT_SERVER=$(normalize_url "$server_input")
            echo "Normalized URL: $HT_SERVER"
            
            # Validate server connection
            validate_server "$HT_SERVER"
            
            echo -n "Use this server? (y/n): "
            read -r confirm
            if [[ "$confirm" =~ ^[Yy] ]]; then
                break
            else
                HT_SERVER=""
            fi
        else
            print_error "Server URL cannot be empty"
        fi
    done
    
    while [[ -z "$HT_VOUCHER" ]]; do
        echo
        print_info "Get your voucher from: $HT_SERVER/agents.php"
        echo -n "Enter your voucher ID: "
        read -r HT_VOUCHER
        
        if [[ -z "$HT_VOUCHER" ]]; then
            print_error "Voucher ID cannot be empty"
        fi
    done
    
    print_success "Server configuration completed!"
}

select_instance_type() {
    print_step "Selecting instance type..."
    echo
    
    echo "Available instance types:"
    echo
    for key in budget balanced performance spot; do
        echo -e "${CYAN}$key${NC}: $(get_instance_description "$key")"
    done
    echo
    
    while [[ -z "$INSTANCE_TYPE" ]]; do
        echo -n "Select instance type (budget/balanced/performance/spot): "
        read -r instance_input
        
        if [[ -n "$(get_instance_config "$instance_input")" ]]; then
            INSTANCE_TYPE="$instance_input"
            print_success "Selected: $INSTANCE_TYPE"
        else
            print_error "Invalid instance type. Choose from: budget, balanced, performance, spot"
        fi
    done
}

generate_vast_url() {
    local base_url="https://vast.ai/console/create"
    local image_param="image=${DOCKER_IMAGE}"
    local env_params="env=HT_SERVER%3D$(printf '%s' "$HT_SERVER" | jq -sRr @uri)%26HT_VOUCHER%3D$(printf '%s' "$HT_VOUCHER" | jq -sRr @uri)"
    
    # Add instance type specific search parameters
    local search_params=""
    local instance_config
    instance_config=$(get_instance_config "$INSTANCE_TYPE")
    if [[ -n "$instance_config" ]]; then
        search_params="&search=$(printf '%s' "$instance_config" | jq -sRr @uri)"
    fi
    
    echo "${base_url}?${image_param}&${env_params}${search_params}"
}

generate_docker_command() {
    echo "docker run -d --gpus all \\"
    echo "  -e HT_SERVER=\"$HT_SERVER\" \\"
    echo "  -e HT_VOUCHER=\"$HT_VOUCHER\" \\"
    echo "  -e MAX_RETRIES=10 \\"
    echo "  -e RETRY_DELAY=60 \\"
    echo "  $DOCKER_IMAGE"
}

generate_vast_template() {
    cat << EOF
{
  "name": "Hashtopolis Runner - $INSTANCE_TYPE",
  "image": "$DOCKER_IMAGE",
  "env": {
    "HT_SERVER": "$HT_SERVER",
    "HT_VOUCHER": "$HT_VOUCHER",
    "MAX_RETRIES": "10",
    "RETRY_DELAY": "60"
  },
  "search_criteria": "$(get_instance_config "$INSTANCE_TYPE")",
  "description": "$(get_instance_description "$INSTANCE_TYPE")"
}
EOF
}

show_results() {
    print_step "Configuration complete! Here are your deployment options:"
    echo
    
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}📋 CONFIGURATION SUMMARY${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo "Server URL: $HT_SERVER"
    echo "Voucher: ${HT_VOUCHER:0:8}..."
    echo "Instance Type: $INSTANCE_TYPE"
    echo "Description: $(get_instance_description "$INSTANCE_TYPE")"
    echo
    
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}🚀 VAST.AI ONE-CLICK DEPLOYMENT${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo "Click this link to deploy instantly on Vast.ai:"
    echo
    echo -e "${YELLOW}$(generate_vast_url)${NC}"
    echo
    
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}⚙️ MANUAL VAST.AI CONFIGURATION${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo "If the one-click link doesn't work, use these settings:"
    echo
    echo "Image: $DOCKER_IMAGE"
    echo "Environment Variables:"
    echo "  -e HT_SERVER=$HT_SERVER"
    echo "  -e HT_VOUCHER=$HT_VOUCHER"
    echo "  -e MAX_RETRIES=10"
    echo "  -e RETRY_DELAY=60"
    echo
    echo "Search filters: $(get_instance_config "$INSTANCE_TYPE")"
    echo
    
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}🐳 LOCAL DOCKER COMMAND${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo "For local testing:"
    echo
    generate_docker_command
    echo
    
    if command -v jq >/dev/null 2>&1; then
        echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}📄 TEMPLATE JSON${NC}"
        echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
        generate_vast_template
        echo
    fi
    
    print_success "Setup complete! Happy hash cracking! 🔐"
}

save_config() {
    local config_file="vast-hashtopolis-config.sh"
    
    cat > "$config_file" << EOF
#!/bin/bash
# Generated by Vast.ai Hashtopolis Setup Wizard
# $(date)

export HT_SERVER="$HT_SERVER"
export HT_VOUCHER="$HT_VOUCHER"
export INSTANCE_TYPE="$INSTANCE_TYPE"
export DOCKER_IMAGE="$DOCKER_IMAGE"

# To use this config:
# source $config_file
# /usr/local/bin/vast-startup.sh
EOF
    
    chmod +x "$config_file"
    print_success "Configuration saved to $config_file"
}

main() {
    print_banner
    echo
    print_step "Welcome to the Vast.ai Hashtopolis Runner setup wizard!"
    print_info "This wizard will help you configure and deploy Hashtopolis agents on Vast.ai"
    echo
    
    collect_server_info
    echo
    
    select_instance_type
    echo
    
    show_results
    echo
    
    echo -n "Save configuration to file? (y/n): "
    read -r save_confirm
    if [[ "$save_confirm" =~ ^[Yy] ]]; then
        save_config
    fi
    
    echo
    print_success "All done! 🎉"
}

# Handle command line arguments
case "${1:-}" in
    "--help"|"-h")
        echo "Vast.ai Hashtopolis Setup Wizard"
        echo "Usage: $0 [--help]"
        echo
        echo "This interactive wizard helps you configure Hashtopolis agents for Vast.ai deployment."
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac