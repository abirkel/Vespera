# GPU Variant Support

Vespera now supports Aurora's GPU variants, allowing you to choose the appropriate base image for your hardware.

## Available GPU Variants

Aurora provides three GPU variants optimized for different hardware:

### `nvidia` - NVIDIA Proprietary Drivers (DEFAULT)
- Uses NVIDIA's proprietary drivers for best performance and compatibility
- **Best for**: All NVIDIA GPUs (GeForce, Quadro, Tesla)
- **Use cases**: Gaming, CUDA workloads, professional graphics, general desktop use
- **Compatibility**: All NVIDIA GPU generations
- **Recommended**: For most NVIDIA users due to proven stability and performance

### `nvidia-open` - NVIDIA Open Source Drivers
- Uses NVIDIA's open source kernel modules (released by NVIDIA, not nouveau)
- **Best for**: Newer NVIDIA GPUs (Turing architecture and later)
- **Supported GPUs**: RTX 20-series, RTX 30-series, RTX 40-series, and newer
- **Benefits**: Better Wayland support, open-source development model, community contributions
- **Note**: Not recommended for older GPUs (GTX 10-series and earlier)

### `main` - Intel/AMD Open Source Drivers
- Uses Mesa open source drivers (Intel i915/Xe, AMD AMDGPU)
- **Best for**: Intel integrated graphics and AMD GPUs
- **Intel GPUs**: All Intel integrated graphics (UHD, Iris, Xe)
- **AMD GPUs**: All modern AMD GPUs (Radeon RX 400-series and newer)
- **Benefits**: Native open-source support, excellent Wayland compatibility, no proprietary drivers needed

## Hardware-Specific Recommendations

### If You Have an NVIDIA GPU

**For most NVIDIA users** (recommended):
```yaml
base:
  gpu_variant: "nvidia"  # Proprietary drivers, best compatibility
```

**For RTX 20-series or newer** (optional):
```yaml
base:
  gpu_variant: "nvidia-open"  # Open-source drivers, newer GPUs only
```

Use `nvidia-open` only if:
- You have RTX 20-series or newer (Turing, Ampere, Ada Lovelace)
- You prefer open-source drivers
- You're experiencing Wayland-specific issues with proprietary drivers

**Do NOT use** `nvidia-open` if:
- You have GTX 10-series or older
- You need maximum stability for production work
- You're unsure about your GPU generation

### If You Have an Intel GPU

```yaml
base:
  gpu_variant: "main"  # Intel uses open-source drivers
```

Intel GPUs always use open-source drivers (i915 or Xe). This includes:
- Intel UHD Graphics (11th gen and newer)
- Intel Iris Xe Graphics
- Intel HD Graphics (older generations)
- Intel Arc Graphics (discrete GPUs)

### If You Have an AMD GPU

```yaml
base:
  gpu_variant: "main"  # AMD uses open-source AMDGPU drivers
```

Modern AMD GPUs use the open-source AMDGPU driver. This includes:
- Radeon RX 7000-series (RDNA 3)
- Radeon RX 6000-series (RDNA 2)
- Radeon RX 5000-series (RDNA)
- Radeon RX 400/500-series (Polaris)
- Older AMD GPUs may use the legacy radeon driver

### If You Have a Hybrid System

**Laptop with Intel + NVIDIA** (Optimus):
```yaml
base:
  gpu_variant: "nvidia"  # Choose based on primary GPU
```

**Desktop with integrated + discrete GPU**:
- Choose based on which GPU drives your display
- If using NVIDIA for display: use `nvidia`
- If using Intel/AMD for display: use `main`

The system will handle GPU switching automatically via PRIME or similar technologies.

## Configuration

The GPU variant is configured in `vespera-config.yaml`:

```yaml
base:
  variant: "aurora"  # or "aurora-dx"
  gpu_variant: "nvidia"  # main, nvidia, or nvidia-open
  registry: "ghcr.io/ublue-os"
```

## How It Works

### 1. Configuration Parsing

The GitHub Actions workflow reads the `gpu_variant` from `vespera-config.yaml`:

```bash
GPU_VARIANT=$(yq eval '.base.gpu_variant // "nvidia"' vespera-config.yaml)
```

### 2. Validation

The workflow validates that the GPU variant is one of the supported values:

```bash
if [[ ! "$GPU_VARIANT" =~ ^(main|nvidia|nvidia-open)$ ]]; then
  echo "::error::Invalid GPU variant: $GPU_VARIANT"
  exit 1
fi
```

### 3. Base Image Selection

The GPU variant is combined with the Aurora variant to construct the full base image name:

```bash
FULL_IMAGE="${AURORA_BASE_IMAGE}-${AURORA_VARIANT}-${GPU_VARIANT}"
# Examples:
# - ghcr.io/ublue-os/aurora-nvidia:latest
# - ghcr.io/ublue-os/aurora-dx-nvidia-open:latest
# - ghcr.io/ublue-os/aurora-main:latest
```

### 4. Build Arguments

The GPU variant is passed to the container build as a build argument:

```bash
buildah bud \
  --build-arg AURORA_VARIANT=${AURORA_VARIANT} \
  --build-arg GPU_VARIANT=${GPU_VARIANT} \
  ...
```

### 5. Containerfile Usage

The Containerfile uses the GPU variant in the FROM statement:

```dockerfile
ARG AURORA_VARIANT=aurora
ARG GPU_VARIANT=nvidia

FROM ghcr.io/ublue-os/${AURORA_VARIANT}-${GPU_VARIANT}:${FEDORA_VERSION}
```

## Validation

### Local Validation

You can validate your GPU variant configuration locally using the provided script:

```powershell
.\validate-gpu-variant.ps1
```

This script will:
- Read the GPU variant from `vespera-config.yaml`
- Validate that it's a supported value
- Check Containerfile compatibility
- Display information about the selected GPU variant

### Containerfile Validation

The Containerfile validation script also checks GPU variant support:

```powershell
.\validate-containerfile.ps1
```

This ensures:
- `GPU_VARIANT` ARG is defined
- GPU variant is used in the FROM statement
- Default value is set to "nvidia"

## Change Detection

The workflow monitors the specific GPU variant image for updates:

```bash
# Checks for updates to the specific GPU variant image
FULL_IMAGE="${AURORA_BASE_IMAGE}-${AURORA_VARIANT}-${GPU_VARIANT}"
AURORA_DIGEST=$(skopeo inspect docker://${FULL_IMAGE}:latest | jq -r '.Digest')
```

This means:
- Builds only trigger when YOUR configured GPU variant is updated
- Different GPU variants are tracked independently
- Switching GPU variants will trigger a new build

## Build Metadata

The GPU variant is stored in the image metadata:

```json
{
  "base_image": {
    "name": "ghcr.io/ublue-os/aurora",
    "variant": "aurora",
    "gpu_variant": "nvidia",
    "digest": "sha256:..."
  }
}
```

And as image labels:

```dockerfile
--label "org.vespera.aurora.variant=${AURORA_VARIANT}"
--label "org.vespera.gpu.variant=${GPU_VARIANT}"
```

## Switching GPU Variants

To switch to a different GPU variant:

1. Edit `vespera-config.yaml`:
   ```yaml
   base:
     gpu_variant: "nvidia-open"  # Change from "nvidia" to "nvidia-open"
   ```

2. Commit and push the change:
   ```bash
   git add vespera-config.yaml
   git commit -m "Switch to NVIDIA open source drivers"
   git push
   ```

3. The workflow will automatically:
   - Detect the configuration change
   - Build a new image using the new GPU variant
   - Publish the updated image

## Troubleshooting

### Invalid GPU Variant Error

If you see an error like:
```
Invalid GPU variant: xyz. Must be one of: main, nvidia, nvidia-open
```

Check your `vespera-config.yaml` and ensure `gpu_variant` is set to one of the valid values.

### Base Image Not Found

If the build fails with "image not found", verify that:
1. The GPU variant is spelled correctly
2. The Aurora variant + GPU variant combination exists
3. You have network access to pull from ghcr.io

Valid combinations:
- `aurora-main`
- `aurora-nvidia`
- `aurora-nvidia-open`
- `aurora-dx-main`
- `aurora-dx-nvidia`
- `aurora-dx-nvidia-open`

## Default Behavior

If `gpu_variant` is not specified in the configuration:
- The default value `nvidia` is used
- This matches the most common use case (NVIDIA GPUs with proprietary drivers)
- No error is raised; the build proceeds with the default

## Implementation Details

The GPU variant support is implemented across several files:

1. **vespera-config.yaml** - Configuration file with `gpu_variant` option
2. **.github/workflows/build-vespera.yml** - Workflow reads and validates GPU variant
3. **Containerfile** - Uses GPU variant in base image selection
4. **validate-gpu-variant.ps1** - Local validation script
5. **validate-containerfile.ps1** - Updated to check GPU variant support

All scripts properly handle:
- Reading the GPU variant from configuration
- Validating the value
- Passing it through the build process
- Storing it in metadata
