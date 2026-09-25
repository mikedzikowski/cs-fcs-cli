#!/usr/bin/env bash
# Workaround for Bicep coverage with the local ruleset.
#
# FCS CLI 3.3.1's bundled local ruleset has no Azure Bicep platform rules, so a
# raw .bicep file only yields embedded-secret findings. Transpiling to ARM JSON
# first routes the file through the AzureResourceManager rules instead.
#
# Usage: ./scripts/scan-bicep.sh [path/to/file.bicep]
set -euo pipefail

cd "$(dirname "$0")/.."

SRC="${1:-examples/azure-bicep/insecure.bicep}"
OUT_DIR="scan-reports/azure-bicep-transpiled"
OUT_JSON="$OUT_DIR/$(basename "${SRC%.bicep}").json"

if ! az bicep version >/dev/null 2>&1; then
  echo "error: 'az bicep' is required. Install with: az bicep install" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

echo "Transpiling $SRC -> $OUT_JSON"
az bicep build --file "$SRC" --outfile "$OUT_JSON"

echo
echo "Scanning raw .bicep (secrets rules only):"
fcs scan iac --path "$SRC" --policy-rule local

echo
echo "Scanning transpiled ARM JSON (AzureResourceManager rules):"
fcs scan iac --path "$OUT_JSON" --policy-rule local
