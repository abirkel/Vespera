# Vespera Implementation Plan

This implementation plan is based on correct understanding of:
- Aurora's actual customizations (see AURORA-CUSTOMIZATIONS.md)
- Maccel's actual build process (see MACCEL-BUILD-ANALYSIS.md)

## Project Overview

Vespera is a custom Fedora Atomic image based on Aurora that:
1. Customizes Aurora's package list (remove/add RPMs and Flatpaks)
2. Integrates the maccel mouse acceleration driver (kernel module + CLI)
3. Builds automatically via GitHub Actions when upstream changes are detected

## Implementation Tasks

- [ ] 1. Create project structure and configuration
  - Create vespera-config.yaml for package customization
  - Include option to select Aurora variant (aurora or aurora-dx)
  - Default to regular aurora variant
  - Create .gitignore for build artifacts
  - Create README.md with project overview
  - _Requirements: 1.1, 1.2, 6.2_

- [ ] 2. Create Containerfile with multi-stage build
  - [ ] 2.1 Set up base image and metadata
    - Define ARG variables for base image and versions
    - Read Aurora variant from vespera-config.yaml (aurora or aurora-dx)
    - Set up FROM statement using selected Aurora variant
    - Add image labels and metadata
    - _Requirements: 1.1, 1.2_
  
  - [ ] 2.2 Implement package customization
    - Copy vespera-config.yaml into build
    - Install yq for YAML parsing
    - Remove specified RPM packages using rpm-ostree override remove
    - Add specified RPM packages using rpm-ostree install
    - Handle Flatpak removal and installation
    - _Requirements: 2.1, 2.2, 2.3, 2.4_
  
  - [ ] 2.3 Create maccel builder stage
    - Create separate FROM fedora:41 AS maccel-builder stage
    - Install build dependencies (git, make, gcc, kernel-devel, rust, cargo, dkms)
    - Clone maccel repository
    - Build kernel module using make in driver/ directory
    - Build CLI using cargo build --bin maccel --release
    - _Requirements: 3.1, 3.2, 3.5_
  
  - [ ] 2.4 Integrate maccel into final image
    - Copy kernel module from builder to /usr/lib/modules/${KERNEL}/extra/maccel/
    - Run depmod to update module dependencies
    - Copy CLI binary from builder to /usr/local/bin/maccel
    - Install udev rules using make udev_install from builder
    - Create /etc/modules-load.d/maccel.conf for auto-loading
    - Create /etc/modprobe.d/maccel.conf for module config
    - Create maccel group with groupadd
    - _Requirements: 3.2, 3.3, 3.4, 3.5_
  
  - [ ] 2.5 Cleanup and finalization
    - Remove temporary files
    - Run ostree container commit
    - _Requirements: 1.5_

- [ ] 3. Create GitHub Actions workflow for automated builds
  - [ ] 3.1 Create workflow file structure
    - Create .github/workflows/build-vespera.yml
    - Set up workflow triggers (schedule, workflow_dispatch, push)
    - Define environment variables and secrets
    - _Requirements: 4.1, 6.1_
  
  - [ ] 3.2 Implement change detection job
    - Create job to check Aurora base image version
    - Create job to check maccel repository for updates
    - Set output variables indicating if build is needed
    - Store version metadata for next comparison
    - _Requirements: 4.2, 4.3, 4.4_
  
  - [ ] 3.3 Implement build job
    - Configure job to run conditionally based on change detection
    - Set up container build environment (buildah/podman)
    - Build vespera image using Containerfile
    - Tag image with date and version
    - _Requirements: 4.5, 1.4_
  
  - [ ] 3.4 Implement publish job
    - Authenticate to container registry (ghcr.io)
    - Push built image to registry
    - Generate and store build metadata
    - Create job summary with build information
    - _Requirements: 4.6, 4.7_

- [ ] 4. Create documentation
  - [ ] 4.1 Write comprehensive README
    - Document project purpose (Vespera = evening, Aurora = dawn)
    - Explain what Aurora provides as base
    - Document package customization process
    - Explain maccel integration
    - Provide installation instructions
    - Include usage examples
    - _Requirements: 6.3_
  
  - [ ] 4.2 Document configuration
    - Create example vespera-config.yaml with comments
    - Document all configuration options
    - Provide examples for common customizations
    - Reference AURORA-CUSTOMIZATIONS.md for what's already included
    - _Requirements: 6.2, 6.3_
  
  - [ ] 4.3 Document build process
    - Explain multi-stage build approach
    - Document maccel integration details
    - Provide troubleshooting guide
    - Document GitHub Actions workflow
    - _Requirements: 6.3, 6.4_

- [ ] 5. Testing and validation
  - [ ] 5.1 Validate Containerfile syntax locally
    - Review Containerfile for syntax errors
    - Verify all paths and commands are correct
    - Check multi-stage build structure
    - Validate ARG and ENV variables
    - _Requirements: 5.1_
  
  - [ ] 5.2 Add verification job to GitHub Actions workflow
    - Create verification job that runs after successful build
    - Use podman/docker to run verification commands in built image
    - Check for maccel kernel module in /usr/lib/modules/
    - Verify maccel CLI binary at /usr/local/bin/maccel
    - Check udev rules in /etc/udev/rules.d/
    - Verify maccel group exists
    - Check module loading config in /etc/modules-load.d/
    - Output all verification results to job summary
    - _Requirements: 3.3, 3.4, 3.5, 5.2, 5.3_
  
  - [ ] 5.3 Add package verification to GitHub Actions
    - Run commands to list installed RPM packages
    - Verify removed packages are not present
    - Verify added packages are installed
    - Check Flatpak installations
    - Output package verification results to job summary
    - _Requirements: 2.2, 2.3, 2.4, 5.2_
  
  - [ ] 5.4 Test complete workflow
    - Push to GitHub repository
    - Trigger workflow manually via workflow_dispatch
    - Monitor build logs in GitHub Actions
    - Review verification job output
    - Verify build completes without errors
    - Check image publishes to registry
    - _Requirements: 4.1, 4.4, 4.6, 5.1_
  
  - [ ] 5.5 Validate change detection logic
    - Test workflow with manual trigger (should build)
    - Wait for scheduled run with no changes (should skip)
    - Make a config change and verify build triggers
    - Verify version metadata is stored correctly
    - _Requirements: 4.1, 4.4, 4.5_
  
  - [ ] 5.5 Optional: Test on actual hardware (if available)
    - Deploy built image to a test machine or VM
    - Verify maccel module loads
    - Test maccel CLI functionality
    - Verify package customizations
    - Note: This requires Linux environment or VM
    - _Requirements: 5.2, 5.3_

- [ ] 6. Repository setup and deployment
  - [ ] 6.1 Initialize git repository
    - Initialize git repo
    - Create initial commit with all files
    - _Requirements: 6.1_
  
  - [ ] 6.2 Create GitHub repository
    - Create public repository on GitHub
    - Push local repository to GitHub
    - Configure repository settings
    - _Requirements: 6.1, 6.4_
  
  - [ ] 6.3 Configure GitHub Actions secrets
    - Add GITHUB_TOKEN for registry authentication
    - Configure any additional secrets needed
    - Test workflow runs successfully
    - _Requirements: 6.5_
  
  - [ ] 6.4 Enable automated builds
    - Verify daily schedule trigger works
    - Monitor first automated build
    - Confirm change detection prevents unnecessary builds
    - _Requirements: 4.1, 4.5_

## Success Criteria

- [ ] Containerfile passes syntax validation
- [ ] GitHub Actions workflow builds successfully
- [ ] Verification job confirms maccel integration (module + CLI present)
- [ ] Verification job confirms package customizations applied
- [ ] Image publishes to container registry
- [ ] Image size is reasonable (check in registry)
- [ ] Change detection prevents unnecessary builds
- [ ] Documentation is complete and accurate

## Testing Strategy for Windows Development

Since local Linux build environment is not available, we use GitHub Actions for both building and verification:

1. **Local Syntax Validation**: Review all files for correctness before pushing
2. **Cloud-Based Building**: GitHub Actions builds the container image
3. **Automated Verification**: GitHub Actions runs verification commands inside the built image
4. **Results in Job Summary**: All verification results output to GitHub Actions job summary
5. **Iterative Debugging**: Use logs and verification output to identify and fix issues

This approach provides comprehensive testing without requiring local Linux environment.
