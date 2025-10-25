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

Use `./tools/check-aurora-packages.sh` to see Aurora's current package list, or check the [static reference](.references/AURORA-CUSTOMIZATIONS.md).

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

[Maccel](https://github.com/Gnarus-G/maccel) is a Linux kernel driver that provides customizable mouse acceleration, similar to what's available on Windows and macOS. Vespera integrates maccel directly into the immutable image:

- **Kernel Module**: Built from source during image creation and integrated into the kernel module tree
- **CLI Tool**: Rust-based command-line interface for configuring acceleration curves
- **TUI Interface**: Interactive terminal UI for easy configuration (`maccel tui`)
- **Auto-loading**: Kernel module loads automatically at boot via `/etc/modules-load.d/`
- **Udev Rules**: Proper device permissions configured for mouse input access
- **User Access**: Non-root access via `maccel` group membership
- **Multi-Stage Build**: Build tools kept out of final image for minimal size

The integration uses a multi-stage Docker build:
1. **Builder Stage**: Compiles kernel module and CLI from source with all build dependencies
2. **Final Stage**: Copies only the built artifacts (kernel module + binary) into the Aurora base
3. **Configuration**: Sets up module loading, udev rules, and group permissions

This approach ensures maccel is fully integrated and ready to use immediately after installation, without requiring DKMS or runtime compilation.

### Automated Builds
- **Daily Checks**: Automatically checks for Aurora and maccel updates
- **Smart Building**: Only builds when upstream changes are detected
- **GitHub Actions**: Fully automated CI/CD pipeline
- **Container Registry**: Built images published to GitHub Container Registry

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
   rpm-ostree rebase ostree-unverified-registry:ghcr.io/YOUR_USERNAME/vespera:latest
   systemctl reboot
   ```

**Note**: Changing GPU variants rebuilds the entire image with a different base. Make sure to choose the variant that matches your hardware before deploying to production systems.

**Documentation**:
- [Configuration Guide](docs/CONFIGURATION.md) - Detailed configuration options and examples
- [Package Inspection Tools](tools/README.md) - Tools to analyze Aurora and package chains
- [Build Process](docs/BUILD-PROCESS.md) - How Vespera is built
- [GPU Variant Support](docs/GPU-VARIANT-SUPPORT.md) - Detailed GPU variant information

## Installation

### Prerequisites
- A system capable of running Fedora Atomic (x86_64 architecture)
- Existing Fedora Atomic/Kinoite installation (for rebasing)

### Rebasing to Vespera

Once the image is built and published, you can rebase your existing Fedora Atomic system:

```bash
# Rebase to Vespera
rpm-ostree rebase ostree-unverified-registry:ghcr.io/YOUR_USERNAME/vespera:latest

# Reboot to apply changes
systemctl reboot
```

### Fresh Installation

For a fresh installation, you'll need to:
1. Install Fedora Kinoite (KDE) or another Fedora Atomic variant
2. Rebase to Vespera using the command above

## Usage

### Maccel Mouse Acceleration

After installation, the maccel driver is ready to use:

```bash
# Check if maccel module is loaded
lsmod | grep maccel

# View maccel help
maccel --help

# Launch interactive TUI for configuration
maccel tui

# Set acceleration sensitivity (command line)
maccel set --sensitivity 1.5

# Apply a custom acceleration curve
maccel set --curve "0.0 0.0 0.5 0.3 1.0 1.0"

# Check current configuration
maccel status
```

**Adding your user to the maccel group** (for non-root access):

```bash
# Add your user to the maccel group
sudo usermod -aG maccel $USER

# Log out and back in for group changes to take effect
```

**Maccel Configuration Tips**:
- Start with the TUI (`maccel tui`) for an interactive experience
- Sensitivity values typically range from 0.5 (slower) to 2.0 (faster)
- Custom curves allow fine-grained control over acceleration behavior
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

## Building Locally

While Vespera is designed for automated GitHub Actions builds, you can build locally:

```bash
# Build the container image
podman build -t vespera:local -f Containerfile .

# Run verification
podman run --rm vespera:local /usr/local/bin/maccel --version
```

## Project Structure

```
vespera/
├── vespera-config.yaml      # Main configuration file
├── Containerfile            # Multi-stage build definition
├── .github/
│   └── workflows/
│       └── build-vespera.yml  # Automated build workflow
├── docs/
│   ├── CONFIGURATION.md     # Configuration guide
│   └── BUILD-PROCESS.md     # Build process documentation
├── .references/             # Reference documentation
│   ├── AURORA-CUSTOMIZATIONS.md
│   ├── MACCEL-BUILD-ANALYSIS.md
│   └── MACCEL-CHANGES-SUMMARY.md
├── tools/                   # Package inspection tools
│   ├── check-aurora-packages.sh
│   ├── check-kinoite-packages.sh
│   ├── compare-packages.sh
│   └── README.md
└── README.md               # This file
```

## How It Works

1. **Change Detection**: GitHub Actions checks daily for updates to Aurora base image and maccel repository
2. **Conditional Build**: Only builds when changes are detected, saving resources
3. **Multi-Stage Build**: 
   - Stage 1: Builds maccel kernel module and CLI from source
   - Stage 2: Customizes Aurora packages and integrates maccel
4. **Verification**: Automated checks confirm maccel integration and package customizations
5. **Publication**: Successfully built images are pushed to GitHub Container Registry

## Development

### Repository Setup

1. Fork or clone this repository
2. Customize `vespera-config.yaml` for your needs
3. Push to GitHub
4. Configure GitHub Actions secrets (GITHUB_TOKEN is automatic)
5. Workflow will run automatically

### Testing Changes

- Push changes to trigger a build
- Monitor GitHub Actions workflow
- Check verification job output
- Review published image in container registry

## Troubleshooting

### Build Failures

Check GitHub Actions logs for:
- Package dependency conflicts
- Maccel build errors
- Base image availability issues

### Runtime Issues

If maccel doesn't work after installation:
- Verify module is loaded: `lsmod | grep maccel`
- Check module loading config: `cat /etc/modules-load.d/maccel.conf`
- Verify user is in maccel group: `groups`
- Check kernel compatibility

### Package Conflicts

If package customization fails:
- Review removed packages for dependencies
- Check that added packages are available in Fedora repos
- Verify Flatpak applications exist on Flathub

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test the build
5. Submit a pull request

## License

This project configuration is provided as-is for personal use. Please respect the licenses of:
- [Aurora](https://github.com/ublue-os/aurora) - Apache 2.0
- [Maccel](https://github.com/Gnarus-G/maccel) - MIT
- Fedora and included packages - Various open source licenses

## Acknowledgments

- **Aurora Team**: For creating an excellent Fedora Atomic variant
- **Maccel Project**: For the mouse acceleration driver
- **Universal Blue**: For the infrastructure and tooling
- **Fedora Project**: For the solid foundation

## Resources

- [Aurora Documentation](https://getaurora.dev/)
- [Maccel GitHub](https://github.com/Gnarus-G/maccel)
- [Fedora Atomic Documentation](https://docs.fedoraproject.org/en-US/fedora-silverblue/)
- [Universal Blue](https://universal-blue.org/)
