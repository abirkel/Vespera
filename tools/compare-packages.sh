#!/bin/bash

# compare-packages.sh
# Compares packages across the full chain: Fedora Kinoite → ublue-os/main → Aurora → Vespera
# Shows what each layer adds/removes from the previous layer
# Supports GPU variants: main, nvidia, nvidia-open

set -euo pipefail

AURORA_RAW="https://raw.githubusercontent.com/ublue-os/aurora/main"
MAIN_RAW="https://raw.githubusercontent.com/ublue-os/main/main"
VESPERA_CONFIG="vespera-config.yaml"

# Default values
GPU_VARIANT="nvidia"
AURORA_VARIANT="aurora"

echo "=== Package Comparison Tool ==="
echo "Comparing packages across the full build chain..."
echo

# Function to fetch and parse Aurora packages
fetch_aurora_packages() {
    local variant="$1"
    local packages_json
    packages_json=$(curl -s "${AURORA_RAW}/packages.json")
    
    if [[ -z "$packages_json" ]]; then
        echo "❌ Failed to fetch Aurora packages.json"
        return 1
    fi
    
    # Extract RPM packages for specified variant
    echo "$packages_json" | jq -r ".\"${variant}\".rpms[]? // empty" 2>/dev/null | sort
}

# Function to fetch and parse ublue-os/main packages
fetch_main_packages() {
    local packages_json
    packages_json=$(curl -s "${MAIN_RAW}/packages.json")
    
    if [[ -z "$packages_json" ]]; then
        echo "❌ Failed to fetch ublue-os/main packages.json"
        return 1
    fi
    
    # Extract RPM packages for kinoite variant
    echo "$packages_json" | jq -r '.kinoite.rpms[]? // empty' 2>/dev/null | sort
}

# Function to fetch Aurora Flatpaks
fetch_aurora_flatpaks() {
    local variant="$1"
    local flatpak_file
    
    if [[ "$variant" == "aurora-dx" ]]; then
        flatpak_file="system-flatpaks-dx.list"
    else
        flatpak_file="system-flatpaks.list"
    fi
    
    curl -s "${AURORA_RAW}/flatpaks/${flatpak_file}" 2>/dev/null | grep -v '^#' | grep -v '^$' | sort || echo ""
}

# Function to fetch ublue-os/main Flatpaks
fetch_main_flatpaks() {
    curl -s "${MAIN_RAW}/flatpaks/system-flatpaks.list" 2>/dev/null | grep -v '^#' | grep -v '^$' | sort || echo ""
}

# Function to parse Vespera config
parse_vespera_config() {
    if [[ ! -f "$VESPERA_CONFIG" ]]; then
        echo "⚠️  Vespera config file not found: $VESPERA_CONFIG"
        return 1
    fi
    
    # Use yq if available, otherwise try basic parsing
    if command -v yq &> /dev/null; then
        case "$1" in
            "remove_rpm")
                yq eval '.packages.remove_rpm[]? // empty' "$VESPERA_CONFIG" 2>/dev/null | sort
                ;;
            "add_rpm")
                yq eval '.packages.add_rpm[]? // empty' "$VESPERA_CONFIG" 2>/dev/null | sort
                ;;
            "remove_flatpak")
                yq eval '.packages.remove_flatpak[]? // empty' "$VESPERA_CONFIG" 2>/dev/null | sort
                ;;
            "add_flatpak")
                yq eval '.packages.add_flatpak[]? // empty' "$VESPERA_CONFIG" 2>/dev/null | sort
                ;;
        esac
    else
        echo "⚠️  yq not available for parsing YAML. Install yq for full Vespera config parsing."
        return 1
    fi
}

# Function to compare two package lists
compare_packages() {
    local base_list="$1"
    local derived_list="$2"
    local base_name="$3"
    local derived_name="$4"
    
    # Create temporary files
    local base_temp=$(mktemp)
    local derived_temp=$(mktemp)
    
    echo "$base_list" > "$base_temp"
    echo "$derived_list" > "$derived_temp"
    
    # Find additions (in derived but not in base)
    local additions
    additions=$(comm -13 "$base_temp" "$derived_temp" 2>/dev/null || echo "")
    
    # Find removals (in base but not in derived)
    local removals
    removals=$(comm -23 "$base_temp" "$derived_temp" 2>/dev/null || echo "")
    
    echo "📊 $derived_name vs $base_name:"
    echo "────────────────────────────────────"
    
    if [[ -n "$additions" ]]; then
        echo "✅ Added packages:"
        echo "$additions" | sed 's/^/  + /'
    else
        echo "  No packages added"
    fi
    
    if [[ -n "$removals" ]]; then
        echo "❌ Removed packages:"
        echo "$removals" | sed 's/^/  - /'
    else
        echo "  No packages removed"
    fi
    echo
    
    # Cleanup
    rm -f "$base_temp" "$derived_temp"
}

# Function to show the full chain comparison
show_full_chain() {
    local aurora_variant="$1"
    local gpu_variant="$2"
    
    echo "🔗 Full Package Chain Analysis"
    echo "═══════════════════════════════════════════════════════════════"
    echo "Analyzing: Fedora Kinoite → ublue-os/main → Aurora ($aurora_variant) → Vespera"
    echo "GPU Variant: $gpu_variant"
    echo
    
    # Fetch all package lists
    echo "📥 Fetching package data..."
    
    local main_rpms
    main_rpms=$(fetch_main_packages)
    
    local aurora_rpms
    aurora_rpms=$(fetch_aurora_packages "$aurora_variant")
    
    local main_flatpaks
    main_flatpaks=$(fetch_main_flatpaks)
    
    local aurora_flatpaks
    aurora_flatpaks=$(fetch_aurora_flatpaks "$aurora_variant")
    
    echo "✅ Package data fetched successfully"
    echo
    
    # RPM Comparisons
    echo "🔍 RPM Package Analysis:"
    echo "═══════════════════════"
    
    # We can't easily get base Fedora Kinoite packages, so we start from ublue-os/main
    echo "📦 ublue-os/main RPM packages (added to Fedora Kinoite):"
    echo "──────────────────────────────────────────────────────"
    if [[ -n "$main_rpms" ]]; then
        echo "$main_rpms" | sed 's/^/  + /'
    else
        echo "  No RPM packages found"
    fi
    echo
    
    # Compare Aurora to ublue-os/main
    compare_packages "$main_rpms" "$aurora_rpms" "ublue-os/main" "Aurora ($aurora_variant)"
    
    # Vespera comparison (if config exists)
    if [[ -f "$VESPERA_CONFIG" ]]; then
        echo "📦 Vespera customizations (from $VESPERA_CONFIG):"
        echo "─────────────────────────────────────────────────"
        
        local vespera_remove_rpm
        vespera_remove_rpm=$(parse_vespera_config "remove_rpm" 2>/dev/null || echo "")
        
        local vespera_add_rpm
        vespera_add_rpm=$(parse_vespera_config "add_rpm" 2>/dev/null || echo "")
        
        if [[ -n "$vespera_remove_rpm" ]]; then
            echo "❌ Vespera removes these RPM packages:"
            echo "$vespera_remove_rpm" | sed 's/^/  - /'
        fi
        
        if [[ -n "$vespera_add_rpm" ]]; then
            echo "✅ Vespera adds these RPM packages:"
            echo "$vespera_add_rpm" | sed 's/^/  + /'
        fi
        
        if [[ -z "$vespera_remove_rpm" && -z "$vespera_add_rpm" ]]; then
            echo "  No RPM customizations defined"
        fi
        echo
    fi
    
    # Flatpak Comparisons
    echo "🔍 Flatpak Analysis:"
    echo "═══════════════════"
    
    echo "📱 ublue-os/main Flatpaks:"
    echo "─────────────────────────"
    if [[ -n "$main_flatpaks" ]]; then
        echo "$main_flatpaks" | sed 's/^/  + /'
    else
        echo "  No Flatpaks found"
    fi
    echo
    
    # Compare Aurora Flatpaks to ublue-os/main
    compare_packages "$main_flatpaks" "$aurora_flatpaks" "ublue-os/main" "Aurora ($aurora_variant)"
    
    # Vespera Flatpak comparison (if config exists)
    if [[ -f "$VESPERA_CONFIG" ]]; then
        echo "📱 Vespera Flatpak customizations:"
        echo "─────────────────────────────────"
        
        local vespera_remove_flatpak
        vespera_remove_flatpak=$(parse_vespera_config "remove_flatpak" 2>/dev/null || echo "")
        
        local vespera_add_flatpak
        vespera_add_flatpak=$(parse_vespera_config "add_flatpak" 2>/dev/null || echo "")
        
        if [[ -n "$vespera_remove_flatpak" ]]; then
            echo "❌ Vespera removes these Flatpaks:"
            echo "$vespera_remove_flatpak" | sed 's/^/  - /'
        fi
        
        if [[ -n "$vespera_add_flatpak" ]]; then
            echo "✅ Vespera adds these Flatpaks:"
            echo "$vespera_add_flatpak" | sed 's/^/  + /'
        fi
        
        if [[ -z "$vespera_remove_flatpak" && -z "$vespera_add_flatpak" ]]; then
            echo "  No Flatpak customizations defined"
        fi
        echo
    fi
    
    # GPU Variant Information
    echo "🎮 GPU Variant Information:"
    echo "═══════════════════════════"
    echo "Current GPU variant: $gpu_variant"
    echo
    echo "ℹ️  GPU variants use different Aurora base images:"
    echo "  • main:         ghcr.io/ublue-os/aurora-main:41"
    echo "  • nvidia:       ghcr.io/ublue-os/aurora-nvidia:41"
    echo "  • nvidia-open:  ghcr.io/ublue-os/aurora-nvidia-open:41"
    echo
    echo "The package lists shown above are typically the same across GPU variants."
    echo "GPU-specific differences are in the base image (drivers, kernel modules)."
    echo
    echo "Your Vespera image will use: ghcr.io/ublue-os/aurora-${gpu_variant}:41"
    echo
}

# Function to show summary
show_summary() {
    local gpu_variant="$1"
    
    echo "📋 Summary:"
    echo "═══════════"
    echo "This tool shows the complete package evolution chain:"
    echo
    echo "1. 🐧 Fedora Kinoite (base immutable desktop)"
    echo "   └─ Provides core KDE Plasma desktop on Fedora"
    echo
    echo "2. 🔧 ublue-os/main (universal base layer)"
    echo "   └─ Adds essential packages and improvements to Kinoite"
    echo
    echo "3. 🌅 Aurora (gaming-focused layer with GPU variant: $gpu_variant)"
    echo "   └─ Adds gaming packages, codecs, and user experience improvements"
    echo "   └─ GPU-specific drivers and kernel modules for $gpu_variant hardware"
    echo
    echo "4. 🌆 Vespera (your custom layer)"
    echo "   └─ Your personalized package selection + maccel driver"
    echo
    echo "Each layer builds upon the previous one, adding or removing packages"
    echo "to create a more specialized system for specific use cases."
    echo
    echo "GPU Variants:"
    echo "  • main:         Intel/AMD graphics with open source drivers"
    echo "  • nvidia:       NVIDIA graphics with proprietary drivers"
    echo "  • nvidia-open:  NVIDIA graphics with open source drivers"
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
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --variant)
                AURORA_VARIANT="$2"
                shift 2
                ;;
            --gpu-variant)
                GPU_VARIANT="$2"
                shift 2
                ;;
            --help|-h)
                echo "Usage: $0 [--variant aurora|aurora-dx] [--gpu-variant main|nvidia|nvidia-open]"
                echo
                echo "Compare packages across the full build chain:"
                echo "Fedora Kinoite → ublue-os/main → Aurora → Vespera"
                echo
                echo "Options:"
                echo "  --variant        Aurora variant to compare (aurora or aurora-dx)"
                echo "                   Default: aurora (or reads from vespera-config.yaml)"
                echo "  --gpu-variant    GPU variant to use (main, nvidia, nvidia-open)"
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
    
    # Try to read configuration from vespera-config.yaml if not specified
    if [[ -f "$VESPERA_CONFIG" ]]; then
        if command -v yq &> /dev/null; then
            # Read Aurora variant if not specified via command line
            if [[ "$AURORA_VARIANT" == "aurora" ]]; then
                CONFIG_VARIANT=$(yq eval '.base.variant // "aurora"' "$VESPERA_CONFIG" 2>/dev/null || echo "aurora")
                if [[ -n "$CONFIG_VARIANT" ]]; then
                    AURORA_VARIANT="$CONFIG_VARIANT"
                fi
            fi
            
            # Read GPU variant if not specified via command line
            if [[ "$GPU_VARIANT" == "nvidia" ]]; then
                CONFIG_GPU_VARIANT=$(yq eval '.base.gpu_variant // "nvidia"' "$VESPERA_CONFIG" 2>/dev/null || echo "nvidia")
                if [[ -n "$CONFIG_GPU_VARIANT" ]]; then
                    GPU_VARIANT="$CONFIG_GPU_VARIANT"
                fi
            fi
        fi
    fi
    
    show_full_chain "$AURORA_VARIANT" "$GPU_VARIANT"
    show_summary "$GPU_VARIANT"
    
    echo "✅ Package comparison complete!"
    echo
    echo "💡 Tips:"
    echo "   • Use --variant aurora-dx to compare with Aurora DX variant"
    echo "   • Use --gpu-variant to compare different GPU configurations"
    echo "   • Configuration is read from $VESPERA_CONFIG if present"
    echo "   • Current settings: variant=$AURORA_VARIANT, gpu_variant=$GPU_VARIANT"
    echo "   • Run individual scripts for detailed package lists:"
    echo "     - ./tools/check-aurora-packages.sh"
    echo "     - ./tools/check-kinoite-packages.sh"
}

# Run main function
main "$@"