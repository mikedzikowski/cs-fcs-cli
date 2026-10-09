#!/bin/bash

# Practical FCS CLI Demo Script for Available Images
# This script demonstrates scanning real images in your environment

set -e

echo "🔍 FCS CLI Practical Demo - Using Available Images"
echo "================================================="

# Create scan results directory
mkdir -p scan-results

# Check if FCS CLI is available (simulated output for demo)
echo "📋 Available Images for Scanning:"
echo "================================"

# List some high-value targets from your available images
TARGET_IMAGES=(
    "ubuntu:22.04"
    "debian:10-slim"
    "alpine:latest"
    "node:18-alpine"
    "redis:7-alpine"
    "registry.access.redhat.com/ubi9/ubi:latest"
)

echo "Public Images (good candidates for vulnerability scanning):"
for image in "${TARGET_IMAGES[@]}"; do
    if docker image inspect "$image" &>/dev/null; then
        echo "  ✅ $image (available locally)"
    else
        echo "  ⚠️  $image (not available - would need docker pull)"
    fi
done

echo ""
echo "Custom/Private Images (potentially vulnerable):"
# Your custom alpine-lab-app images that likely contain vulnerabilities
CUSTOM_IMAGES=(
    "alpine-lab-app:latest"
    "alpine-lab-app:enhanced"
    "alpine-lab-app:diagnostic"
    "alpine-lab-app:ubuntu"
    "my-app:latest"
)

for image in "${CUSTOM_IMAGES[@]}"; do
    if docker image inspect "$image" &>/dev/null; then
        echo "  🎯 $image (custom - likely has findings)"
    fi
done

echo ""
echo "🔍 Demonstration: What FCS CLI Would Find"
echo "========================================"

# Simulate FCS CLI scanning output for demonstration
echo ""
echo "Example: Scanning ubuntu:22.04"
echo "------------------------------"
cat << 'EOF'
$ fcs image scan ubuntu:22.04

┌─────────────────────────────────────────────────────────────────────────────────┐
│ Image: ubuntu:22.04                                                             │
│ Scan ID: scan-123456789                                                         │
│ Scan Time: 2024-10-09T08:55:00Z                                                │
└─────────────────────────────────────────────────────────────────────────────────┘

Vulnerability Summary:
├─ Critical: 2
├─ High: 8
├─ Medium: 15
├─ Low: 23
└─ Total: 48

Top Critical Vulnerabilities:
┌─────────────────┬──────────┬─────────────────────────────────────────────────────┐
│ CVE             │ Package  │ Description                                         │
├─────────────────┼──────────┼─────────────────────────────────────────────────────┤
│ CVE-2023-4911   │ glibc    │ Buffer overflow in ld.so                          │
│ CVE-2023-29491  │ ncurses  │ Segmentation fault via crafted data               │
└─────────────────┴──────────┴─────────────────────────────────────────────────────┘

Configuration Issues:
├─ Running as root user
├─ No health check defined
└─ Base image contains unnecessary packages

Recommendations:
1. Update to ubuntu:24.04 for latest security patches
2. Use distroless or minimal base images when possible
3. Implement multi-stage builds to reduce attack surface
4. Add non-root user configuration
EOF

echo ""
echo ""
echo "Example: Scanning alpine-lab-app:latest (Custom App)"
echo "---------------------------------------------------"
cat << 'EOF'
$ fcs image scan alpine-lab-app:latest

┌─────────────────────────────────────────────────────────────────────────────────┐
│ Image: alpine-lab-app:latest                                                    │
│ Scan ID: scan-987654321                                                         │
│ Scan Time: 2024-10-09T08:55:00Z                                                │
└─────────────────────────────────────────────────────────────────────────────────┘

Vulnerability Summary:
├─ Critical: 0
├─ High: 2
├─ Medium: 5
├─ Low: 8
└─ Total: 15

Security Issues Found:
┌─────────────────┬──────────┬─────────────────────────────────────────────────────┐
│ Type            │ Severity │ Description                                         │
├─────────────────┼──────────┼─────────────────────────────────────────────────────┤
│ Configuration   │ HIGH     │ Container runs as root (UID 0)                    │
│ Configuration   │ HIGH     │ Privileged capabilities not dropped               │
│ Package         │ MEDIUM   │ openssl 3.1.1 has known vulnerabilities          │
│ Secrets         │ MEDIUM   │ Potential API key found in layer                  │
│ Configuration   │ MEDIUM   │ No security context defined                       │
└─────────────────┴──────────┴─────────────────────────────────────────────────────┘

Supply Chain Analysis:
├─ Base image: alpine:3.18 (moderate risk)
├─ Packages: 23 installed, 3 with known CVEs
└─ Layer analysis: 8 layers, 1 potential secret detected

Recommendations:
1. Switch to non-root user
2. Drop unnecessary Linux capabilities
3. Update openssl package
4. Remove or externalize embedded secrets
5. Add security context configuration
EOF

echo ""
echo ""
echo "🚀 Running Live Demo with Available Images"
echo "=========================================="

# Let's actually inspect one of the available images to show real data
echo ""
echo "📊 Real Image Analysis: alpine:latest"
echo "------------------------------------"

if docker image inspect alpine:latest &>/dev/null; then
    echo "Image Details:"
    docker image inspect alpine:latest --format '
├─ Image ID: {{.Id}}
├─ Created: {{.Created}}
├─ Size: {{.Size}} bytes
├─ Architecture: {{.Architecture}}
├─ OS: {{.Os}}
└─ Layers: {{len .RootFS.Layers}}'

    echo ""
    echo "Layer History:"
    docker history alpine:latest --format "table {{.CreatedBy}}\t{{.Size}}" | head -5

    echo ""
    echo "Package Information (if available):"
    # This would show what packages are in the image
    docker run --rm alpine:latest apk list --installed 2>/dev/null | head -10 || echo "  (Package list not accessible without container execution)"
fi

echo ""
echo "🔧 Setting Up Your Environment for Real FCS CLI Scanning"
echo "======================================================="

echo ""
echo "1. Install FCS CLI:"
echo "   # For macOS:"
echo "   curl -L 'https://github.com/CrowdStrike/falcon-container-sensor-cli/releases/latest/download/fcs_darwin_amd64.tar.gz' -o fcs.tar.gz"
echo "   tar -xzf fcs.tar.gz && sudo mv fcs /usr/local/bin/"
echo ""
echo "2. Configure Falcon API credentials:"
echo "   export FALCON_CLIENT_ID='your-client-id'"
echo "   export FALCON_CLIENT_SECRET='your-client-secret'"
echo "   export FALCON_CLOUD='us-1'  # or us-2, eu-1, etc."
echo ""
echo "3. Test the installation:"
echo "   fcs version"
echo "   fcs auth test"
echo ""
echo "4. Start scanning your images:"
echo "   # Scan public images"
echo "   fcs image scan ubuntu:22.04"
echo "   fcs image scan alpine:latest"
echo ""
echo "   # Scan your custom images"
echo "   fcs image scan alpine-lab-app:latest"
echo "   fcs image scan my-app:latest"
echo ""
echo "   # Bulk scan with JSON output"
echo "   for img in alpine:latest ubuntu:22.04 node:18-alpine; do"
echo "     fcs image scan \"\$img\" --format json --output \"scan-results/\${img//[:\/]/_}.json\""
echo "   done"

echo ""
echo "📋 Images in Your Environment Prime for Scanning:"
echo "================================================"

# Show specific images that would be interesting to scan
echo ""
echo "🎯 High-Value Scan Targets:"
echo "  • ubuntu:22.04 - Popular base image, likely has CVEs"
echo "  • debian:10-slim - Older version, potential vulnerabilities"
echo "  • node:18-alpine - JavaScript runtime, dependency risks"
echo "  • redis:7-alpine - Database, configuration risks"
echo "  • registry.access.redhat.com/ubi9/ubi:latest - Enterprise base image"
echo ""
echo "🔍 Custom Images to Investigate:"
echo "  • alpine-lab-app:* - Your custom applications"
echo "  • my-app:latest - Custom application"
echo "  • wizconvertv3-* - Appears to be custom applications"
echo ""
echo "💡 Pro Tips:"
echo "  • Start with public base images to understand baseline risk"
echo "  • Focus on custom applications - they often have more findings"
echo "  • Use --min-severity HIGH to focus on critical issues first"
echo "  • Save JSON outputs for tracking and reporting"
echo "  • Integrate scanning into your CI/CD pipelines"

echo ""
echo "✅ Demo Complete!"
echo "================"
echo ""
echo "This demonstration showed what FCS CLI scanning looks like."
echo "To run actual scans, install FCS CLI and configure your Falcon API credentials."
echo ""
echo "Next steps:"
echo "1. Get your Falcon API credentials from the CrowdStrike console"
echo "2. Install FCS CLI using the commands shown above"
echo "3. Run the demo script: ./demo-scan.sh"
echo "4. Review findings and implement remediation"
echo ""