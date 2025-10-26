# Image Signing Documentation

## Overview

Vespera container images are cryptographically signed using [Sigstore](https://www.sigstore.dev/) keyless signing technology. This provides strong guarantees about image authenticity and integrity without requiring manual key management.

**Key Benefits**:
- **Authenticity**: Verify images come from the official Vespera repository
- **Integrity**: Detect any tampering or modification of images
- **Transparency**: All signing events are recorded in a public audit log
- **No Key Management**: No private keys to store, rotate, or protect
- **Supply Chain Security**: Protection against supply chain attacks

## How It Works

### Keyless Signing Process

Vespera uses Sigstore's keyless signing infrastructure, which eliminates the need for long-lived private keys:

1. **Build Completion**: After successful image build and verification in GitHub Actions
2. **OIDC Authentication**: GitHub Actions obtains an identity token from GitHub's OIDC provider
3. **Certificate Issuance**: Sigstore's Fulcio CA issues a short-lived certificate (valid for ~10 minutes) bound to the repository identity
4. **Image Signing**: Cosign signs the image using the ephemeral certificate
5. **Transparency Logging**: The signature is recorded in Rekor, Sigstore's public transparency log
6. **Verification**: Signatures can be verified against the repository identity and transparency log

### Trust Model

The security of keyless signing relies on:

- **Sigstore Root of Trust**: Public root certificates maintained by the Sigstore project
- **GitHub OIDC Identity**: GitHub's identity provider authenticates the signer
- **Certificate Binding**: Certificates are bound to the specific GitHub repository URL
- **Transparency Log**: Public audit trail of all signing events in Rekor

When you verify a signature, you're checking:
1. The certificate was issued by Sigstore's Fulcio CA
2. The certificate subject matches the expected repository (e.g., `https://github.com/YOUR_USERNAME/vespera`)
3. The certificate issuer is GitHub Actions (`https://token.actions.githubusercontent.com`)
4. The signature is recorded in the Rekor transparency log

## Verifying Image Signatures

### Automatic Verification with rpm-ostree

The simplest way to use signed images is with `ostree-image-signed:` URLs:

```bash
# rpm-ostree automatically verifies signatures
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/YOUR_USERNAME/vespera-nvidia:latest
```

This provides automatic signature verification with no additional configuration required.

### Manual Verification with Cosign

For manual verification or to inspect signature details before rebasing:

#### Install Cosign

```bash
# Download and install cosign
curl -O -L "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64"
sudo install cosign-linux-amd64 /usr/local/bin/cosign
rm cosign-linux-amd64

# Verify installation
cosign version
```

#### Verify Image Signature

```bash
# Basic verification (checks signature exists and is valid)
cosign verify \
  --certificate-identity=https://github.com/YOUR_USERNAME/vespera \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  ghcr.io/YOUR_USERNAME/vespera-nvidia:latest
```

Replace `YOUR_USERNAME` with your GitHub username.

#### Verify Specific Image Digest

For maximum security, verify using the image digest (immutable reference):

```bash
# Get the image digest
skopeo inspect docker://ghcr.io/YOUR_USERNAME/vespera-nvidia:latest | jq -r '.Digest'

# Verify using digest
cosign verify \
  --certificate-identity=https://github.com/YOUR_USERNAME/vespera \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  ghcr.io/YOUR_USERNAME/vespera-nvidia@sha256:DIGEST_HERE
```

#### Inspect Certificate Details

```bash
# View full certificate information
cosign verify \
  --certificate-identity=https://github.com/YOUR_USERNAME/vespera \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  ghcr.io/YOUR_USERNAME/vespera-nvidia:latest | jq
```

This shows:
- Certificate subject (repository URL)
- Certificate issuer (GitHub Actions)
- Workflow details (workflow name, trigger, commit SHA)
- Rekor transparency log entry
- Signature timestamp

### Verification Output

Successful verification output looks like:

```json
[
  {
    "critical": {
      "identity": {
        "docker-reference": "ghcr.io/YOUR_USERNAME/vespera-nvidia"
      },
      "image": {
        "docker-manifest-digest": "sha256:..."
      },
      "type": "cosign container image signature"
    },
    "optional": {
      "Bundle": {
        "SignedEntryTimestamp": "...",
        "Payload": {
          "logIndex": 12345,
          "logID": "..."
        }
      },
      "Issuer": "https://token.actions.githubusercontent.com",
      "Subject": "https://github.com/YOUR_USERNAME/vespera"
    }
  }
]
```

## Security Benefits

### Protection Against Tampering

Cryptographic signatures ensure that:
- Images haven't been modified after signing
- Images come from the official repository
- Build process completed successfully

Any modification to the image invalidates the signature, and verification will fail.

### Supply Chain Security

Keyless signing provides supply chain security through:

1. **Identity Verification**: Signatures are bound to the GitHub repository identity
2. **Workflow Context**: Certificate includes workflow details (commit SHA, trigger, etc.)
3. **Transparency**: All signing events are publicly auditable in Rekor
4. **No Key Compromise**: Ephemeral certificates eliminate long-lived key compromise risks

### OIDC Identity Verification

The certificate subject contains the repository URL, ensuring signatures can only be created by:
- The official repository's GitHub Actions workflows
- With proper OIDC authentication
- During legitimate build processes

This prevents:
- Unauthorized signing from forked repositories
- Signature spoofing from unrelated repositories
- Man-in-the-middle attacks during image distribution

## Advanced Configuration

### Custom Signature Policies

For stricter security requirements, configure custom signature verification policies:

```bash
# Create policy configuration directory
sudo mkdir -p /etc/containers

# Edit policy file
sudo nano /etc/containers/policy.json
```

#### Example: Strict Policy (Reject All Except Signed Vespera)

```json
{
  "default": [{"type": "reject"}],
  "transports": {
    "docker": {
      "ghcr.io/YOUR_USERNAME/vespera-nvidia": [
        {
          "type": "sigstoreSigned",
          "keyless": {
            "issuer": "https://token.actions.githubusercontent.com",
            "subject": "https://github.com/YOUR_USERNAME/vespera"
          }
        }
      ],
      "ghcr.io/YOUR_USERNAME/vespera-dx-nvidia": [
        {
          "type": "sigstoreSigned",
          "keyless": {
            "issuer": "https://token.actions.githubusercontent.com",
            "subject": "https://github.com/YOUR_USERNAME/vespera"
          }
        }
      ]
    }
  }
}
```

#### Example: Permissive Policy (Allow Signed Vespera, Reject Others)

```json
{
  "default": [{"type": "insecureAcceptAnything"}],
  "transports": {
    "docker": {
      "ghcr.io/YOUR_USERNAME": [
        {
          "type": "sigstoreSigned",
          "keyless": {
            "issuer": "https://token.actions.githubusercontent.com",
            "subject": "https://github.com/YOUR_USERNAME/vespera"
          }
        }
      ]
    }
  }
}
```

### Policy Configuration Options

- `"type": "reject"`: Reject all images (use as default for maximum security)
- `"type": "insecureAcceptAnything"`: Accept any image (use with caution)
- `"type": "sigstoreSigned"`: Require Sigstore keyless signature
- `"keyless"`: Specify required certificate identity
  - `"issuer"`: OIDC issuer (GitHub Actions)
  - `"subject"`: Repository URL

### Verifying Multiple Image Variants

If you use multiple Vespera variants, add policies for each:

```json
{
  "default": [{"type": "reject"}],
  "transports": {
    "docker": {
      "ghcr.io/YOUR_USERNAME/vespera": [
        {
          "type": "sigstoreSigned",
          "keyless": {
            "issuer": "https://token.actions.githubusercontent.com",
            "subject": "https://github.com/YOUR_USERNAME/vespera"
          }
        }
      ],
      "ghcr.io/YOUR_USERNAME/vespera-nvidia": [
        {
          "type": "sigstoreSigned",
          "keyless": {
            "issuer": "https://token.actions.githubusercontent.com",
            "subject": "https://github.com/YOUR_USERNAME/vespera"
          }
        }
      ],
      "ghcr.io/YOUR_USERNAME/vespera-nvidia-open": [
        {
          "type": "sigstoreSigned",
          "keyless": {
            "issuer": "https://token.actions.githubusercontent.com",
            "subject": "https://github.com/YOUR_USERNAME/vespera"
          }
        }
      ],
      "ghcr.io/YOUR_USERNAME/vespera-dx": [
        {
          "type": "sigstoreSigned",
          "keyless": {
            "issuer": "https://token.actions.githubusercontent.com",
            "subject": "https://github.com/YOUR_USERNAME/vespera"
          }
        }
      ],
      "ghcr.io/YOUR_USERNAME/vespera-dx-nvidia": [
        {
          "type": "sigstoreSigned",
          "keyless": {
            "issuer": "https://token.actions.githubusercontent.com",
            "subject": "https://github.com/YOUR_USERNAME/vespera"
          }
        }
      ],
      "ghcr.io/YOUR_USERNAME/vespera-dx-nvidia-open": [
        {
          "type": "sigstoreSigned",
          "keyless": {
            "issuer": "https://token.actions.githubusercontent.com",
            "subject": "https://github.com/YOUR_USERNAME/vespera"
          }
        }
      ]
    }
  }
}
```

## Transparency Log

All Vespera image signatures are recorded in [Rekor](https://rekor.sigstore.dev/), Sigstore's public transparency log.

### Viewing Transparency Log Entries

```bash
# Verify and show Rekor log entry
cosign verify \
  --certificate-identity=https://github.com/YOUR_USERNAME/vespera \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  ghcr.io/YOUR_USERNAME/vespera-nvidia:latest | jq '.[] | .optional.Bundle.Payload'
```

### Searching the Transparency Log

```bash
# Search for signatures by repository
rekor-cli search --email YOUR_USERNAME@users.noreply.github.com

# Get specific log entry
rekor-cli get --log-index LOG_INDEX_NUMBER
```

### Benefits of Transparency

- **Public Audit Trail**: Anyone can verify signing events
- **Tamper Detection**: Log entries are cryptographically protected
- **Historical Verification**: Verify signatures even after certificates expire
- **Incident Response**: Investigate suspicious signing activity

## Migration Guide

### Migrating from Unsigned to Signed Images

If you're currently using unsigned images (`ostree-unverified-registry:`), follow these steps to migrate:

#### Step 1: Verify Current Deployment

```bash
# Check current deployment
rpm-ostree status

# Note your current image reference
```

#### Step 2: Rebase to Signed Image

```bash
# Rebase using signed image URL
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/YOUR_USERNAME/vespera-nvidia:latest

# Review the changes
rpm-ostree status
```

#### Step 3: Reboot and Verify

```bash
# Reboot to apply changes
systemctl reboot

# After reboot, verify deployment
rpm-ostree status

# Check that signature verification is active
journalctl -u rpm-ostreed | grep -i signature
```

#### Step 4: Test Rollback (Optional)

```bash
# Test rollback capability
rpm-ostree rollback

# Reboot to previous deployment
systemctl reboot

# After testing, reboot back to signed image
systemctl reboot
```

### Rollback to Unsigned Images

If you need to rollback to unsigned images:

```bash
# Rebase to unsigned image
rpm-ostree rebase ostree-unverified-registry:ghcr.io/YOUR_USERNAME/vespera-nvidia:latest

# Reboot
systemctl reboot
```

**Note**: This is not recommended for security reasons. Unsigned images will be deprecated in the future.

## Troubleshooting

See the [Troubleshooting Guide](IMAGE-SIGNING.md#troubleshooting-guide) section below for common issues and solutions.

## Resources

- [Sigstore Documentation](https://docs.sigstore.dev/) - Official Sigstore documentation
- [Cosign Documentation](https://docs.sigstore.dev/cosign/overview/) - Cosign signing and verification
- [Rekor Transparency Log](https://rekor.sigstore.dev/) - Public transparency log
- [Fedora Container Signature Verification](https://docs.fedoraproject.org/en-US/fedora-silverblue/container-image-signatures/) - Fedora's signature verification guide

## Troubleshooting Guide

### Common Issues and Solutions

#### Issue: "Error: Signature verification failed"

**Cause**: Image signature cannot be verified against the expected identity.

**Solutions**:

1. **Verify repository identity matches**:
   ```bash
   # Check that YOUR_USERNAME matches your GitHub username
   cosign verify \
     --certificate-identity=https://github.com/YOUR_USERNAME/vespera \
     --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
     ghcr.io/YOUR_USERNAME/vespera-nvidia:latest
   ```

2. **Check image was actually signed**:
   ```bash
   # Verify signature exists
   cosign verify \
     --certificate-identity=https://github.com/YOUR_USERNAME/vespera \
     --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
     ghcr.io/YOUR_USERNAME/vespera-nvidia:latest
   ```
   
   If this fails, the image may not be signed yet. Check GitHub Actions workflow logs.

3. **Verify network connectivity**:
   ```bash
   # Test connectivity to Sigstore services
   curl -I https://fulcio.sigstore.dev
   curl -I https://rekor.sigstore.dev
   ```

4. **Check for policy configuration issues**:
   ```bash
   # Review policy file
   cat /etc/containers/policy.json
   
   # Temporarily use a permissive policy for testing
   sudo mv /etc/containers/policy.json /etc/containers/policy.json.backup
   ```

#### Issue: "Error: Image not found" or "Error: Manifest unknown"

**Cause**: Image doesn't exist or tag is incorrect.

**Solutions**:

1. **Verify image exists in registry**:
   ```bash
   # List available tags
   skopeo list-tags docker://ghcr.io/YOUR_USERNAME/vespera-nvidia
   ```

2. **Check image name matches your configuration**:
   - Review `vespera-config.yaml` for correct variant and GPU settings
   - Verify image name follows naming convention (see README.md)

3. **Ensure build completed successfully**:
   - Check GitHub Actions workflow status
   - Review build logs for errors

#### Issue: "Error: Certificate identity mismatch"

**Cause**: Certificate subject doesn't match expected repository URL.

**Solutions**:

1. **Verify repository URL is correct**:
   ```bash
   # Check certificate details
   cosign verify \
     --certificate-identity=https://github.com/YOUR_USERNAME/vespera \
     --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
     ghcr.io/YOUR_USERNAME/vespera-nvidia:latest | jq '.[] | .optional.Subject'
   ```

2. **Ensure you're using the correct GitHub username**:
   - Replace `YOUR_USERNAME` with your actual GitHub username
   - Check for typos or case sensitivity issues

3. **Verify image was built from your repository**:
   - Forked repositories have different identities
   - Ensure you're pulling from your own registry

#### Issue: "Error: OIDC issuer mismatch"

**Cause**: Certificate issuer doesn't match GitHub Actions.

**Solutions**:

1. **Verify issuer URL is correct**:
   ```bash
   # Should be: https://token.actions.githubusercontent.com
   cosign verify \
     --certificate-identity=https://github.com/YOUR_USERNAME/vespera \
     --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
     ghcr.io/YOUR_USERNAME/vespera-nvidia:latest | jq '.[] | .optional.Issuer'
   ```

2. **Check for manual signing attempts**:
   - Images must be signed by GitHub Actions workflow
   - Manual signing with different OIDC providers won't match

#### Issue: Slow verification or timeouts

**Cause**: Network latency to Sigstore services or Rekor transparency log.

**Solutions**:

1. **Check network connectivity**:
   ```bash
   # Test latency to Sigstore services
   ping -c 5 fulcio.sigstore.dev
   ping -c 5 rekor.sigstore.dev
   ```

2. **Use cached verification** (if available):
   ```bash
   # rpm-ostree caches verification results
   # Subsequent rebases should be faster
   ```

3. **Verify during off-peak hours**:
   - Sigstore services may be slower during peak usage
   - Try verification at different times

#### Issue: "Error: Policy requirements not satisfied"

**Cause**: Container policy configuration is too restrictive or misconfigured.

**Solutions**:

1. **Review policy configuration**:
   ```bash
   # Check policy file
   sudo cat /etc/containers/policy.json
   ```

2. **Test with permissive policy**:
   ```bash
   # Backup current policy
   sudo cp /etc/containers/policy.json /etc/containers/policy.json.backup
   
   # Create permissive policy for testing
   echo '{
     "default": [{"type": "insecureAcceptAnything"}]
   }' | sudo tee /etc/containers/policy.json
   
   # Try rebase again
   rpm-ostree rebase ostree-image-signed:docker://ghcr.io/YOUR_USERNAME/vespera-nvidia:latest
   
   # Restore original policy after testing
   sudo mv /etc/containers/policy.json.backup /etc/containers/policy.json
   ```

3. **Verify policy syntax**:
   ```bash
   # Validate JSON syntax
   jq . /etc/containers/policy.json
   ```

### Fallback Procedures

#### Temporary Fallback to Unsigned Images

If signature verification is blocking critical updates:

```bash
# Temporarily use unsigned images
rpm-ostree rebase ostree-unverified-registry:ghcr.io/YOUR_USERNAME/vespera-nvidia:latest
systemctl reboot

# After resolving issues, return to signed images
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/YOUR_USERNAME/vespera-nvidia:latest
systemctl reboot
```

**Warning**: Only use this as a temporary measure. Investigate and resolve the underlying issue.

#### Emergency Rollback

If a signed image causes system issues:

```bash
# Rollback to previous deployment
rpm-ostree rollback
systemctl reboot

# After reboot, investigate the issue
rpm-ostree status
journalctl -u rpm-ostreed -b -1
```

### Getting Help

If you continue to experience issues:

1. **Check GitHub Actions logs**: Review workflow logs for signing errors
2. **Verify Sigstore service status**: Check [Sigstore Status](https://status.sigstore.dev/)
3. **Review system logs**: `journalctl -u rpm-ostreed | grep -i signature`
4. **Test manual verification**: Use `cosign verify` to isolate the issue
5. **Check Rekor transparency log**: Verify signing events were recorded

### Debugging Commands

```bash
# Check rpm-ostree status and deployment
rpm-ostree status -v

# View recent rpm-ostree logs
journalctl -u rpm-ostreed -n 100

# Test cosign verification with verbose output
cosign verify \
  --certificate-identity=https://github.com/YOUR_USERNAME/vespera \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  ghcr.io/YOUR_USERNAME/vespera-nvidia:latest 2>&1 | tee verify.log

# Inspect image manifest
skopeo inspect docker://ghcr.io/YOUR_USERNAME/vespera-nvidia:latest

# Check container policy
cat /etc/containers/policy.json | jq

# Test network connectivity to Sigstore
curl -v https://fulcio.sigstore.dev
curl -v https://rekor.sigstore.dev
```
