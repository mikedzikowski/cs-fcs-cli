#!/usr/bin/env bash
# Scan every example directory and print a per-platform finding count.
# Uses the local (bundled) ruleset, so no Falcon credentials are required.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

REPORT_DIR="scan-reports"
mkdir -p "$REPORT_DIR"

printf '%-28s %s\n' "PLATFORM DIRECTORY" "RESULT"
printf '%-28s %s\n' "------------------" "------"

for dir in examples/*/; do
  name="$(basename "$dir")"
  out="$REPORT_DIR/$name"
  mkdir -p "$out"

  summary=$(fcs scan iac \
    --path "$dir" \
    --policy-rule local \
    --report-formats json \
    --output-path "$out" 2>&1 \
    | tr -d '\r' \
    | sed 's/\x1b\[[0-9;]*m//g' \
    | grep -E '^(Critical|High|Medium|Informational|Total):' \
    | tr '\n' ' ')

  if [ -z "$summary" ]; then
    summary="no findings or scan error (see $out)"
  fi

  printf '%-28s %s\n' "$name" "$summary"
done

echo
echo "JSON reports written under ./$REPORT_DIR/"
