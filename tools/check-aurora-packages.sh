#!/bin/bash

# check-aurora-packages.sh
# Fetches and displays current Aurora package lists from the ublue-os/aurora repository
# Supports GPU variants: main, nvidia, nvidia-open

set -euo pipefail

AURORA_REPO="https://api.github.com/repos/ublue-os/aurora"
AURORA_RAW="https://raw.githubusercontent.com/ublue-os/aurora/main"
VESPERA_CONFIG="vespera-config.yaml"

# Default GPU variant
GPU_VARIANT="nvidia"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --gpu-variant)
            GPU_VARIANT="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [--gpu-variant main|nvidia|nvidia-open]"
            echo
            echo "Fetches and displays Aurora package lists from the ublue-os/aurora repository."
            echo "Supports GPU variants to show packages for specific GPU configurations."
            echo
            echo "Options:"
            echo "  --gpu-variant    GPU variant to check (main, nvidia, nvidia-open)"
            echo "                   Default: nvidia (or reads from vespera-config.yaml)"
            echo "  --help           Show this help message"
            echo
            echo "GPU Variants:"
            echo "  main          - Intel/AMD graphics with open source drivers"
            echo "  nvidia        - NVIDIA graphics with proprietary drivers"
            echo "  nvidia-open   - NVIDIA graphics with open source drivers"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Try to read GPU variant from vespera-config.yaml if not specified
if [[ "$GPU_VARIANT" == "nvidia" ]] && [[ -f "$VESPERA_CONFIG" ]]; then
    if command -v yq &> /dev/null; then
        CONFIG_GPU_VARIANT=$(yq eval '.base.gpu_variant // "nvidia"' "$VESPERA_CONFIG" 2>/dev/null || echo "nvidia")
        if [[ -n "$CONFIG_GPU_VARIANT" ]]; then
            GPU_VARIANT="$CONFIG_GPU_VARIANT"
        fi
    fi
fi

echo "=== Aurora Package Inspector ==="
echo "GPU Variant: $GPU_VARIANT"
echo "Fetching current Aurora package information..."
echo

# Function to fetch and parse packages.json
fetch_packages_json() {
    echo "📦 Fetching packages.json..."
    local packages_json
    packages_json=$(curl -s "${AURORA_RAW}/packages.json")
    
    if [[ -z "$packages_json" ]]; then
        echo "❌ Failed to fetch packages.json"
        return 1
    fi
    
    echo "✅ Successfully fetched packages.json"
    echo
    
    # Parse aurora variant packages
    echo "🔍 Aurora (standard) variant packages:"
    echo "────────────────────────────────────────"
    
    # Extract RPM packages for aurora variant
    local aurora_rpms
    aurora_rpms=$(echo "$packages_json" | jq -r '.aurora.rpms[]? // empty' 2>/dev/null || echo "No RPM packages found")
    
    if [[ "$aurora_rpms" != "No RPM packages found" ]]; then
        echo "RPM packages:"
        echo "$aurora_rpms" | sort | sed 's/^/  - /'
    else
        echo "  No RPM packages defined"
    fi
    echo
    
    # Parse aurora-dx variant packages
    echo "🔍 Aurora-DX (developer) variant packages:"
    echo "──────────────────────────────────────────"
    
    # Extract RPM packages for aurora-dx variant
    local aurora_dx_rpms
    aurora_dx_rpms=$(echo "$packages_json" | jq -r '.["aurora-dx"].rpms[]? // empty' 2>/dev/null || echo "No RPM packages found")
    
    if [[ "$aurora_dx_rpms" != "No RPM packages found" ]]; then
        echo "RPM packages:"
        echo "$aurora_dx_rpms" | sort | sed 's/^/  - /'
    else
        echo "  No RPM packages defined"
    fi
    echo
    
    # Check for GPU variant-specific differences
    check_gpu_variant_differences "$packages_json"
}

# Function to check for GPU variant-specific package differences
check_gpu_variant_differences() {
    local packages_json="$1"
    
    echo "🎮 GPU Variant Analysis (Current: $GPU_VARIANT):"
    echo "─────────────────────────────────────────────────"
    
    # Note: Aurora images use different base images for GPU variants but typically
    # don't have different package lists in packages.json. The differences are in
    # the base image itself (different kernel modules, drivers, etc.)
    
    echo "ℹ️  GPU variants use different Aurora base images:"
    echo "  • main:         ghcr.io/ublue-os/aurora-main:41"
    echo "  • nvidia:       ghcr.io/ublue-os/aurora-nvidia:41"
    echo "  • nvidia-open:  ghcr.io/ublue-os/aurora-nvidia-open:41"
    echo
    echo "The package list in packages.json is typically the same across GPU variants."
    echo "GPU-specific differences are in the base image (drivers, kernel modules)."
    echo
    echo "Your configured GPU variant: $GPU_VARIANT"
    echo "Your Vespera image will use: ghcr.io/ublue-os/aurora-${GPU_VARIANT}:41"
    echo
}

# Function to fetch Flatpak lists
fetch_flatpaks() {
    echo "📱 Fetching Flatpak lists..."
    
    # Fetch system flatpaks (standard aurora)
    echo "🔍 Aurora (standard) Flatpaks:"
    echo "──────────────────────────────"
    
    local system_flatpaks
    system_flatpaks=$(curl -s "${AURORA_RAW}/flatpaks/system-flatpaks.list" 2>/dev/null || echo "")
    
    if [[ -n "$system_flatpaks" ]]; then
        echo "System Flatpaks:"
        echo "$system_flatpaks" | grep -v '^#' | grep -v '^$' | sort | sed 's/^/  - /' || echo "  No Flatpaks found"
    else
        echo "  ❌ Could not fetch system-flatpaks.list"
    fi
    echo
    
    # Fetch system flatpaks DX (aurora-dx)
    echo "🔍 Aurora-DX (developer) Flatpaks:"
    echo "───────────────────────────────────"
    
    local system_flatpaks_dx
    system_flatpaks_dx=$(curl -s "${AURORA_RAW}/flatpaks/system-flatpaks-dx.list" 2>/dev/null || echo "")
    
    if [[ -n "$system_flatpaks_dx" ]]; then
        echo "System Flatpaks (DX):"
        echo "$system_flatpaks_dx" | grep -v '^#' | grep -v '^$' | sort | sed 's/^/  - /' || echo "  No Flatpaks found"
    else
        echo "  ❌ Could not fetch system-flatpaks-dx.list"
    fi
    echo
}

# Function to get repository information
get_repo_info() {
    echo "ℹ️  Repository Information:"
    echo "─────────────────────────"
    
    local repo_info
    repo_info=$(curl -s "$AURORA_REPO")
    
    if [[ -n "$repo_info" ]]; then
        local updated_at
        local default_branch
        updated_at=$(echo "$repo_info" | jq -r '.updated_at // "Unknown"')
        default_branch=$(echo "$repo_info" | jq -r '.default_branch // "main"')
        
        echo "  Repository: ublue-os/aurora"
        echo "  Branch: $default_branch"
        echo "  Last updated: $updated_at"
        echo "  URL: https://github.com/ublue-os/aurora"
        echo "  GPU Variant: $GPU_VARIANT"
    else
        echo "  ❌ Could not fetch repository information"
    fi
    echo
}

# Main execution
main() {
    # Check for required tools
    if ! command -v curl &> /dev/null; then
        echo "❌ curl is required but not installed"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo "❌ jq is required but not installed"
        echo "Please install jq to parse JSON data"
        exit 1
    fi
    
    get_repo_info
    fetch_packages_json
    fetch_flatpaks
    
    echo "✅ Aurora package inspection complete!"
    echo
    echo "💡 Tips:"
    echo "   • Use this information to understand what packages Aurora provides"
    echo "     before customizing them in your Vespera configuration."
    echo "   • Use --gpu-variant to check different GPU configurations"
    echo "   • GPU variant is read from vespera-config.yaml if present"
    echo "   • Current GPU variant: $GPU_VARIANT"
}

# Run main function
main "$@"