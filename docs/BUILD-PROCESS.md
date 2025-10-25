# Vespera Build Process Documentation

This document explains how Vespera is built, including the multi-stage build approach, maccel integration, and the automated GitHub Actions workflow.

## Table of Contents

- [Overview](#overview)
- [Multi-Stage Build Architecture](#multi-stage-build-architecture)
- [Maccel Integration Details](#maccel-integration-details)
- [GitHub Actions Workflow](#github-actions-workflow)
- [Local Building](#local-building)
- [Troubleshooting](#troubleshooting)

## Overview

Vespera uses a containerized build process with the following key features:

1. **Multi-stage Docker build**: Separates build tools from the final image
2. **Aurora base**: Builds on top of Aurora's curated package selection
3. **Package customization**: Removes unwanted packages and adds preferred alternatives
4. **Maccel integration**: Builds and integrates the maccel driver from source
5. **Automated builds**: GitHub Actions checks for upstream changes and builds automatically

## Multi-Stage Build Architecture

The build process uses a multi-stage Containerfile to keep the final image clean and minimal.

### Stage 1: Maccel Builder

```dockerfile
FROM fedora:41 AS maccel-builder
```

**Purpose**: Build maccel kernel module and CLI from source

**What happens**:
1. Install build dependencies (gcc, make, kernel-devel, rust, cargo)
2. Clone maccel repository from GitHub
3. Build kernel module using `make` in the `driver/` directory
4. Build CLI tool using `cargo build --bin maccel --release`

**Output artifacts**:
- `driver/maccel.ko` - Compiled kernel module
- `target/release/maccel` - Compiled CLI binary

**Why separate stage?**
- Keeps build tools (gcc, rust, cargo) out of final image
- Reduces final image size significantly
- Follows Docker best practices

### Stage 2: Aurora Customization

```dockerfile
FROM ghcr.io/ublue-os/${AURORA_VARIANT}:${FEDORA_VERSION}
```

**Purpose**: Customize Aurora and integrate maccel

**What happens**:
1. Start with Aurora base image (aurora or aurora-dx)
2. Install yq for YAML parsing
3. Read `vespera-config.yaml` for customization instructions
4. Remove specified RPM packages using `rpm-ostree override remove`
5. Add specified RPM packages using `rpm-ostree install`
6. Remove specified Flatpak applications
7. Add specified Flatpak applications
8. Copy maccel artifacts from builder stage
9. Install maccel kernel module to `/usr/lib/modules/*/extra/maccel/`
10. Run `depmod` to update module dependencies
11. Install maccel CLI to `/usr/local/bin/maccel`
12. Install udev rules for device permissions
13. Configure module auto-loading via `/etc/modules-load.d/`
14. Create `maccel` group for non-root access
15. Clean up temporary files
16. Commit ostree container

**Output**: Final Vespera image ready for use

## Maccel Integration Details

### Why Maccel Integration is Complex

Maccel consists of two components that need careful integration:

1. **Kernel Module**: Must be compiled for the exact kernel version in the image
2. **CLI Tool**: Rust application that needs to be compiled from source

### Build Process Breakdown

#### 1. Kernel Module Build

```bash
# In builder stage
cd /tmp/maccel/driver
make
```

This produces `maccel.ko` compiled for the Fedora 41 kernel.

**Key considerations**:
- Must match the kernel version in Aurora base image
- Requires kernel headers and development tools
- Uses standard Linux kernel module build system

#### 2. CLI Tool Build

```bash
# In builder stage
cd /tmp/maccel
cargo build --bin maccel --release
```

This produces the `maccel` binary with TUI and CLI functionality.

**Key considerations**:
- Requires Rust toolchain (cargo, rustc)
- Release build for optimization
- Binary is statically linked (mostly) for portability

#### 3. Integration into Final Image

```bash
# Copy kernel module
KERNEL_VERSION=$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')
cp maccel.ko /usr/lib/modules/${KERNEL_VERSION}/extra/maccel/
depmod -a ${KERNEL_VERSION}

# Copy CLI binary
cp maccel /usr/local/bin/maccel
chmod +x /usr/local/bin/maccel

# Install udev rules
cp 99-maccel.rules /etc/udev/rules.d/

# Configure auto-loading
echo "maccel" > /etc/modules-load.d/maccel.conf

# Create group
groupadd -r maccel
```

**Why this approach?**
- **No DKMS needed**: Module is pre-compiled for the specific kernel
- **No runtime compilation**: Everything is ready to use immediately
- **Immutable OS friendly**: Works with Fedora Atomic's immutable architecture
- **Clean separation**: Build tools don't bloat the final image

### Alternative Approaches Considered

#### Akmods (Rejected)
- **Pros**: Standard for Fedora Atomic, handles kernel updates
- **Cons**: Complex RPM packaging, requires akmods infrastructure, larger image
- **Why rejected**: Multi-stage build is simpler and produces smaller images

#### DKMS (Rejected)
- **Pros**: Standard Linux approach, well-documented
- **Cons**: Requires runtime compilation, not ideal for immutable OS
- **Why rejected**: Doesn't fit immutable OS model, requires build tools at runtime

#### Pre-built RPMs (Rejected)
- **Pros**: Standard package management
- **Cons**: Need to maintain RPM repository, version synchronization issues
- **Why rejected**: More maintenance overhead, less flexible

## GitHub Actions Workflow

The automated build process consists of three jobs:

### Job 1: Detect Changes

**Purpose**: Determine if a build is necessary

**Steps**:
1. Check Aurora base image for new versions (using `skopeo inspect`)
2. Check maccel repository for new commits (using `git ls-remote`)
3. Compare with previous build metadata
4. Decide whether to build based on:
   - Force build flag (manual trigger)
   - Push to main branch
   - Aurora version change
   - Maccel commit change
   - No previous build metadata

**Outputs**:
- `should_build`: Boolean indicating if build is needed
- `aurora_version`: Current Aurora image digest
- `maccel_commit`: Current maccel commit hash
- `build_date`: Date stamp for tagging

**Why this matters**:
- Saves resources by skipping unnecessary builds
- Ensures builds only happen when there are actual changes
- Provides transparency about what triggered the build

### Job 2: Build

**Purpose**: Build the Vespera image

**Runs**: Only if `should_build` is true

**Steps**:
1. Checkout repository
2. Install build tools (buildah, podman, skopeo)
3. Build image using `buildah bud`
4. Tag with date and 'latest'
5. Add metadata labels:
   - Build date
   - Aurora digest
   - Maccel commit
   - Git revision
6. Run basic validation
7. Upload build metadata as artifact

**Build command**:
```bash
buildah bud \
  --format docker \
  --layers \
  --tag ${IMAGE_REGISTRY}/${IMAGE_NAME}:${BUILD_DATE} \
  --tag ${IMAGE_REGISTRY}/${IMAGE_NAME}:latest \
  --label "org.vespera.build.date=$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
  --label "org.vespera.aurora.digest=${AURORA_DIGEST}" \
  --label "org.vespera.maccel.commit=${MACCEL_COMMIT}" \
  .
```

**Why buildah?**
- Native to Fedora ecosystem
- Works well with OCI images
- Good integration with Fedora Atomic tooling

### Job 3: Publish

**Purpose**: Push the built image to GitHub Container Registry

**Runs**: Only if build succeeded

**Steps**:
1. Rebuild image (artifacts don't persist between jobs)
2. Authenticate to GitHub Container Registry
3. Push both tags (date and latest)
4. Generate build summary with:
   - Build information
   - Upstream versions
   - Pull command
   - Rebase command
5. Store build metadata as JSON

**Registry authentication**:
```bash
echo "${{ secrets.GITHUB_TOKEN }}" | buildah login -u ${{ github.actor }} --password-stdin ghcr.io
```

**Why GitHub Container Registry?**
- Free for public repositories
- Integrated with GitHub
- Good performance and reliability
- Standard OCI registry

### Workflow Triggers

The workflow runs on:

1. **Schedule**: Daily at 2 AM UTC
   ```yaml
   schedule:
     - cron: '0 2 * * *'
   ```

2. **Manual trigger**: Via workflow_dispatch
   - Includes option to force build even without changes

3. **Push to main**: When Containerfile or config changes
   ```yaml
   push:
     branches:
       - main
     paths:
       - 'Containerfile'
       - 'vespera-config.yaml'
       - '.github/workflows/build-vespera.yml'
   ```

## Local Building

You can build Vespera locally for testing or development.

### Prerequisites

- Podman or Docker installed
- Sufficient disk space (5-10 GB)
- Linux system (or WSL2 on Windows)

### Basic Build

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/vespera.git
cd vespera

# Build with podman
podman build -t vespera:local -f Containerfile .

# Or with docker
docker build -t vespera:local -f Containerfile .
```

### Build with Specific Aurora Variant

```bash
# Build with aurora-dx
podman build \
  --build-arg AURORA_VARIANT=aurora-dx \
  -t vespera:local-dx \
  -f Containerfile .
```

### Testing the Built Image

```bash
# Check if maccel is present
podman run --rm vespera:local /usr/local/bin/maccel --version

# Check kernel module
podman run --rm vespera:local ls -la /usr/lib/modules/*/extra/maccel/

# Interactive shell
podman run --rm -it vespera:local /bin/bash
```

### Build Time Expectations

- **First build**: 15-30 minutes (downloads base image, builds maccel)
- **Subsequent builds**: 5-10 minutes (uses cached layers)
- **With changes**: Varies based on what changed

### Build Caching

Docker/Podman cache layers to speed up builds:
- Base image pulls are cached
- Maccel builder stage is cached if source hasn't changed
- Package installations are cached if config hasn't changed

To force a clean build:
```bash
podman build --no-cache -t vespera:local -f Containerfile .
```

## Troubleshooting

### Build Failures

#### Package Not Found

**Symptom**: `rpm-ostree install` fails with "package not found"

**Causes**:
- Typo in package name
- Package not available in Fedora repositories
- Package name changed between Fedora versions

**Solution**:
```bash
# Search for package
dnf search package-name

# Check exact package name
dnf info package-name
```

#### Dependency Conflicts

**Symptom**: `rpm-ostree override remove` fails with dependency errors

**Causes**:
- Other packages depend on the package being removed
- Removing a package that's required by the system

**Solution**:
- Check dependencies: `rpm -q --whatrequires package-name`
- Remove dependent packages first
- Consider keeping the package

#### Maccel Build Failure

**Symptom**: Kernel module or CLI fails to build

**Causes**:
- Kernel headers mismatch
- Missing build dependencies
- Maccel source code changes

**Solution**:
- Check builder stage logs
- Verify kernel-devel version matches kernel version
- Check maccel repository for build issues
- Try pinning to a specific maccel commit

#### Flatpak Installation Failure

**Symptom**: Flatpak install fails

**Causes**:
- Application not available on Flathub
- Typo in application ID
- Flathub connectivity issues

**Solution**:
- Search Flathub: https://flathub.org/
- Verify exact application ID
- Check Flathub status

### GitHub Actions Failures

#### Authentication Failure

**Symptom**: Cannot push to registry

**Causes**:
- GITHUB_TOKEN permissions issue
- Registry authentication failure

**Solution**:
- Check workflow permissions in repository settings
- Verify GITHUB_TOKEN has package write permissions
- Check if ghcr.io is accessible

#### Change Detection Issues

**Symptom**: Builds when they shouldn't, or doesn't build when they should

**Causes**:
- Previous metadata not found
- Comparison logic error
- Force build flag set

**Solution**:
- Check previous build metadata in registry
- Review change detection job logs
- Manually trigger with force build if needed

#### Out of Disk Space

**Symptom**: Build fails with disk space error

**Causes**:
- GitHub Actions runner out of space
- Large image size
- Build artifacts accumulating

**Solution**:
- Clean up build artifacts in workflow
- Optimize image size (remove unnecessary packages)
- Use `--squash` flag to reduce layers

### Runtime Issues

#### Maccel Module Not Loading

**Symptom**: `lsmod | grep maccel` shows nothing

**Causes**:
- Module not installed correctly
- Kernel version mismatch
- Module loading configuration missing

**Solution**:
```bash
# Check if module exists
ls -la /usr/lib/modules/*/extra/maccel/

# Check module loading config
cat /etc/modules-load.d/maccel.conf

# Try loading manually
sudo modprobe maccel

# Check kernel logs
sudo dmesg | grep maccel
```

#### Maccel CLI Permission Denied

**Symptom**: `maccel` command fails with permission error

**Causes**:
- User not in maccel group
- Udev rules not applied
- Device permissions incorrect

**Solution**:
```bash
# Add user to maccel group
sudo usermod -aG maccel $USER

# Log out and back in

# Check group membership
groups

# Check udev rules
cat /etc/udev/rules.d/99-maccel.rules

# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger
```

#### Package Conflicts After Rebase

**Symptom**: System won't boot or has package conflicts

**Causes**:
- Removed package that was required
- Conflicting package versions
- Broken dependencies

**Solution**:
```bash
# Rollback to previous deployment
rpm-ostree rollback

# Reboot
systemctl reboot

# After reboot, check what went wrong
rpm-ostree status
journalctl -b -1  # Check previous boot logs
```

## Advanced Topics

### Customizing the Build Process

#### Adding Build Arguments

Modify `Containerfile` to accept additional build arguments:

```dockerfile
ARG CUSTOM_OPTION=default_value
```

Use in GitHub Actions:

```yaml
buildah bud \
  --build-arg CUSTOM_OPTION=custom_value \
  ...
```

#### Multi-Architecture Builds

To build for multiple architectures (x86_64, aarch64):

```yaml
# In GitHub Actions
- name: Set up QEMU
  uses: docker/setup-qemu-action@v3

- name: Build multi-arch
  run: |
    buildah bud \
      --platform linux/amd64,linux/arm64 \
      ...
```

#### Custom Registry

To use a different container registry:

1. Update `vespera-config.yaml`:
   ```yaml
   build:
     registry: "docker.io"  # or quay.io, etc.
     image_name: "username/vespera"
   ```

2. Update GitHub Actions secrets with registry credentials

3. Modify authentication step in workflow

### Performance Optimization

#### Reducing Build Time

1. **Use layer caching**: Order Containerfile commands from least to most frequently changing
2. **Parallel builds**: Use `--jobs` flag with buildah
3. **Smaller base**: Use aurora instead of aurora-dx if you don't need dev tools

#### Reducing Image Size

1. **Remove unnecessary packages**: Audit what you actually need
2. **Clean up caches**: Remove package manager caches
3. **Squash layers**: Use `--squash` flag (trade-off: loses layer caching)

```bash
buildah bud --squash -t vespera:small -f Containerfile .
```

### Security Considerations

#### Image Signing

Consider signing your images for verification:

```bash
# Generate signing key
cosign generate-key-pair

# Sign image
cosign sign --key cosign.key ${IMAGE_REGISTRY}/${IMAGE_NAME}:${TAG}
```

#### Vulnerability Scanning

Add vulnerability scanning to your workflow:

```yaml
- name: Scan image
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ${{ env.IMAGE_REGISTRY }}/${{ env.IMAGE_NAME }}:latest
    format: 'sarif'
    output: 'trivy-results.sarif'
```

#### Supply Chain Security

- Pin base image to specific digest instead of tag
- Verify maccel source integrity
- Use dependabot for dependency updates

## Further Reading

- [Containerfile Reference](https://github.com/containers/common/blob/main/docs/Containerfile.5.md)
- [Buildah Documentation](https://buildah.io/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Fedora Atomic Documentation](https://docs.fedoraproject.org/en-US/fedora-silverblue/)
- [rpm-ostree Documentation](https://coreos.github.io/rpm-ostree/)
