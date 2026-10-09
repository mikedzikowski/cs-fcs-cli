#!/bin/bash

# FCS CLI Container Scanning Demo Script
# This script demonstrates various FCS CLI scanning capabilities

set -e

echo "🔍 FCS CLI Container Scanning Demo"
echo "=================================="

# Check if FCS CLI is installed
if ! command -v fcs &> /dev/null; then
    echo "❌ FCS CLI not found. Installing..."

    # Detect OS and architecture
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m | sed 's/x86_64/amd64/')

    # Download and install FCS CLI
    echo "📥 Downloading FCS CLI for ${OS}_${ARCH}..."
    curl -L "https://github.com/CrowdStrike/falcon-container-sensor-cli/releases/latest/download/fcs_${OS}_${ARCH}.tar.gz" -o fcs.tar.gz
    tar -xzf fcs.tar.gz
    sudo mv fcs /usr/local/bin/
    chmod +x /usr/local/bin/fcs
    rm -f fcs.tar.gz
    echo "✅ FCS CLI installed successfully"
fi

# Verify installation
echo "📋 FCS CLI Version:"
fcs version

# Check authentication
echo ""
echo "🔐 Checking Falcon API Authentication..."
if [[ -z "$FALCON_CLIENT_ID" ]] || [[ -z "$FALCON_CLIENT_SECRET" ]]; then
    echo "❌ Falcon API credentials not set!"
    echo "Please set the following environment variables:"
    echo "  export FALCON_CLIENT_ID=\"your-client-id\""
    echo "  export FALCON_CLIENT_SECRET=\"your-client-secret\""
    echo "  export FALCON_CLOUD=\"us-1\"  # or us-2, eu-1, us-gov-1"
    exit 1
fi

echo "✅ Credentials configured"

# Build vulnerable test image
echo ""
echo "🏗️  Building vulnerable test image..."
docker build -f Dockerfile.vulnerable -t vulnerable-app:test .
echo "✅ Test image built: vulnerable-app:test"

# Scan public images with known vulnerabilities
echo ""
echo "🔍 Scanning Public Images"
echo "========================"

PUBLIC_IMAGES=(
    "ubuntu:18.04"
    "node:12-alpine"
    "python:3.7-slim"
    "nginx:1.16"
    "mysql:5.7"
)

for image in "${PUBLIC_IMAGES[@]}"; do
    echo ""
    echo "🔍 Scanning: $image"
    echo "----------------------------------------"

    # Pull image if not exists
    docker pull "$image" &>/dev/null || true

    # Scan with FCS CLI
    fcs image scan "$image" --format table --min-severity MEDIUM || true

    # Save detailed results
    output_file="scan-results/${image//[:\/]/_}-scan.json"
    mkdir -p scan-results
    fcs image scan "$image" --format json --output "$output_file" || true
    echo "📄 Results saved to: $output_file"
done

# Scan local vulnerable image
echo ""
echo "🔍 Scanning Local Vulnerable Image"
echo "=================================="
echo "🔍 Scanning: vulnerable-app:test"
fcs image scan vulnerable-app:test --format table || true

# Save detailed results for vulnerable app
fcs image scan vulnerable-app:test --format json --output "scan-results/vulnerable-app-scan.json" || true
echo "📄 Results saved to: scan-results/vulnerable-app-scan.json"

# Demonstrate container scanning (if any are running)
echo ""
echo "🔍 Scanning Running Containers"
echo "============================="

# Check for running containers
if [ "$(docker ps -q)" ]; then
    echo "📋 Running containers found:"
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"

    echo ""
    # Scan each running container
    docker ps --format "{{.Names}}" | while read -r container; do
        if [[ -n "$container" ]]; then
            echo "🔍 Scanning container: $container"
            fcs container scan "$container" --format table || true
            echo ""
        fi
    done
else
    echo "ℹ️  No running containers found"
    echo "💡 Starting a test container for demonstration..."

    # Start nginx container for testing
    docker run -d --name nginx-test nginx:1.16 &>/dev/null || true
    sleep 2

    if docker ps --filter "name=nginx-test" --format "{{.Names}}" | grep -q nginx-test; then
        echo "🔍 Scanning test container: nginx-test"
        fcs container scan nginx-test --format table || true

        # Cleanup test container
        docker stop nginx-test &>/dev/null || true
        docker rm nginx-test &>/dev/null || true
        echo "🧹 Test container cleaned up"
    fi
fi

# Generate summary report
echo ""
echo "📊 Generating Summary Report"
echo "=========================="

REPORT_FILE="scan-results/summary-report.md"
cat > "$REPORT_FILE" << 'EOF'
# Container Security Scan Report

## Scan Summary
Generated on: $(date)

## Images Scanned
EOF

echo "| Image | Vulnerabilities | Critical | High | Medium | Low |" >> "$REPORT_FILE"
echo "|-------|----------------|----------|------|--------|-----|" >> "$REPORT_FILE"

# Parse JSON results and add to report
for json_file in scan-results/*-scan.json; do
    if [[ -f "$json_file" ]]; then
        image_name=$(basename "$json_file" -scan.json | tr '_' ':')
        # Note: This would need actual JSON parsing in a real implementation
        echo "| $image_name | - | - | - | - | - |" >> "$REPORT_FILE"
    fi
done

echo ""
echo "📄 Summary report generated: $REPORT_FILE"

# Display next steps
echo ""
echo "✅ Container Scanning Demo Complete!"
echo "=================================="
echo ""
echo "📋 Next Steps:"
echo "1. Review scan results in the scan-results/ directory"
echo "2. Remediate identified vulnerabilities"
echo "3. Integrate FCS CLI into your CI/CD pipeline"
echo "4. Set up regular scanning schedules"
echo ""
echo "🔗 Resources:"
echo "- FCS CLI Documentation: https://github.com/CrowdStrike/falcon-container-sensor-cli"
echo "- Container Security Best Practices: https://docs.crowdstrike.com/projects/falcon-container-security/"
echo ""