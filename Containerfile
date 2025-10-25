# Vespera - Custom Fedora Atomic Image
# Multi-stage build: Stage 1 builds maccel, Stage 2 customizes Aurora

# =============================================================================
# Stage 1: Build maccel kernel module and CLI
# =============================================================================
FROM fedora:41 AS maccel-builder

# Install build dependencies
# Note: We need to build for the kernel version that will be in the final Aurora image
# Query the target Aurora image to get its kernel version
ARG AURORA_VARIANT=aurora
ARG GPU_VARIANT=nvidia
ARG FEDORA_VERSION=41

# Get kernel version from target Aurora image
RUN dnf install -y skopeo jq && \
    AURORA_IMAGE="ghcr.io/ublue-os/${AURORA_VARIANT}-${GPU_VARIANT}:${FEDORA_VERSION}" && \
    echo "Querying kernel version from ${AURORA_IMAGE}..." && \
    KERNEL_VERSION=$(skopeo inspect docker://${AURORA_IMAGE} | jq -r '.Labels["ostree.linux"] // empty') && \
    if [ -z "$KERNEL_VERSION" ]; then \
        echo "Could not determine kernel version from Aurora image, using latest Fedora 41 kernel"; \
        KERNEL_VERSION="6.17.4-100.fc41"; \
    fi && \
    echo "Target kernel version: ${KERNEL_VERSION}" && \
    echo "${KERNEL_VERSION}" > /tmp/target-kernel-version && \
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
RUN KERNEL_VERSION=$(cat /tmp/target-kernel-version) && \
    echo "Building maccel module for kernel ${KERNEL_VERSION}..." && \
    cd driver && \
    make KVER=${KERNEL_VERSION}

# Build CLI tool (in root directory, not maccel-tui/)
RUN cargo build --bin maccel --release

# =============================================================================
# Stage 2: Customize Aurora and integrate maccel
# =============================================================================

# ARG for selecting Aurora variant (aurora or aurora-dx)
ARG AURORA_VARIANT=aurora
# ARG for selecting GPU variant (main, nvidia, nvidia-open)
# This should be read from vespera-config.yaml by the build system and passed as --build-arg
ARG GPU_VARIANT=nvidia
ARG FEDORA_VERSION=41
ARG AURORA_DATE=latest

# Base image from Aurora with GPU variant support
# The GPU variant will be appended to the Aurora variant name
# Examples: aurora-nvidia, aurora-dx-nvidia-open, etc.
FROM ghcr.io/ublue-os/${AURORA_VARIANT}-${GPU_VARIANT}:${FEDORA_VERSION}

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

# Install udev rules
COPY --from=maccel-builder /tmp/maccel/99-maccel.rules /etc/udev/rules.d/99-maccel.rules

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
