# Vespera Configuration Guide

This guide provides detailed information about configuring Vespera through the `vespera-config.yaml` file.

## Table of Contents

- [Base Configuration](#base-configuration)
- [Build Configuration](#build-configuration)
- [Package Customization](#package-customization)
- [Maccel Integration](#maccel-integration)
- [Common Configuration Examples](#common-configuration-examples)
- [What Aurora Already Includes](#what-aurora-already-includes)

## Base Configuration

### Choosing Your Aurora Variant

Vespera can be built on either Aurora variant:

**Note**: Each variant also comes in three GPU-specific versions. See [GPU Variant Selection](#gpu-variant-selection) below.

#### aurora (Standard)
The standard Aurora variant includes:
- KDE Plasma desktop environment
- Essential system utilities and tools
- Backup tools (Borg, Restic, Rclone)
- Hardware support (Tailscale, OpenRazer, printer drivers)
- Fonts (Nerd Fonts, JetBrains Mono, Inter)
- KDE applications (Gwenview, Haruna, Okular, etc.)
- Firefox and Thunderbird (as Flatpaks)

**Best for**: General desktop use, gaming, multimedia

#### aurora-dx (Developer Experience)
The DX variant includes everything in standard Aurora PLUS:
- Container tools (Docker, Podman, Incus, LXC)
- Virtualization (QEMU, libvirt, virt-manager)
- Development tools (VS Code, Android tools)
- System monitoring (Cockpit, bpftrace, sysprof)
- AMD ROCm support

**Best for**: Software development, DevOps, system administration

```yaml
base:
  variant: "aurora"  # or "aurora-dx"
  gpu_variant: "nvidia"  # See GPU Variant Selection below
  registry: "ghcr.io/ublue-os"
```

### GPU Variant Selection

Aurora provides three GPU-specific variants to optimize driver support for different hardware. Vespera respects this choice and builds on the appropriate GPU variant.

#### Available GPU Variants

**nvidia** (default)
- NVIDIA proprietary drivers
- Best performance and compatibility for NVIDIA GPUs
- Supports all NVIDIA GPU generations
- Recommended for most NVIDIA users

**nvidia-open**
- NVIDIA open-source drivers
- For newer NVIDIA GPUs (Turing architecture and later: RTX 20-series, RTX 30-series, RTX 40-series)
- Benefits from open-source development model
- May have better Wayland support on newer hardware

**main**
- Intel and AMD open-source drivers
- For Intel integrated graphics (Iris, UHD, etc.)
- For AMD GPUs (Radeon RX series, etc.)
- Native open-source driver support

#### Hardware-Specific Recommendations

**If you have an NVIDIA GPU**:
```yaml
base:
  variant: "aurora"
  gpu_variant: "nvidia"  # Default, best compatibility
```

Use `nvidia-open` only if:
- You have RTX 20-series or newer (Turing, Ampere, Ada Lovelace architectures)
- You want to use open-source drivers
- You're experiencing Wayland issues with proprietary drivers

**If you have an Intel GPU**:
```yaml
base:
  variant: "aurora"
  gpu_variant: "main"  # Intel uses open-source drivers
```

**If you have an AMD GPU**:
```yaml
base:
  variant: "aurora"
  gpu_variant: "main"  # AMD uses open-source drivers (AMDGPU)
```

**If you have a hybrid system** (e.g., Intel + NVIDIA):
- Choose based on your **primary GPU** (the one driving your display)
- For NVIDIA Optimus laptops, typically use `nvidia` variant
- The system will handle GPU switching automatically

#### How GPU Variants Work

The GPU variant determines which Aurora base image Vespera uses:
- `nvidia` → builds from `ghcr.io/ublue-os/aurora-nvidia:41`
- `nvidia-open` → builds from `ghcr.io/ublue-os/aurora-nvidia-open:41`
- `main` → builds from `ghcr.io/ublue-os/aurora:41`

The variant combination also determines your final Vespera image name following Aurora's convention:
- `aurora` + `nvidia` → `ghcr.io/username/vespera-nvidia:latest`
- `aurora-dx` + `nvidia` → `ghcr.io/username/vespera-dx-nvidia:latest`
- `aurora` + `main` → `ghcr.io/username/vespera:latest`

All Vespera features (package customization, maccel integration, etc.) work identically across all GPU variants. The only difference is the underlying GPU driver stack.

#### Changing GPU Variants

To switch GPU variants:

1. Edit `vespera-config.yaml`:
   ```yaml
   base:
     variant: "aurora"
     gpu_variant: "main"  # Changed from nvidia to main
   ```

2. Commit and push to trigger a rebuild

3. After the build completes, rebase your system to the new image name:
   ```bash
   # For main GPU variant (produces vespera:latest)
   rpm-ostree rebase ostree-unverified-registry:ghcr.io/YOUR_USERNAME/vespera:latest
   systemctl reboot
   ```

**Important**: Changing GPU variants rebuilds the entire image with different drivers AND changes the image name. Only change this if you've changed your hardware or need different driver support.

## Build Configuration

### Image Naming Convention

Vespera follows Aurora's naming convention, creating different images for each variant combination:

| Aurora Variant | GPU Variant | Final Image Name |
|----------------|-------------|------------------|
| `aurora` | `main` | `vespera` |
| `aurora` | `nvidia` | `vespera-nvidia` |
| `aurora` | `nvidia-open` | `vespera-nvidia-open` |
| `aurora-dx` | `main` | `vespera-dx` |
| `aurora-dx` | `nvidia` | `vespera-dx-nvidia` |
| `aurora-dx` | `nvidia-open` | `vespera-dx-nvidia-open` |

This allows you to have multiple Vespera variants simultaneously, just like Aurora.

### Build Strategy

Configure how many variants to build:

```yaml
build:
  # Build strategy: "single" or "matrix"
  strategy: "single"  # Default: only builds your specific configuration
  
  # Base image name (modified based on variant)
  image_name: "vespera"
  
  # Registry to publish to
  registry: "ghcr.io"
```

#### Single Build Strategy (Recommended)

```yaml
build:
  strategy: "single"
```

**Behavior**:
- Builds only the variant/GPU combination specified in your `base` configuration
- Efficient resource usage - only builds what you need
- Produces one image with Aurora-style naming
- Recommended for personal use

**Example**: With `aurora` + `nvidia`, produces `ghcr.io/username/vespera-nvidia:latest`

#### Matrix Build Strategy (Future)

```yaml
build:
  strategy: "matrix"
```

**Behavior**:
- Would build all 6 possible variant/GPU combinations
- Higher resource usage but provides complete coverage
- Useful for projects supporting multiple configurations

**Note**: Matrix builds are not yet implemented but the configuration option is reserved for future use.

### Registry Configuration

```yaml
build:
  registry: "ghcr.io"  # GitHub Container Registry (default)
  # registry: "docker.io"  # Docker Hub
  # registry: "quay.io"   # Red Hat Quay
```

Most users should stick with GitHub Container Registry (`ghcr.io`) as it's free and integrates well with GitHub Actions.

## Package Customization

### Understanding Package Management

Vespera uses two package systems:
1. **RPM packages**: System-level packages integrated into the immutable image
2. **Flatpak applications**: Containerized applications with sandboxing

### Removing Packages

Only remove packages you're certain you don't need. Removing the wrong packages can break dependencies.

#### Safe RPM Packages to Remove

```yaml
packages:
  remove_rpm:
    # Hardware-specific (safe if you don't have the hardware)
    - sunshine  # Game streaming server
    - openrazer-daemon  # Razer peripheral support
    - virtualbox-guest-additions  # VirtualBox support
    
    # Backup tools (safe if using alternatives)
    - borgbackup  # Borg backup
    - restic  # Restic backup
    - rclone  # Cloud sync
    
    # VPN (safe if using alternatives)
    - tailscale  # Tailscale VPN
    - wireguard-tools  # WireGuard VPN
    
    # Terminal tools (safe if you prefer alternatives)
    - tmux  # Terminal multiplexer
    - fish  # Fish shell
    - zsh  # Zsh shell
```

#### Safe Flatpaks to Remove

```yaml
packages:
  remove_flatpak:
    # Email clients (safe if you don't use desktop email)
    - org.mozilla.Thunderbird
    - org.kde.kontact
    
    # Utilities you might not need
    - org.kde.kweather  # Weather app
    - org.kde.kcalc  # Calculator
    - org.kde.kclock  # Clock/timer
    - org.deskflow.deskflow  # KVM software
    
    # Hardware-specific
    - io.github.pwr_solaar.solaar  # Logitech device manager
    
    # Backup tools
    - com.borgbase.Vorta  # Borg backup GUI
    - org.gnome.DejaDup  # Backup tool
```

### Adding Packages

Before adding packages, check if Aurora already includes them. See [What Aurora Already Includes](#what-aurora-already-includes).

#### Useful RPM Additions

```yaml
packages:
  add_rpm:
    # Modern CLI tools
    - neovim  # Modern Vim
    - htop  # Process viewer
    - btop  # Modern resource monitor
    - bat  # Cat with syntax highlighting
    - ripgrep  # Fast grep
    - fd-find  # Fast find
    - eza  # Modern ls (formerly exa)
    - ncdu  # Disk usage analyzer
    
    # System utilities
    - tree  # Directory tree viewer
    - jq  # JSON processor
    - yq  # YAML processor
    
    # Network tools
    - nmap  # Network scanner
    - tcpdump  # Packet analyzer
    - iperf3  # Network performance
```

#### Popular Flatpak Additions

```yaml
packages:
  add_flatpak:
    # Communication
    - com.spotify.Client  # Music streaming
    - com.discordapp.Discord  # Gaming/community chat
    - com.slack.Slack  # Team communication
    - us.zoom.Zoom  # Video conferencing
    - org.signal.Signal  # Secure messaging
    
    # Creative tools
    - org.gimp.GIMP  # Image editor
    - org.inkscape.Inkscape  # Vector graphics
    - org.blender.Blender  # 3D creation
    - com.obsproject.Studio  # Video recording/streaming
    - org.audacityteam.Audacity  # Audio editor
    
    # Productivity
    - org.libreoffice.LibreOffice  # Office suite
    - md.obsidian.Obsidian  # Note-taking
    - org.keepassxc.KeePassXC  # Password manager
    
    # Development (if not using aurora-dx)
    - com.visualstudio.code  # VS Code
    - io.podman_desktop.PodmanDesktop  # Podman GUI
    
    # Gaming
    - com.valvesoftware.Steam  # Gaming platform
    - com.heroicgameslauncher.hgl  # Epic/GOG launcher
    - net.lutris.Lutris  # Game manager
    
    # Media
    - org.videolan.VLC  # Media player
    - io.mpv.Mpv  # Minimal media player
```

## Maccel Integration

Maccel is automatically integrated into Vespera. You don't need to configure anything in `vespera-config.yaml`.

### What Gets Installed

- **Kernel module**: `/usr/lib/modules/*/extra/maccel/maccel.ko`
- **CLI binary**: `/usr/local/bin/maccel`
- **Udev rules**: `/etc/udev/rules.d/99-maccel.rules`
- **Module loading**: `/etc/modules-load.d/maccel.conf`
- **System group**: `maccel` group for non-root access

### Using Maccel After Installation

```bash
# Add your user to the maccel group
sudo usermod -aG maccel $USER

# Log out and back in, then use maccel
maccel tui  # Interactive configuration
maccel --help  # View all options
```

## Common Configuration Examples

### Minimal Configuration (Keep Most of Aurora)

```yaml
base:
  variant: "aurora"
  gpu_variant: "nvidia"  # Change based on your hardware
  registry: "ghcr.io/ublue-os"

build:
  strategy: "single"  # Only build what you need
  registry: "ghcr.io"
  image_name: "vespera"  # Will become vespera-nvidia

packages:
  remove_rpm:
    - sunshine  # Don't need game streaming
  
  remove_flatpak:
    - org.mozilla.Thunderbird  # Don't use email client
  
  add_rpm:
    - htop  # Prefer htop over other monitors
  
  add_flatpak:
    - com.spotify.Client  # Add music streaming

maccel:
  repository: "https://github.com/Gnarus-G/maccel"
  enabled: true
```

**Result**: Produces `ghcr.io/username/vespera-nvidia:latest`

### Developer Configuration (Using aurora-dx)

```yaml
base:
  variant: "aurora-dx"  # Use developer variant
  gpu_variant: "nvidia"  # Change based on your hardware
  registry: "ghcr.io/ublue-os"

build:
  strategy: "single"
  registry: "ghcr.io"
  image_name: "vespera"  # Will become vespera-dx-nvidia

packages:
  remove_rpm:
    - sunshine
    - openrazer-daemon
  
  remove_flatpak:
    - org.mozilla.Thunderbird
    - org.kde.kweather
  
  add_rpm:
    - neovim
    - htop
    - btop
    - ripgrep
    - fd-find
    - bat
  
  add_flatpak:
    - com.slack.Slack
    - md.obsidian.Obsidian
    - org.keepassxc.KeePassXC

maccel:
  repository: "https://github.com/Gnarus-G/maccel"
  enabled: true
```

**Result**: Produces `ghcr.io/username/vespera-dx-nvidia:latest`

### Gaming Configuration

```yaml
base:
  variant: "aurora"  # Standard variant is fine for gaming
  gpu_variant: "nvidia"  # Most gaming PCs have NVIDIA GPUs
  registry: "ghcr.io/ublue-os"

build:
  strategy: "single"
  registry: "ghcr.io"
  image_name: "vespera"  # Will become vespera-nvidia

packages:
  remove_rpm:
    - borgbackup
    - restic
  
  remove_flatpak:
    - org.mozilla.Thunderbird
    - org.kde.kontact
  
  add_rpm:
    - htop
  
  add_flatpak:
    - com.valvesoftware.Steam
    - com.heroicgameslauncher.hgl
    - net.lutris.Lutris
    - com.discordapp.Discord
    - com.spotify.Client
    - com.obsproject.Studio  # For streaming

maccel:
  repository: "https://github.com/Gnarus-G/maccel"
  enabled: true
```

**Result**: Produces `ghcr.io/username/vespera-nvidia:latest`

### Minimal/Lightweight Configuration

```yaml
base:
  variant: "aurora"
  gpu_variant: "nvidia"  # Change based on your hardware
  registry: "ghcr.io/ublue-os"

build:
  strategy: "single"
  registry: "ghcr.io"
  image_name: "vespera"  # Will become vespera-nvidia

packages:
  # Remove as much as possible
  remove_rpm:
    - sunshine
    - openrazer-daemon
    - tailscale
    - borgbackup
    - restic
    - rclone
    - virtualbox-guest-additions
  
  remove_flatpak:
    - org.mozilla.Thunderbird
    - org.kde.kontact
    - org.kde.kweather
    - org.kde.kcalc
    - org.kde.kclock
    - io.github.pwr_solaar.solaar
    - com.borgbase.Vorta
    - org.gnome.DejaDup
    - org.deskflow.deskflow
  
  # Only add essentials
  add_rpm:
    - htop
  
  add_flatpak:
    - com.spotify.Client

maccel:
  repository: "https://github.com/Gnarus-G/maccel"
  enabled: true
```

**Result**: Produces `ghcr.io/username/vespera-nvidia:latest`

## What Aurora Already Includes

Before adding packages, check if Aurora already includes them. Use `./tools/check-aurora-packages.sh` to see the current list, or check the [static reference](../.references/AURORA-CUSTOMIZATIONS.md).

### Key Aurora Packages (All Variants)

**System Utilities**: fastfetch, glow, gum, make, tmux, wireguard-tools, wl-clipboard

**Shells & Prompts**: fish, zsh, starship

**Development**: git, git-credential-libsecret, python3-pip

**Backup**: borgbackup, restic, rclone

**Fonts**: JetBrains Mono, Fira Code Nerd Font, Inter, Nerd Fonts Symbols

**Hardware**: tailscale, openrazer-daemon, sunshine, virtualbox-guest-additions

**KDE Apps** (Flatpak): Gwenview, Haruna, Okular, Kontact, KWeather, KCalc, KClock

**Utilities** (Flatpak): Firefox, Thunderbird, Flatseal, Warehouse, DejaDup, Vorta

### Additional in aurora-dx

**Containers**: docker-ce, podman-compose, incus, lxc

**Virtualization**: qemu, libvirt, virt-manager, virt-viewer

**Development**: code (VS Code), android-tools, flatpak-builder

**Monitoring**: cockpit, bpftrace, sysprof, iotop

**Fonts**: Adobe Source Code Pro, Cascadia Code, IBM Plex Mono, Intel One Mono

## Troubleshooting

### Package Not Found

If a package fails to install:
- Verify the package name is correct
- Check if it's available in Fedora repositories
- For Flatpaks, verify it exists on Flathub

### Dependency Conflicts

If removing a package causes dependency issues:
- Check what depends on that package: `rpm -q --whatrequires package-name`
- Consider keeping the package or removing dependent packages too

### Build Failures

Check GitHub Actions logs for:
- Package names (typos or incorrect names)
- Dependency conflicts
- Repository availability

## Further Reading

- [Aurora Documentation](https://getaurora.dev/)
- [Package Inspection Tools](../tools/README.md) - Analyze current Aurora packages
- [Fedora Packages Search](https://packages.fedoraproject.org/)
- [Flathub](https://flathub.org/)
