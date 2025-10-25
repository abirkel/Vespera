# Package Inspection Tools

This directory contains tools to inspect and compare packages across the full Vespera build chain.

## Tools Overview

### 1. check-aurora-packages.sh
Fetches and displays current Aurora package lists from the ublue-os/aurora repository.

**Features:**
- Shows RPM packages for both aurora and aurora-dx variants
- Displays Flatpak lists for both variants
- Provides repository information and last update timestamps

**Usage:**
```bash
./tools/check-aurora-packages.sh
```

**Requirements:**
- `curl` - for fetching data from GitHub
- `jq` - for parsing JSON responses

### 2. check-kinoite-packages.sh
Fetches and displays ublue-os/main package customizations (Aurora's upstream).

**Features:**
- Shows what ublue-os/main adds to base Fedora Kinoite
- Displays Flatpak configurations
- Explains the relationship between Fedora Kinoite and ublue-os/main

**Usage:**
```bash
./tools/check-kinoite-packages.sh
```

**Requirements:**
- `curl` - for fetching data from GitHub
- `jq` - for parsing JSON responses

### 3. compare-packages.sh
Compares packages across the full build chain: Fedora Kinoite → ublue-os/main → Aurora → Vespera.

**Features:**
- Shows what each layer adds/removes from the previous layer
- Supports both aurora and aurora-dx variants
- Reads Vespera configuration to show your customizations
- Provides comprehensive analysis of the entire package evolution

**Usage:**
```bash
# Compare with standard Aurora variant
./tools/compare-packages.sh

# Compare with Aurora DX variant
./tools/compare-packages.sh --variant aurora-dx

# Show help
./tools/compare-packages.sh --help
```

**Requirements:**
- `curl` - for fetching data from GitHub
- `jq` - for parsing JSON responses
- `yq` - for parsing Vespera YAML configuration (optional but recommended)

## Installation Requirements

### On Linux/macOS:
```bash
# Install jq (JSON processor)
# Ubuntu/Debian:
sudo apt install jq curl

# Fedora:
sudo dnf install jq curl

# macOS:
brew install jq curl

# Install yq (YAML processor) - optional but recommended
# Using go:
go install github.com/mikefarah/yq/v4@latest

# Using pip:
pip install yq

# Using snap:
sudo snap install yq
```

### On Windows:
```powershell
# Using chocolatey:
choco install jq curl yq

# Using scoop:
scoop install jq curl yq

# Or download binaries directly from:
# - jq: https://stedolan.github.io/jq/download/
# - curl: https://curl.se/download.html
# - yq: https://github.com/mikefarah/yq/releases
```

## Understanding the Package Chain

The tools help you understand this evolution:

```
Fedora Kinoite (base)
    ↓ (ublue-os/main adds essential packages)
ublue-os/main
    ↓ (Aurora adds gaming focus and user experience)
Aurora
    ↓ (Vespera adds your customizations + maccel)
Vespera
```

Each layer:
1. **Fedora Kinoite**: Base immutable KDE desktop
2. **ublue-os/main**: Universal base layer with essential improvements
3. **Aurora**: Gaming-focused layer with codecs and gaming packages
4. **Vespera**: Your custom layer with package preferences and maccel driver

## Example Workflow

1. **Understand what Aurora provides:**
   ```bash
   ./tools/check-aurora-packages.sh
   ```

2. **See what ublue-os/main contributes:**
   ```bash
   ./tools/check-kinoite-packages.sh
   ```

3. **Compare the full chain:**
   ```bash
   ./tools/compare-packages.sh
   ```

4. **Create your Vespera configuration** based on the insights

5. **Re-run comparison** to see your customizations:
   ```bash
   ./tools/compare-packages.sh
   ```

## Tips

- Run these tools before creating your `vespera-config.yaml` to understand what's already available
- Use the comparison tool to avoid removing packages that aren't actually installed
- Check both aurora and aurora-dx variants to choose the best base for your needs
- The tools cache nothing - they always fetch fresh data from GitHub

## Troubleshooting

**"Command not found" errors:**
- Ensure `curl` and `jq` are installed and in your PATH
- On Windows, you may need to use Git Bash or WSL to run the scripts

**"Failed to fetch" errors:**
- Check your internet connection
- Verify GitHub is accessible from your network
- Some corporate networks may block GitHub API access

**YAML parsing issues:**
- Install `yq` for full Vespera configuration parsing
- The tools will work without `yq` but with limited Vespera config analysis