# Vespera - Custom Fedora Atomic Image
# Multi-stage build: Stage 1 builds maccel, Stage 2 customizes Aurora

# =============================================================================
# Global ARGs (available to all stages)
# =============================================================================
# ARG for selecting Aurora variant (aurora or aurora-dx)
ARG AURORA_VARIANT=aurora
# ARG for selecting GPU variant (main, nvidia, nvidia-open)
ARG GPU_VARIANT=nvidia
ARG FEDORA_VERSION=41
ARG AURORA_DATE=latest

# =============================================================================
# Stage 1: Build maccel kernel module and CLI
# =============================================================================
# First, we need to determine the Fedora version from the Aurora image
# This is a temporary stage just to query the Aurora image metadata
FROM fedora:latest AS aurora-inspector

# Re-declare ARGs needed in this stage
ARG AURORA_VARIANT
ARG GPU_VARIANT
ARG AURORA_DATE

# Query Aurora image to get Fedora version and kernel version
RUN dnf install -y skopeo jq && \
    AURORA_IMAGE="ghcr.io/ublue-os/${AURORA_VARIANT}-${GPU_VARIANT}:${AURORA_DATE}" && \
    echo "Querying Aurora image: ${AURORA_IMAGE}..." && \
    skopeo inspect docker://${AURORA_IMAGE} > /tmp/aurora-inspect.json && \
    FEDORA_VERSION=$(jq -r '.Labels["org.opencontainers.image.version"] // .Labels["version"] // empty' /tmp/aurora-inspect.json | grep -oP 'fc\K[0-9]+' || echo "42") && \
    KERNEL_VERSION=$(jq -r '.Labels["ostree.linux"] // empty' /tmp/aurora-inspect.json) && \
    if [ -z "$KERNEL_VERSION" ]; then \
        echo "ERROR: Could not determine kernel version from Aurora image ${AURORA_IMAGE}"; \
        echo "This is required to build the maccel kernel module for the correct kernel."; \
        exit 1; \
    fi && \
    echo "Detected Fedora version: ${FEDORA_VERSION}" && \
    echo "Detected kernel version: ${KERNEL_VERSION}" && \
    echo "${FEDORA_VERSION}" > /tmp/fedora-version && \
    echo "${KERNEL_VERSION}" > /tmp/kernel-version

# Now use the detected Fedora version for the actual builder
FROM fedora:latest AS maccel-builder

# Copy the detected versions from inspector stage
COPY --from=aurora-inspector /tmp/fedora-version /tmp/fedora-version
COPY --from=aurora-inspector /tmp/kernel-version /tmp/kernel-version

# Install build dependencies using the detected versions
RUN FEDORA_VERSION=$(cat /tmp/fedora-version) && \
    KERNEL_VERSION=$(cat /tmp/kernel-version) && \
    echo "Building for Fedora ${FEDORA_VERSION} with kernel ${KERNEL_VERSION}" && \
    dnf install -y \
        git \
        make \
        gcc \
        "kernel-devel-${KERNEL_VERSION}" \
        "kernel-headers-${KERNEL_VERSION}" \
        elfutils-libelf-devel \
        rust \
        cargo \
    && dnf clean all

# Clone maccel repository
ARG MACCEL_REPO=https://github.com/Gnarus-G/maccel
RUN git clone ${MACCEL_REPO} /tmp/maccel

WORKDIR /tmp/maccel

# Build kernel module for the target kernel version
# The driver is in the driver/ subdirectory
# In containers, kernel-devel installs to /usr/src/kernels/ not /lib/modules/
RUN KERNEL_VERSION=$(cat /tmp/kernel-version) && \
    echo "Building maccel module for kernel ${KERNEL_VERSION}..." && \
    KERNEL_SRC="/usr/src/kernels/${KERNEL_VERSION}" && \
    if [ ! -d "$KERNEL_SRC" ]; then \
        echo "Kernel source not found at $KERNEL_SRC, checking alternatives..."; \
        KERNEL_SRC=$(ls -d /usr/src/kernels/*$(echo ${KERNEL_VERSION} | cut -d. -f1-3)* 2>/dev/null | head -n1); \
    fi && \
    echo "Using kernel source: $KERNEL_SRC" && \
    cd driver && \
    make KDIR="$KERNEL_SRC"

# Build CLI tool (in root directory, not maccel-tui/)
RUN cargo build --bin maccel --release

# =============================================================================
# Stage 2: Customize Aurora and integrate maccel
# =============================================================================

# Re-declare ARGs for this stage
ARG AURORA_VARIANT
ARG GPU_VARIANT
ARG FEDORA_VERSION
ARG AURORA_DATE

# Base image from Aurora with GPU variant support
# The GPU variant will be appended to the Aurora variant name
# Examples: aurora-nvidia, aurora-dx-nvidia-open, etc.
# Aurora images use 'latest', 'stable', or date-based tags, not Fedora version numbers
FROM ghcr.io/ublue-os/${AURORA_VARIANT}-${GPU_VARIANT}:${AURORA_DATE}

# Image metadata
LABEL org.opencontainers.image.title="Vespera"
LABEL org.opencontainers.image.description="Custom Fedora Atomic image based on Aurora with maccel integration"
LABEL org.opencontainers.image.source="https://github.com/YOUR_USERNAME/vespera"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.vendor="Vespera Project"

# Copy configuration file
COPY vespera-config.yaml /tmp/vespera-config.yaml

# Install yq for YAML parsing
RUN curl -L https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -o /usr/bin/yq && \
    chmod +x /usr/bin/yq

# Remove specified RPM packages
RUN PACKAGES_TO_REMOVE=$(yq eval '.packages.remove_rpm[]' /tmp/vespera-config.yaml 2>/dev/null | tr '\n' ' ') && \
    if [ -n "$PACKAGES_TO_REMOVE" ]; then \
        rpm-ostree override remove $PACKAGES_TO_REMOVE || true; \
    fi

# Add specified RPM packages
RUN PACKAGES_TO_ADD=$(yq eval '.packages.add_rpm[]' /tmp/vespera-config.yaml 2>/dev/null | tr '\n' ' ') && \
    if [ -n "$PACKAGES_TO_ADD" ]; then \
        rpm-ostree install $PACKAGES_TO_ADD; \
    fi

# Handle Flatpak removal
RUN FLATPAKS_TO_REMOVE=$(yq eval '.packages.remove_flatpak[]' /tmp/vespera-config.yaml 2>/dev/null) && \
    if [ -n "$FLATPAKS_TO_REMOVE" ]; then \
        echo "$FLATPAKS_TO_REMOVE" | while read -r flatpak; do \
            if [ -n "$flatpak" ]; then \
                flatpak remove -y "$flatpak" 2>/dev/null || true; \
            fi; \
        done; \
    fi

# Handle Flatpak installation
RUN FLATPAKS_TO_ADD=$(yq eval '.packages.add_flatpak[]' /tmp/vespera-config.yaml 2>/dev/null) && \
    if [ -n "$FLATPAKS_TO_ADD" ]; then \
        echo "$FLATPAKS_TO_ADD" | while read -r flatpak; do \
            if [ -n "$flatpak" ]; then \
                flatpak install -y flathub "$flatpak" 2>/dev/null || true; \
            fi; \
        done; \
    fi

# =============================================================================
# Integrate maccel from builder stage
# =============================================================================

# Get the kernel version for module installation
RUN KERNEL_VERSION=$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}') && \
    echo "Installing maccel for kernel: $KERNEL_VERSION" && \
    mkdir -p /usr/lib/modules/${KERNEL_VERSION}/extra/maccel

# Copy kernel module from builder
RUN KERNEL_VERSION=$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}') && \
    mkdir -p /tmp/maccel-module
COPY --from=maccel-builder /tmp/maccel/driver/maccel.ko /tmp/maccel-module/
RUN KERNEL_VERSION=$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}') && \
    cp /tmp/maccel-module/maccel.ko /usr/lib/modules/${KERNEL_VERSION}/extra/maccel/ && \
    depmod -a ${KERNEL_VERSION}

# Copy CLI binary from builder
COPY --from=maccel-builder /tmp/maccel/target/release/maccel /usr/local/bin/maccel
RUN chmod +x /usr/local/bin/maccel

# Install udev rules - create them since they may not exist in the repo
RUN echo '# Maccel udev rules' > /etc/udev/rules.d/99-maccel.rules && \
    echo '# Allow access to uinput device for maccel' >> /etc/udev/rules.d/99-maccel.rules && \
    echo 'KERNEL=="uinput", SUBSYSTEM=="misc", TAG+="uaccess", OPTIONS+="static_node=uinput", GROUP="maccel", MODE="0660"' >> /etc/udev/rules.d/99-maccel.rules && \
    echo '# Allow access to input event devices' >> /etc/udev/rules.d/99-maccel.rules && \
    echo 'KERNEL=="event*", SUBSYSTEM=="input", TAG+="uaccess", GROUP="maccel", MODE="0660"' >> /etc/udev/rules.d/99-maccel.rules

# Create module loading configuration
RUN echo "maccel" > /etc/modules-load.d/maccel.conf

# Create module configuration (if needed for parameters)
RUN echo "# Maccel kernel module configuration" > /etc/modprobe.d/maccel.conf && \
    echo "# Add module parameters here if needed" >> /etc/modprobe.d/maccel.conf

# Create maccel group for non-root access
RUN groupadd -r maccel || true

# =============================================================================
# Cleanup and finalization
# =============================================================================

# Remove temporary files
RUN rm -rf /tmp/vespera-config.yaml /tmp/maccel-module /usr/bin/yq

# Commit the ostree container
RUN ostree container commit

# Set default command
CMD ["/sbin/init"]
