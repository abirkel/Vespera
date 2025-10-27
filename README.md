# Vespera

> *Vespera* (Latin for "evening") - A custom Fedora Atomic image based on Aurora with personalized packages and integrated mouse acceleration.

Vespera is a custom immutable Linux distribution based on [Aurora](https://getaurora.dev/) that adds:

- **Package Customization**: Remove unwanted packages and add preferred alternatives (RPM and Flatpak)
- **Maccel Integration**: Built-in mouse acceleration driver for precise pointer control
- **Automated Builds**: Daily checks for upstream changes, building only when necessary
- **Personal Configuration**: Tailored to your specific needs while maintaining Aurora's immutable benefits

Use `./tools/check-aurora-packages.sh` to see what Aurora provides by default.

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
  variant: "aurora"  # or "aurora-dx" for developer tools
  gpu_variant: "nvidia"  # "nvidia", "nvidia-open", or "main"

packages:
  remove_rpm:
    - sunshine  # Game streaming
  remove_flatpak:
    - org.mozilla.Thunderbird  # Email client
  add_rpm:
    - htop  # Process viewer
  add_flatpak:
    - org.keepassxc.KeePassXC  # Password manager
```

**GPU Variants**:
- `nvidia`: NVIDIA proprietary drivers (default, best performance)
- `nvidia-open`: NVIDIA open-source drivers (RTX 20-series+)
- `main`: Intel/AMD open-source drivers

**Documentation**: [Configuration Guide](docs/CONFIGURATION.md) | [Build Process](docs/BUILD-PROCESS.md) | [GPU Variants](docs/GPU-VARIANT-SUPPORT.md)

## Installation

Rebase your existing Fedora Atomic system to Vespera:

```bash
# Default configuration (aurora + nvidia)
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/YOUR_USERNAME/vespera-nvidia:latest
systemctl reboot
```

**Image names**: `vespera`, `vespera-nvidia`, `vespera-nvidia-open`, `vespera-dx`, `vespera-dx-nvidia`, `vespera-dx-nvidia-open`

### Signature Verification

Images are cryptographically signed using Sigstore. The `ostree-image-signed:` URLs automatically verify signatures.

For manual verification or custom policies, see [Image Signing Documentation](docs/IMAGE-SIGNING.md).

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



## Getting Started

1. Fork this repository
2. Edit `vespera-config.yaml` to customize packages
3. Push changes - GitHub Actions builds your image automatically
4. Rebase your system to the new image

## Troubleshooting

**Build Issues**: Check GitHub Actions logs for package conflicts or build errors

**Maccel Issues**: Verify user is in `maccel` group (`groups`) and module is loaded (`lsmod | grep maccel`)

**Package Issues**: Ensure removed packages don't have dependencies and added packages exist in Fedora repos

**Signature Verification Issues**: Check [Image Signing Documentation](docs/IMAGE-SIGNING.md#troubleshooting-guide) for detailed troubleshooting

## Resources

- [Aurora Documentation](https://getaurora.dev/) - Base image documentation
- [Maccel GitHub](https://github.com/Gnarus-G/maccel) - Mouse acceleration driver
- [Fedora Atomic Documentation](https://docs.fedoraproject.org/en-US/fedora-silverblue/) - Immutable OS concepts

## License

This project configuration is provided as-is for personal use. Respects licenses of Aurora (Apache 2.0), Maccel (MIT), and Fedora packages.
