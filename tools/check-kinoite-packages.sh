#!/bin/bash

# check-kinoite-packages.sh
# Fetches and displays ublue-os/main package customizations (Aurora's upstream)
# Shows what ublue-os/main adds to base Fedora Kinoite

set -euo pipefail

MAIN_REPO="https://api.github.com/repos/ublue-os/main"
MAIN_RAW="https://raw.githubusercontent.com/ublue-os/main/main"

echo "=== ublue-os/main Package Inspector ==="
echo "Fetching ublue-os/main package information (Aurora's upstream)..."
echo

# Function to fetch and parse packages.json from ublue-os/main
fetch_main_packages_json() {
    echo "📦 Fetching packages.json from ublue-os/main..."
    local packages_json
    packages_json=$(curl -s "${MAIN_RAW}/packages.json")
    
    if [[ -z "$packages_json" ]]; then
        echo "❌ Failed to fetch packages.json from ublue-os/main"
        return 1
    fi
    
    echo "✅ Successfully fetched packages.json"
    echo
    
    # Parse kinoite variant packages (what ublue-os/main adds to Fedora Kinoite)
    echo "🔍 ublue-os/main Kinoite customizations:"
    echo "──────────────────────────────────────────"
    echo "These are packages that ublue-os/main adds to base Fedora Kinoite"
    echo
    
    # Extract RPM packages for kinoite variant
    local kinoite_rpms
    kinoite_rpms=$(echo "$packages_json" | jq -r '.kinoite.rpms[]? // empty' 2>/dev/null || echo "No RPM packages found")
    
    if [[ "$kinoite_rpms" != "No RPM packages found" ]]; then
        echo "Added RPM packages:"
        echo "$kinoite_rpms" | sort | sed 's/^/  + /'
    else
        echo "  No additional RPM packages defined"
    fi
    echo
    
    # Check for removed packages
    local removed_rpms
    removed_rpms=$(echo "$packages_json" | jq -r '.kinoite.remove[]? // empty' 2>/dev/null || echo "No removed packages found")
    
    if [[ "$removed_rpms" != "No removed packages found" ]]; then
        echo "Removed RPM packages:"
        echo "$removed_rpms" | sort | sed 's/^/  - /'
        echo
    fi
    
    # Look for other variants that might be relevant
    echo "🔍 Other variants in ublue-os/main:"
    echo "───────────────────────────────────"
    local variants
    variants=$(echo "$packages_json" | jq -r 'keys[]' 2>/dev/null | grep -v '^kinoite$' || echo "No other variants found")
    
    if [[ "$variants" != "No other variants found" ]]; then
        echo "Available variants:"
        echo "$variants" | sed 's/^/  - /'
    else
        echo "  Only kinoite variant found"
    fi
    echo
}

# Function to fetch Flatpak lists from ublue-os/main
fetch_main_flatpaks() {
    echo "📱 Fetching Flatpak lists from ublue-os/main..."
    
    # Check for system flatpaks
    echo "🔍 ublue-os/main Flatpaks:"
    echo "──────────────────────────"
    
    local system_flatpaks
    system_flatpaks=$(curl -s "${MAIN_RAW}/flatpaks/system-flatpaks.list" 2>/dev/null || echo "")
    
    if [[ -n "$system_flatpaks" ]]; then
        echo "System Flatpaks added by ublue-os/main:"
        echo "$system_flatpaks" | grep -v '^#' | grep -v '^$' | sort | sed 's/^/  + /' || echo "  No Flatpaks found"
    else
        echo "  ❌ Could not fetch system-flatpaks.list or file doesn't exist"
    fi
    echo
    
    # Check for other flatpak lists
    echo "🔍 Checking for other Flatpak configurations..."
    
    # Try to find other flatpak files
    local flatpak_files=("user-flatpaks.list" "kinoite-flatpaks.list" "desktop-flatpaks.list")
    
    for file in "${flatpak_files[@]}"; do
        local flatpaks
        flatpaks=$(curl -s "${MAIN_RAW}/flatpaks/${file}" 2>/dev/null || echo "")
        
        if [[ -n "$flatpaks" ]]; then
            echo "Found ${file}:"
            echo "$flatpaks" | grep -v '^#' | grep -v '^$' | sort | sed 's/^/  + /' || echo "  No entries found"
            echo
        fi
    done
}

# Function to get repository information
get_main_repo_info() {
    echo "ℹ️  Repository Information:"
    echo "─────────────────────────"
    
    local repo_info
    repo_info=$(curl -s "$MAIN_REPO")
    
    if [[ -n "$repo_info" ]]; then
        local updated_at
        local default_branch
        local description
        updated_at=$(echo "$repo_info" | jq -r '.updated_at // "Unknown"')
        default_branch=$(echo "$repo_info" | jq -r '.default_branch // "main"')
        description=$(echo "$repo_info" | jq -r '.description // "No description"')
        
        echo "  Repository: ublue-os/main"
        echo "  Description: $description"
        echo "  Branch: $default_branch"
        echo "  Last updated: $updated_at"
        echo "  URL: https://github.com/ublue-os/main"
        echo "  Base: quay.io/fedora-ostree-desktops/kinoite"
    else
        echo "  ❌ Could not fetch repository information"
    fi
    echo
}

# Function to explain the relationship
explain_relationship() {
    echo "🔗 Understanding the relationship:"
    echo "─────────────────────────────────"
    echo "  Fedora Kinoite (base)"
    echo "    ↓ (ublue-os/main adds packages and customizations)"
    echo "  ublue-os/main"
    echo "    ↓ (Aurora adds more packages and gaming focus)"
    echo "  Aurora"
    echo "    ↓ (Vespera customizes packages and adds maccel)"
    echo "  Vespera"
    echo
    echo "ublue-os/main provides the foundation that Aurora builds upon."
    echo "It adds essential packages and configurations to base Fedora Kinoite."
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
    
    get_main_repo_info
    explain_relationship
    fetch_main_packages_json
    fetch_main_flatpaks
    
    echo "✅ ublue-os/main package inspection complete!"
    echo
    echo "💡 Tip: This shows what ublue-os/main adds to base Fedora Kinoite."
    echo "   Aurora then builds on top of these customizations."
}

# Run main function
main "$@"