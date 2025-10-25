# GPU Variant Support Tasks

This task list adds support for Aurora's GPU variants (main, nvidia, nvidia-open) to Vespera.

## Background

Aurora provides 3 GPU variants:
- **main** - Intel/AMD (open source drivers)
- **nvidia** - NVIDIA proprietary drivers
- **nvidia-open** - NVIDIA open source drivers

Default should be `nvidia` as requested.

## Tasks

- [x] 1. Update configuration file structure





  - Add `gpu_variant` option to vespera-config.yaml
  - Set default value to "nvidia"
  - Add validation for valid GPU variant values (main, nvidia, nvidia-open)
  - Document the GPU variant options in configuration comments
  - _Files: vespera-config.yaml_

- [x] 2. Update Containerfile for GPU variant support





  - [x] 2.1 Add ARG for GPU variant selection


    - Add ARG GPU_VARIANT with default value "nvidia"
    - Read GPU variant from configuration parsing
    - _Files: Containerfile_
  
  - [x] 2.2 Modify base image selection


    - Update FROM statement to use GPU variant in image name
    - Change from `ghcr.io/ublue-os/aurora:41` to `ghcr.io/ublue-os/aurora-${GPU_VARIANT}:41`
    - Handle both aurora and aurora-dx variants with GPU suffix
    - _Files: Containerfile_

- [x] 3. Update configuration parsing scripts





  - Modify scripts to read gpu_variant from vespera-config.yaml
  - Pass GPU variant to container build process
  - Add validation to ensure GPU variant is supported
  - _Files: Scripts that parse configuration_

- [x] 4. Update GitHub Actions workflow





  - [x] 4.1 Add GPU variant to build process


    - Read GPU variant from configuration
    - Pass GPU variant as build argument to container build
    - Update image tagging to include GPU variant information
    - _Files: .github/workflows/build-vespera.yml_
  
  - [x] 4.2 Update change detection for GPU variants


    - Modify Aurora version checker to check specific GPU variant
    - Update from checking "aurora" to checking "aurora-${gpu_variant}"
    - Ensure change detection works for the configured GPU variant
    - _Files: Change detection scripts_

- [x] 5. Update documentation




  - [x] 5.1 Update README with GPU variant information


    - Explain the three GPU variant options
    - Provide guidance on choosing the right variant
    - Document how to change GPU variant in configuration
    - _Files: README.md_
  
  - [x] 5.2 Update configuration documentation


    - Add gpu_variant to configuration examples
    - Explain default choice and alternatives
    - Provide hardware-specific recommendations
    - _Files: Configuration documentation_


- [x] 6. Update package inspection tools




  - [x] 6.1 Update Aurora package checker


    - Modify tools/check-aurora-packages.sh to support GPU variants
    - Show packages for specific GPU variant being used
    - Display differences between GPU variants if any
    - _Files: tools/check-aurora-packages.sh_
  

  - [x] 6.2 Update comparison tools

    - Update tools/compare-packages.sh to handle GPU variants
    - Show package differences between GPU variants
    - _Files: tools/compare-packages.sh_

- [x] 7. Update verification and testing





  - [x] 7.1 Update verification jobs


    - Modify GitHub Actions verification to check correct GPU variant image
    - Verify the built image matches the configured GPU variant
    - _Files: GitHub Actions verification jobs_
  

  - [x] 7.2 Update local validation

    - Update validation scripts to check GPU variant configuration
    - Verify Containerfile uses correct base image for GPU variant
    - _Files: Local validation scripts_

- [ ] 8. Test GPU variant functionality
  - [ ] 8.1 Test configuration parsing
    - Verify gpu_variant is read correctly from configuration
    - Test with all three GPU variants (main, nvidia, nvidia-open)
    - Validate error handling for invalid GPU variants
  
  - [ ] 8.2 Test build process
    - Test container build with different GPU variants
    - Verify correct base images are used
    - Confirm change detection works for GPU-specific images
  
  - [ ] 8.3 Test documentation and tools
    - Verify package inspection tools work with GPU variants
    - Test that documentation is accurate and helpful
    - Confirm examples work as documented

## Success Criteria

- [x] Configuration supports gpu_variant with nvidia as default




- [ ] Containerfile builds using correct Aurora GPU variant base image
- [ ] GitHub Actions workflow respects GPU variant configuration
- [ ] Change detection monitors the correct GPU variant for updates
- [ ] Documentation clearly explains GPU variant options
- [ ] Package inspection tools show GPU variant-specific information
- [ ] All existing functionality continues to work with GPU variant support

## Notes

- This is an enhancement to existing functionality, not a replacement
- All current features should continue working with default nvidia variant
- Users should be able to easily switch between GPU variants by changing configuration
- The change should be backward compatible if possible