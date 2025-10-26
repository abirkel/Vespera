# Vespera

> *Vespera* (Latin for "evening") - A custom Fedora Atomic image that complements Aurora's dawn.

Vespera is a custom immutable Linux distribution based on [Aurora](https://getaurora.dev/), featuring personalized package selections and integrated mouse acceleration support via the [maccel driver](https://github.com/Gnarus-G/maccel).

## What is Vespera?

Vespera builds upon Aurora, a Fedora Atomic variant that provides:
- **Immutable OS Architecture**: Atomic updates with automatic rollback on failure
- **KDE Plasma Desktop**: Modern, polished desktop environment with Wayland support
- **Curated Package Selection**: Carefully selected tools for productivity and development
- **Universal Blue Infrastructure**: Automated builds and updates from the Universal Blue project
- **Enterprise Features**: Domain integration (FreeIPA, Samba), backup tools (Borg, Restic)
- **Hardware Support**: Tailscale VPN, OpenRazer for gaming peripherals, printer drivers
- **Developer Tools** (DX variant): Docker, Podman, QEMU, libvirt, VS Code, and more

Aurora comes in two variants:
- **aurora**: Standard variant with KDE desktop and essential tools
- **aurora-dx**: Developer Experience variant with containers, virtualization, and development tools

### GPU Variants

Aurora provides three GPU-specific variants to optimize driver support for different hardware:

- **nvidia** (default): NVIDIA proprietary drivers - Best performance for NVIDIA GPUs
- **nvidia-open**: NVIDIA open-source drivers - Open alternative for newer NVIDIA GPUs (Turing+)
- **main**: Intel/AMD open-source drivers - For Intel integrated graphics and AMD GPUs

**Choosing the Right GPU Variant**:

- **NVIDIA GPU users**: Use `nvidia` (default) for maximum compatibility and performance
- **Newer NVIDIA GPUs** (RTX 20-series and later): Can use `nvidia-open` for open-source driver benefits
- **Intel or AMD GPU users**: Use `main` for native open-source driver support
- **Hybrid systems**: Choose based on your primary GPU (the one driving your display)

The GPU variant affects which base image Vespera uses (e.g., `aurora-nvidia`, `aurora-main`). All other Vespera features work identically across GPU variants.

Use `./tools/check-aurora-packages.sh` to see Aurora's current package list, or check the [static reference](.references/AURORA-CUSTOMIZATIONS.md). The tool supports GPU variants: `./tools/check-aurora-packages.sh --gpu-variant nvidia`.

Vespera customizes this foundation by:
- **Package Customization**: Remove unwanted packages and add preferred alternatives (both RPM and Flatpak)
- **Maccel Integration**: Built-in mouse acceleration driver for precise pointer control
- **Automated Builds**: Daily checks for upstream changes, building only when necessary
- **Personal Configuration**: Tailored to your specific needs while maintaining Aurora's benefits

## Features

### Package Customization
- **Flexible Package Management**: Remove unwanted Aurora packages and add preferred alternatives
- **RPM and Flatpak Support**: Customize both system packages and containerized applications
- **Dependency Resolution**: Automatic handling of package dependencies during build

### Maccel Integration

[Maccel](https://github.com/Gnarus-G/maccel) is a Linux kernel driver that provides customizable mouse acceleration, similar to what's available on Windows and macOS. Vespera integrates maccel directly into the immutable image with:

- **Kernel Module**: Built from source and integrated into the kernel module tree
- **CLI Tool**: Rust-based command-line interface for configuring acceleration curves
- **TUI Interface**: Interactive terminal UI for easy configuration (`maccel tui`)
- **Auto-loading**: Kernel module loads automatically at boot
- **User Access**: Non-root access via `maccel` group membership

This ensures maccel is fully integrated and ready to use immediately after installation, without requiring DKMS or runtime compilation.

## Configuration

Edit `vespera-config.yaml` to customize your image:

```yaml
base:
  # Choose your Aurora variant
  variant: "aurora"  # or "aurora-dx" for developer tools
  
  # Choose your GPU variant (default: nvidia)
  gpu_variant: "nvidia"  # Options: "nvidia", "nvidia-open", "main"
  # - nvidia: NVIDIA proprietary drivers (best performance)
  # - nvidia-open: NVIDIA open-source drivers (RTX 20-series+)
  # - main: Intel/AMD open-source drivers

build:
  # Build strategy: "single" or "matrix"
  strategy: "single"  # "single" builds only your config, "matrix" builds all variants
  image_name: "vespera"  # Base name (will be modified based on variant)

packages:
  # Remove packages you don't want
  remove_rpm:
    - sunshine  # Game streaming (if not needed)
    - tailscale  # VPN service (if using alternatives)
  
  # Add packages you prefer
  add_rpm:
    - neovim  # Modern Vim alternative
    - htop  # Process viewer
  
  # Manage Flatpak applications
  add_flatpak:
    - com.spotify.Client  # Music streaming
```

### Changing GPU Variant

To change the GPU variant for your Vespera build:

1. Edit `vespera-config.yaml` and update the `gpu_variant` field:
   ```yaml
   base:
     variant: "aurora"
     gpu_variant: "main"  # Changed from "nvidia" to "main"
   ```

2. Commit and push the change to trigger a new build

3. After the build completes, rebase to the new image:
   ```bash
   # For NVIDIA GPU variant (default configuration)
   rpm-ostree rebase ostree-image-signed:docker://ghcr.io/YOUR_USERNAME/vespera-nvidia:latest
   systemctl reboot
   ```

**Note**: Changing GPU variants rebuilds the entire image with a different base. Make sure to choose the variant that matches your hardware before deploying to production systems.

**Documentation**:
- [Configuration Guide](docs/CONFIGURATION.md) - Detailed configuration options and examples
- [Package Inspection Tools](tools/README.md) - Tools to analyze Aurora and package chains
- [Build Process](docs/BUILD-PROCESS.md) - How Vespera is built and verified
- [GPU Variant Support](docs/GPU-VARIANT-SUPPORT.md) - Detailed GPU variant information

## Installation

### Prerequisites
- A system capable of running Fedora Atomic (x86_64 architecture)
- Existing Fedora Atomic/Kinoite installation (for rebasing)

### Image Naming Convention

Vespera follows Aurora's naming convention, creating different images for each variant combination:

| Configuration | Image Name | Description |
|---------------|------------|-------------|
| `aurora` + `main` | `vespera` | Base image with Intel/AMD GPU support |
| `aurora` + `nvidia` | `vespera-nvidia` | Base image with NVIDIA proprietary drivers |
| `aurora` + `nvidia-open` | `vespera-nvidia-open` | Base image with NVIDIA open drivers |
| `aurora-dx` + `main` | `vespera-dx` | Developer variant with Intel/AMD GPU support |
| `aurora-dx` + `nvidia` | `vespera-dx-nvidia` | Developer variant with NVIDIA proprietary drivers |
| `aurora-dx` + `nvidia-open` | `vespera-dx-nvidia-open` | Developer variant with NVIDIA open drivers |

The default configuration (`aurora` + `nvidia`) produces `vespera-nvidia`.

### Rebasing to Vespera

Once the image is built and published, you can rebase your existing Fedora Atomic system:

```bash
# Rebase to Vespera (NVIDIA variant - matches default config)
# Using signed images (recommended for security)
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/YOUR_USERNAME/vespera-nvidia:latest

# Reboot to apply changes
systemctl reboot
```

**For other variants**, use the corresponding image name from the table above:
```bash
# Developer variant with NVIDIA
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/YOUR_USERNAME/vespera-dx-nvidia:latest

# Base variant with Intel/AMD GPU
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/YOUR_USERNAME/vespera:latest
```

#### Signature Verification Setup

Vespera images are cryptographically signed using [Sigstore](https://www.sigstore.dev/) keyless signing. This ensures that images come from the official repository and haven't been tampered with.

**Automatic Verification**: When using `ostree-image-signed:docker://` URLs, rpm-ostree automatically verifies signatures before rebasing. No additional setup is required for basic security.

**Custom Policy Configuration** (optional): For stricter security policies, you can configure signature verification rules:

```bash
# Create or edit the container policy file
sudo mkdir -p /etc/containers
sudo nano /etc/containers/policy.json
```

Add a policy for your Vespera repository:
```json
{
  "default": [{"type": "reject"}],
  "transports": {
    "docker": {
      "ghcr.io/YOUR_USERNAME/vespera-nvidia": [
        {
          "type": "sigstoreSigned",
          "keyless": {
            "issuer": "https://token.actions.githubusercontent.com",
            "subject": "https://github.com/YOUR_USERNAME/vespera"
          }
        }
      ]
    }
  }
}
```

Replace `YOUR_USERNAME` with your GitHub username. Add similar entries for other image variants you use.

**Manual Verification**: To manually verify an image signature before rebasing:

```bash
# Install cosign (if not already installed)
curl -O -L "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64"
sudo install cosign-linux-amd64 /usr/local/bin/cosign
rm cosign-linux-amd64

# Verify the image signature
cosign verify \
  --certificate-identity=https://github.com/YOUR_USERNAME/vespera \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  ghcr.io/YOUR_USERNAME/vespera-nvidia:latest
```

For more details on image signing, verification, and troubleshooting, see [Image Signing Documentation](docs/IMAGE-SIGNING.md).

#### Transition Period: Unsigned Images

During the transition to signed images, unsigned images remain available:

```bash
# Using unsigned images (legacy, not recommended)
rpm-ostree rebase ostree-unverified-registry:ghcr.io/YOUR_USERNAME/vespera-nvidia:latest
```

**Note**: Unsigned images will be deprecated in the future. We recommend migrating to signed images for enhanced security.

### Fresh Installation

For a fresh installation, you'll need to:
1. Install Fedora Kinoite (KDE) or another Fedora Atomic variant
2. Rebase to Vespera using the command above

## Usage

### Maccel Mouse Acceleration

First, add your user to the maccel group for non-root access:

```bash
# Add your user to the maccel group
sudo usermod -aG maccel $USER

# Log out and back in for group changes to take effect
```

After installation, the maccel driver is ready to use:

```bash
# Check if maccel module is loaded
lsmod | grep maccel

# Launch interactive TUI for configuration (recommended)
maccel tui

# Or use command line options
maccel set --sensitivity 1.5
maccel set --curve "0.0 0.0 0.5 0.3 1.0 1.0"
maccel status
```

**Tips**:
- Start with the TUI (`maccel tui`) for an interactive experience
- Sensitivity values typically range from 0.5 (slower) to 2.0 (faster)
- Configuration persists across reboots

### Package Management

Vespera uses standard Fedora Atomic tools:

```bash
# Install additional packages
rpm-ostree install package-name

# Update system
rpm-ostree upgrade

# Rollback if needed
rpm-ostree rollback
```



## Getting Started

1. Fork this repository
2. Customize `vespera-config.yaml` for your needs
3. Push to GitHub - the workflow will build your image automatically
4. Rebase your system to the built image

## Troubleshooting

**Build Issues**: Check GitHub Actions logs for package conflicts or build errors

**Maccel Issues**: Verify user is in `maccel` group (`groups`) and module is loaded (`lsmod | grep maccel`)

**Package Issues**: Ensure removed packages don't have dependencies and added packages exist in Fedora repos

**Signature Verification Issues**: 
- Ensure you're using the correct GitHub username in verification commands
- Check network connectivity to Sigstore services (fulcio.sigstore.dev, rekor.sigstore.dev)
- Verify the image was built and signed successfully in GitHub Actions
- For detailed troubleshooting, see [Image Signing Documentation](docs/IMAGE-SIGNING.md#troubleshooting-guide)

**Migration from Unsigned Images**:
- Use `rpm-ostree rebase ostree-image-signed:docker://...` to switch to signed images
- Rollback is available via `rpm-ostree rollback` if needed
- See [Migration Guide](docs/IMAGE-SIGNING.md#migration-guide) for detailed steps

## Resources

- [Aurora Documentation](https://getaurora.dev/) - Base image documentation
- [Maccel GitHub](https://github.com/Gnarus-G/maccel) - Mouse acceleration driver
- [Fedora Atomic Documentation](https://docs.fedoraproject.org/en-US/fedora-silverblue/) - Immutable OS concepts

## License

This project configuration is provided as-is for personal use. Respects licenses of Aurora (Apache 2.0), Maccel (MIT), and Fedora packages.
