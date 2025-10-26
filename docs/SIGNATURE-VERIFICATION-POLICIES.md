# Signature Verification Policies for Vespera Images

This document provides examples and guidance for configuring container signature verification policies for Vespera images. These policies control how `rpm-ostree` and other container tools verify image signatures when using `ostree-image-signed:` URLs.

## Overview

Container signature verification policies are configured in `/etc/containers/policy.json`. This file defines which images can be pulled and what verification requirements must be met. For Vespera images signed with Sigstore keyless signing, you need to configure policies that verify against the GitHub repository identity.

## Policy Structure

The policy file has the following structure:

```json
{
  "default": [{"type": "reject"}],
  "transports": {
    "docker": {
      "registry/image": [
        {
          "type": "sigstoreSigned",
          "keyless": {
            "issuer": "https://token.actions.githubusercontent.com",
            "subject": "https://github.com/owner/repository"
          }
        }
      ]
    }
  }
}
```

## Policy Examples

### 1. Basic Policy (`basic-policy.json`)

**Use Case**: Simple setup for personal use with a single Vespera repository.

**Features**:
- Rejects all images by default
- Allows any image from `ghcr.io` if signed by the specified repository
- Minimal configuration

**Setup**:
1. Replace `USERNAME/REPOSITORY` with your GitHub username and repository name
2. Copy to `/etc/containers/policy.json`

**Security Level**: Medium - Trusts any image from the registry if properly signed

### 2. Vespera-Specific Policy (`vespera-specific-policy.json`)

**Use Case**: Explicit control over each Vespera image variant.

**Features**:
- Rejects all images by default
- Explicitly lists each Vespera image variant
- Same signing requirements for all variants
- Clear visibility of allowed images

**Setup**:
1. Replace `USERNAME` with your GitHub username
2. Copy to `/etc/containers/policy.json`

**Security Level**: High - Only allows explicitly listed Vespera images

### 3. Organizational Policy (`organizational-policy.json`)

**Use Case**: Enterprise or team environments with multiple repositories.

**Features**:
- Allows any repository from a specific GitHub organization
- Different policies for different registries
- Supports Red Hat signed images
- Flexible for organizational use

**Setup**:
1. Replace `ORGANIZATION` with your GitHub organization name
2. Adjust registry policies as needed
3. Copy to `/etc/containers/policy.json`

**Security Level**: Medium-High - Trusts organization repositories with proper signing

### 4. Strict Security Policy (`strict-security-policy.json`)

**Use Case**: High-security environments requiring maximum verification.

**Features**:
- Rejects all images by default
- Requires transparency log verification
- Explicit Rekor URL specification
- Only allows specific Vespera images
- No fallback acceptance

**Setup**:
1. Replace `USERNAME` with your GitHub username
2. Copy to `/etc/containers/policy.json`
3. Ensure network access to Rekor transparency log

**Security Level**: Maximum - Requires full signature and transparency log verification

### 5. Transition Policy (`transition-policy.json`)

**Use Case**: Migration period from unsigned to signed images.

**Features**:
- Prefers signed images but accepts unsigned as fallback
- Allows gradual migration
- Maintains compatibility during transition
- Multiple verification methods per image

**Setup**:
1. Replace `USERNAME` with your GitHub username
2. Copy to `/etc/containers/policy.json`
3. Remove `insecureAcceptAnything` entries after full migration

**Security Level**: Low-Medium - Accepts unsigned images as fallback

## Installation Instructions

### Step 1: Choose Your Policy

Select the policy example that best fits your security requirements and use case.

### Step 2: Customize the Policy

1. Replace placeholder values:
   - `USERNAME`: Your GitHub username
   - `REPOSITORY`: Your repository name (usually `vespera`)
   - `ORGANIZATION`: Your GitHub organization name

2. Adjust image names if you've customized them in your build configuration.

### Step 3: Install the Policy

```bash
# Backup existing policy (if any)
sudo cp /etc/containers/policy.json /etc/containers/policy.json.backup

# Copy your chosen policy
sudo cp docs/policy-examples/your-chosen-policy.json /etc/containers/policy.json

# Set proper permissions
sudo chmod 644 /etc/containers/policy.json
```

### Step 4: Test the Policy

```bash
# Test with a signed image
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/USERNAME/vespera-nvidia:latest --preview

# Verify the policy is working
cosign verify \
  --certificate-identity="https://github.com/USERNAME/vespera" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  ghcr.io/USERNAME/vespera-nvidia:latest
```

## Policy Configuration Options

### Sigstore Keyless Verification

```json
{
  "type": "sigstoreSigned",
  "keyless": {
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "https://github.com/owner/repository",
    "rekorURL": "https://rekor.sigstore.dev"
  }
}
```

**Options**:
- `issuer`: OIDC issuer (always `https://token.actions.githubusercontent.com` for GitHub Actions)
- `subject`: Exact repository URL that signed the image
- `subjectRegExp`: Regular expression for matching multiple repositories
- `rekorURL`: Transparency log URL (optional, defaults to public Rekor)

### Other Policy Types

```json
// Accept any image (not recommended for production)
{"type": "insecureAcceptAnything"}

// Reject all images
{"type": "reject"}

// Require GPG signature
{
  "type": "signedBy",
  "keyType": "GPGKeys",
  "keyPath": "/path/to/public/key"
}
```

## Security Considerations

### Trust Model

- **Subject Identity**: The `subject` field must match the exact GitHub repository that signed the image
- **Issuer Trust**: We trust GitHub's OIDC issuer to authenticate the signing identity
- **Transparency Log**: Rekor provides public auditability of all signing events

### Best Practices

1. **Use Specific Subjects**: Prefer exact repository URLs over regular expressions
2. **Enable Transparency Logs**: Include `rekorURL` for maximum security
3. **Regular Updates**: Review and update policies as repositories change
4. **Test Policies**: Always test policy changes before deploying to production
5. **Backup Policies**: Keep backups of working policy configurations

### Common Pitfalls

1. **Case Sensitivity**: Repository names are case-sensitive
2. **URL Format**: Use exact GitHub URLs (https://github.com/owner/repo)
3. **Network Access**: Ensure access to Sigstore services (fulcio.sigstore.dev, rekor.sigstore.dev)
4. **Policy Order**: First matching policy wins - order matters for fallback scenarios

## Troubleshooting

### Signature Verification Fails

```bash
# Check policy syntax
sudo podman pull --signature-policy=/etc/containers/policy.json ghcr.io/USERNAME/vespera:latest

# Verify image signature manually
cosign verify \
  --certificate-identity="https://github.com/USERNAME/vespera" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  ghcr.io/USERNAME/vespera:latest

# Check policy file syntax
python3 -m json.tool /etc/containers/policy.json
```

### Common Error Messages

**"no signature found"**
- Image may not be signed
- Check if signing workflow completed successfully
- Verify image tag/digest is correct

**"certificate identity mismatch"**
- Subject in policy doesn't match signing repository
- Check repository name spelling and case
- Verify GitHub repository URL format

**"issuer mismatch"**
- Issuer in policy is incorrect
- Should be `https://token.actions.githubusercontent.com` for GitHub Actions

**"network error"**
- Cannot reach Sigstore services
- Check internet connectivity
- Verify firewall allows access to *.sigstore.dev

### Policy Validation

```bash
# Test policy with specific image
sudo podman pull --signature-policy=/etc/containers/policy.json \
  ghcr.io/USERNAME/vespera:latest

# Validate JSON syntax
jq . /etc/containers/policy.json

# Check current policy
sudo cat /etc/containers/policy.json | jq .
```

## Migration Guide

### From Unsigned to Signed Images

1. **Phase 1**: Deploy transition policy allowing both signed and unsigned
2. **Phase 2**: Verify all new images are being signed successfully
3. **Phase 3**: Switch to strict policy requiring signatures
4. **Phase 4**: Remove fallback acceptance of unsigned images

### Policy Update Process

1. Test new policy in development environment
2. Backup current policy
3. Deploy new policy
4. Test image pulls
5. Monitor for issues
6. Rollback if necessary

## Advanced Configuration

### Multiple Repositories

```json
{
  "ghcr.io": [
    {
      "type": "sigstoreSigned",
      "keyless": {
        "issuer": "https://token.actions.githubusercontent.com",
        "subjectRegExp": "^https://github\\.com/(org1|org2)/.*$"
      }
    }
  ]
}
```

### Registry-Specific Policies

```json
{
  "ghcr.io": [{"type": "sigstoreSigned", ...}],
  "quay.io": [{"type": "signedBy", ...}],
  "docker.io": [{"type": "insecureAcceptAnything"}]
}
```

### Environment-Specific Policies

- **Development**: Transition policy with unsigned fallback
- **Staging**: Strict policy with transparency log verification
- **Production**: Maximum security with explicit image allowlists

## Support and Resources

- [Sigstore Documentation](https://docs.sigstore.dev/)
- [Containers/Image Policy Documentation](https://github.com/containers/image/blob/main/docs/containers-policy.json.5.md)
- [rpm-ostree Container Documentation](https://coreos.github.io/rpm-ostree/container/)
- [Cosign Documentation](https://docs.sigstore.dev/cosign/overview/)

For Vespera-specific issues, check the repository's issue tracker and documentation.