#!/bin/bash

# Template-based deployment script for Vast.ai Hashtopolis Runner
# Generates deployment configurations from predefined templates

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$(dirname "$SCRIPT_DIR")/templates"

print_usage() {
    echo "Usage: ${0} <template> [options]"
    echo
    echo "Templates:"
    echo "  budget      - Budget-friendly instances under \$0.30/hr"
    echo "  balanced    - Balanced performance/cost under \$0.60/hr"  
    echo "  performance - High-performance instances under \$1.50/hr"
    echo "  spot        - Ultra-cheap interruptible instances under \$0.25/hr"
    echo
    echo "Options:"
    echo "  --server URL         Hashtopolis server URL"
    echo "  --voucher ID         Hashtopolis voucher ID"
    echo "  --output FORMAT      Output format (url|docker|json|env)"
    echo "  --help               Show this help"
    echo
    echo "Examples:"
    echo "  \${0} budget --server https://my-server.com --voucher abc123"
    echo "  \${0} performance --server my-server.com --voucher xyz789 --output url"
    echo "  \${0} spot --output docker"
}

print_templates() {
    echo -e "${CYAN}Available Templates:${NC}"
    echo
    
    for template_file in "$TEMPLATE_DIR"/*.json; do
        if [[ -f "$template_file" ]]; then
            local template_name
            template_name="$(basename "$template_file" .json | sed 's/-template$//')"
            
            # Extract description from JSON
            local description
            description=$(jq -r '.description // "No description available"' "$template_file" 2>/dev/null || echo "Invalid JSON")
            
            echo -e "  ${GREEN}${template_name}${NC}: $description"
        fi
    done
    echo
}

load_template() {
    local template_name="$1"
    local template_file="$TEMPLATE_DIR/${template_name}-template.json"
    
    if [[ ! -f "$template_file" ]]; then
        echo -e "${RED}Error: Template '$template_name' not found${NC}" >&2
        echo -e "${YELLOW}Available templates:${NC}" >&2
        print_templates >&2
        exit 1
    fi
    
    if ! jq empty "$template_file" 2>/dev/null; then
        echo -e "${RED}Error: Template '$template_name' contains invalid JSON${NC}" >&2
        exit 1
    fi
    
    echo "$template_file"
}

normalize_url() {
    local url="$1"
    
    # Add https:// if no protocol specified
    if [[ ! "$url" =~ ^https?:// ]]; then
        url="https://$url"
    fi
    
    # Remove trailing slash
    url="${url%/}"
    
    echo "$url"
}

generate_vast_url() {
    local template_file="$1"
    local server="$2"
    local voucher="$3"
    
    local image
    image=$(jq -r '.image' "$template_file")
    
    local base_url="https://vast.ai/console/create"
    local image_param="image=${image}"
    
    # URL encode the environment variables
    local server_encoded
    local voucher_encoded
    server_encoded=$(printf '%s' "$server" | jq -sRr @uri)
    voucher_encoded=$(printf '%s' "$voucher" | jq -sRr @uri)
    
    local env_params="env=HT_SERVER%3D${server_encoded}%26HT_VOUCHER%3D${voucher_encoded}"
    
    # Add additional environment variables
    local extra_env=""
    jq -r '.environment | to_entries[] | select(.key != "HT_SERVER" and .key != "HT_VOUCHER") | "\(.key)%3D\(.value)"' "$template_file" | while read -r env_var; do
        if [[ -n "$env_var" ]]; then
            env_params="${env_params}%26${env_var}"
        fi
    done
    
    # Add search criteria
    local search_params=""
    local search_query
    search_query=$(jq -r '.search_criteria | to_entries[] | "\(.key)\(.value)"' "$template_file" | tr '\n' ' ' | sed 's/ $//')
    
    if [[ -n "$search_query" ]]; then
        local search_encoded
        search_encoded=$(printf '%s' "$search_query" | jq -sRr @uri)
        search_params="&search=${search_encoded}"
    fi
    
    echo "${base_url}?${image_param}&${env_params}${search_params}"
}

generate_docker_command() {
    local template_file="$1"
    local server="$2"
    local voucher="$3"
    
    local image
    image=$(jq -r '.image' "$template_file")
    
    echo "docker run -d --gpus all \\"
    echo "  -e HT_SERVER=\"$server\" \\"
    echo "  -e HT_VOUCHER=\"$voucher\" \\"
    
    # Add additional environment variables
    jq -r '.environment | to_entries[] | select(.key != "HT_SERVER" and .key != "HT_VOUCHER") | "  -e \(.key)=\"\(.value)\" \\"' "$template_file"
    
    echo "  $image"
}

generate_env_file() {
    local template_file="$1"
    local server="$2"
    local voucher="$3"
    
    echo "# Generated from template: $(basename "$template_file")"
    echo "# $(date)"
    echo
    echo "HT_SERVER=$server"
    echo "HT_VOUCHER=$voucher"
    
    jq -r '.environment | to_entries[] | select(.key != "HT_SERVER" and .key != "HT_VOUCHER") | "\(.key)=\(.value)"' "$template_file"
}

generate_json_config() {
    local template_file="$1"
    local server="$2"
    local voucher="$3"
    
    jq --arg server "$server" --arg voucher "$voucher" '
        .environment.HT_SERVER = $server |
        .environment.HT_VOUCHER = $voucher
    ' "$template_file"
}

main() {
    local template_name=""
    local server=""
    local voucher=""
    local output_format="url"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --server)
                server="$2"
                shift 2
                ;;
            --voucher)
                voucher="$2"
                shift 2
                ;;
            --output)
                output_format="$2"
                shift 2
                ;;
            --help|-h)
                print_usage
                exit 0
                ;;
            --list)
                print_templates
                exit 0
                ;;
            -*)
                echo -e "${RED}Error: Unknown option $1${NC}" >&2
                print_usage >&2
                exit 1
                ;;
            *)
                if [[ -z "$template_name" ]]; then
                    template_name="$1"
                else
                    echo -e "${RED}Error: Multiple template names specified${NC}" >&2
                    print_usage >&2
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Validate required arguments
    if [[ -z "$template_name" ]]; then
        echo -e "${RED}Error: Template name is required${NC}" >&2
        echo
        print_templates >&2
        exit 1
    fi
    
    # Load template
    local template_file
    template_file=$(load_template "$template_name")
    
    # For some output formats, we need server and voucher
    if [[ "$output_format" =~ ^(url|docker|env)$ ]]; then
        if [[ -z "$server" ]]; then
            echo -n "Enter Hashtopolis server URL: "
            read -r server
        fi
        
        if [[ -z "$voucher" ]]; then
            echo -n "Enter voucher ID: "
            read -r voucher
        fi
        
        server=$(normalize_url "$server")
    fi
    
    # Generate output based on format
    echo -e "${BLUE}Generated configuration for template: ${GREEN}$template_name${NC}"
    echo
    
    case "$output_format" in
        url)
            echo -e "${CYAN}One-click Vast.ai deployment URL:${NC}"
            echo
            generate_vast_url "$template_file" "$server" "$voucher"
            ;;
        docker)
            echo -e "${CYAN}Docker command:${NC}"
            echo
            generate_docker_command "$template_file" "$server" "$voucher"
            ;;
        env)
            echo -e "${CYAN}Environment file (.env):${NC}"
            echo
            generate_env_file "$template_file" "$server" "$voucher"
            ;;
        json)
            echo -e "${CYAN}JSON configuration:${NC}"
            echo
            if [[ -n "$server" && -n "$voucher" ]]; then
                generate_json_config "$template_file" "$server" "$voucher"
            else
                cat "$template_file"
            fi
            ;;
        *)
            echo -e "${RED}Error: Invalid output format '$output_format'${NC}" >&2
            echo "Valid formats: url, docker, json, env" >&2
            exit 1
            ;;
    esac
    
    echo
}

# Check if jq is available
if ! command -v jq >/dev/null 2>&1; then
    echo -e "${RED}Error: jq is required but not installed${NC}" >&2
    echo "Please install jq to use this script" >&2
    exit 1
fi

# Run main function with all arguments
main "$@"