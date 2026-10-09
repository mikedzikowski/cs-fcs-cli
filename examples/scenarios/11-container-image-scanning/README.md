# Scenario 11: Container Image Vulnerability Scanning

## Overview
This scenario demonstrates using CrowdStrike Falcon Container Sensor CLI (FCS CLI) to scan container images for vulnerabilities, both public images and locally running containers.

## Attack Path
- **Vulnerable Dependencies**: Container images often contain outdated packages with known CVEs
- **Base Image Vulnerabilities**: Using vulnerable base images (e.g., outdated Ubuntu, Alpine versions)
- **Exposed Secrets**: Hardcoded credentials, API keys, or certificates in container layers
- **Misconfigurations**: Insecure container configurations, running as root, exposed ports

## Prerequisites
1. **Install FCS CLI**: Download from CrowdStrike's GitHub releases
2. **Authentication**: Set up Falcon API credentials
3. **Docker**: For local image scanning

## FCS CLI Installation

### macOS/Linux
```bash
# Download latest release
curl -L "https://github.com/CrowdStrike/falcon-container-sensor-cli/releases/latest/download/fcs_$(uname -s | tr '[:upper:]' '[:lower:]')_$(uname -m | sed 's/x86_64/amd64/').tar.gz" -o fcs.tar.gz

# Extract and install
tar -xzf fcs.tar.gz
sudo mv fcs /usr/local/bin/
chmod +x /usr/local/bin/fcs
```

### Verify Installation
```bash
fcs version
```

## Authentication Setup

### Method 1: Environment Variables
```bash
export FALCON_CLIENT_ID="your-client-id"
export FALCON_CLIENT_SECRET="your-client-secret"
export FALCON_CLOUD="us-1"  # or us-2, eu-1, us-gov-1
```

### Method 2: Configuration File
```bash
# Create config file
mkdir -p ~/.config/falcon
cat > ~/.config/falcon/config.yaml << EOF
client_id: your-client-id
client_secret: your-client-secret
cloud: us-1
EOF
```

## Scanning Examples

### 1. Scan Public Images

#### High-Risk Base Images
```bash
# Scan vulnerable Ubuntu image
fcs image scan ubuntu:18.04

# Scan outdated Node.js image
fcs image scan node:12-alpine

# Scan vulnerable Python image  
fcs image scan python:3.7-slim

# Scan with detailed output
fcs image scan nginx:1.16 --format json --output nginx-scan.json
```

#### Popular Images with Known Issues
```bash
# WordPress with vulnerabilities
fcs image scan wordpress:5.0

# MySQL with security issues
fcs image scan mysql:5.7

# Redis with misconfigurations
fcs image scan redis:5.0-alpine
```

### 2. Scan Local Images

#### Build and Scan Custom Images
```bash
# Build a vulnerable image
docker build -t vulnerable-app:latest ./dockerfile/

# Scan the local image
fcs image scan vulnerable-app:latest

# List all local images and scan
docker images --format "table {{.Repository}}:{{.Tag}}" | tail -n +2 | while read image; do
    echo "Scanning: $image"
    fcs image scan "$image" --format table
    echo "---"
done
```

#### Scan Running Containers
```bash
# List running containers
docker ps --format "table {{.Names}}\t{{.Image}}"

# Scan specific running container
fcs container scan container-name

# Scan all running containers
docker ps --format "{{.Names}}" | while read container; do
    echo "Scanning container: $container"
    fcs container scan "$container"
done
```

### 3. Advanced Scanning Options

#### Detailed Vulnerability Analysis
```bash
# Scan with severity filtering
fcs image scan alpine:latest --min-severity HIGH

# Scan with policy enforcement
fcs image scan ubuntu:20.04 --policy-file security-policy.yaml

# Scan and generate SARIF output for CI/CD
fcs image scan myapp:latest --format sarif --output results.sarif
```

#### Bulk Scanning Script
```bash
#!/bin/bash
# bulk-scan.sh - Scan multiple images

IMAGES=(
    "nginx:latest"
    "apache:latest" 
    "postgres:13"
    "mongo:4.4"
    "elasticsearch:7.10.0"
)

for image in "${IMAGES[@]}"; do
    echo "Scanning $image..."
    fcs image scan "$image" --format json --output "${image//[:\/]/_}-scan.json"
    echo "Results saved to ${image//[:\/]/_}-scan.json"
done
```

## CI/CD Integration

### GitHub Actions
```yaml
name: Container Security Scan
on: [push, pull_request]

jobs:
  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build Docker image
        run: docker build -t ${{ github.repository }}:${{ github.sha }} .
        
      - name: Install FCS CLI
        run: |
          curl -L "https://github.com/CrowdStrike/falcon-container-sensor-cli/releases/latest/download/fcs_linux_amd64.tar.gz" -o fcs.tar.gz
          tar -xzf fcs.tar.gz
          sudo mv fcs /usr/local/bin/
          
      - name: Scan image
        env:
          FALCON_CLIENT_ID: ${{ secrets.FALCON_CLIENT_ID }}
          FALCON_CLIENT_SECRET: ${{ secrets.FALCON_CLIENT_SECRET }}
          FALCON_CLOUD: us-1
        run: |
          fcs image scan ${{ github.repository }}:${{ github.sha }} --format sarif --output security-results.sarif
          
      - name: Upload results
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: security-results.sarif
```

### Docker Compose with Security Scanning
```yaml
# docker-compose.scan.yml
version: '3.8'
services:
  app:
    build: .
    image: myapp:latest
    
  security-scanner:
    image: crowdstrike/fcs:latest
    depends_on:
      - app
    environment:
      - FALCON_CLIENT_ID=${FALCON_CLIENT_ID}
      - FALCON_CLIENT_SECRET=${FALCON_CLIENT_SECRET}
      - FALCON_CLOUD=${FALCON_CLOUD}
    command: ["fcs", "image", "scan", "myapp:latest"]
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./scan-results:/results
```

## Expected Findings

### Common Vulnerabilities
- **CVE-2021-44228**: Log4Shell in Java applications
- **CVE-2021-3156**: Sudo vulnerability in Linux base images
- **CVE-2020-1472**: Zerologon in Windows containers
- **CVE-2019-5021**: Docker registry vulnerabilities

### Security Misconfigurations
- Running containers as root user
- Exposed unnecessary ports
- Weak file permissions
- Missing security updates

### Sample Output
```json
{
  "scan_id": "12345678-1234-1234-1234-123456789012",
  "image": "nginx:1.16",
  "vulnerabilities": [
    {
      "cve": "CVE-2019-20372",
      "severity": "HIGH", 
      "description": "Nginx HTTP request smuggling vulnerability",
      "package": "nginx",
      "version": "1.16.1",
      "fixed_version": "1.18.0"
    }
  ],
  "total_vulnerabilities": 15,
  "critical": 2,
  "high": 5,
  "medium": 6,
  "low": 2
}
```

## Remediation Steps

1. **Update Base Images**: Use latest stable versions
2. **Multi-stage Builds**: Remove build dependencies from final image
3. **Minimal Images**: Use distroless or Alpine variants
4. **Regular Scanning**: Integrate into CI/CD pipelines
5. **Policy Enforcement**: Block deployments of vulnerable images

## References
- [CrowdStrike FCS CLI Documentation](https://github.com/CrowdStrike/falcon-container-sensor-cli)
- [Container Security Best Practices](https://docs.crowdstrike.com/projects/falcon-container-security/)
- [NIST Container Security Guidelines](https://csrc.nist.gov/publications/detail/sp/800-190/final)