# Container Image Security Scanning with FCS CLI

A comprehensive example demonstrating container vulnerability scanning using CrowdStrike's Falcon Container Sensor CLI.

## Files in this scenario:

- **README.md** - Complete documentation and examples
- **Dockerfile.vulnerable** - Intentionally vulnerable container for testing
- **app.py** - Flask application with security vulnerabilities 
- **config.json** - Configuration file containing hardcoded secrets
- **demo-scan.sh** - Automated scanning script for multiple images
- **practical-demo.sh** - Demo using your available local images
- **github-actions-security.yml** - CI/CD integration example

## Quick Start:

1. **Install FCS CLI:**
   ```bash
   curl -L "https://github.com/CrowdStrike/falcon-container-sensor-cli/releases/latest/download/fcs_darwin_amd64.tar.gz" -o fcs.tar.gz
   tar -xzf fcs.tar.gz && sudo mv fcs /usr/local/bin/
   ```

2. **Configure credentials:**
   ```bash
   export FALCON_CLIENT_ID="your-client-id"
   export FALCON_CLIENT_SECRET="your-client-secret"
   export FALCON_CLOUD="us-1"
   ```

3. **Run demo:**
   ```bash
   ./practical-demo.sh
   ```

## Expected Findings:

- **Public images**: 15-50+ vulnerabilities typically found
- **Custom images**: Configuration issues, secrets, outdated packages
- **Base image recommendations**: Use minimal/distroless variants

## Integration Options:

- GitHub Actions (see github-actions-security.yml)
- Docker Compose scanning
- CI/CD pipeline integration
- Kubernetes admission controllers

This scenario provides hands-on experience with container security scanning and demonstrates how to integrate FCS CLI into development workflows.