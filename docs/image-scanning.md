# Container image scanning with the FCS CLI

The rest of this repo exercises `fcs scan iac`, which runs fully offline against a bundled ruleset. Image scanning is a **different mode** with different requirements, so it lives here rather than as an `examples/scenarios/` entry.

| | `fcs scan iac` | `fcs scan image` |
|---|---|---|
| Credentials | Not required (`--disable-custom-rules`) | **Required** |
| Network | Offline | Sends image inventory to the CrowdStrike cloud |
| Input | Files in this repo | A container image your runtime can access |

Image files are never uploaded. The CLI inventories the image locally and sends only that package inventory; the cloud returns the assessment. Reports and inventories are ephemeral unless you pass `--upload`.

Everything below was verified against **FCS CLI 4.2.3** on macOS arm64.

## Install

There is no public GitHub release of the FCS CLI — it is distributed through the Falcon console and the CrowdStrike API.

**Via the console:** Support and resources > Resources and tools > Tool downloads, then search for `CLI`.

**Already have it?** `fcs update` works on 0.42.0+. On 2.1.7+ the API client needs `Cloud Security Tools Download: Read`.

**Programmatically** (needs `jq` and `curl`). Pick the API base URL for your cloud — `us-1` → `https://api.crowdstrike.com`, `us-2` → `https://api.us-2.crowdstrike.com`, `eu-1` → `https://api.eu-1.crowdstrike.com`, `us-gov-1` → `https://api.laggar.gcw.crowdstrike.com`, `us-gov-2` → `https://api.us-gov-2.crowdstrike.mil`:

```bash
FALCON_API_URL="https://api.crowdstrike.com"

TOK=$(curl -s --request POST \
  --header "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "client_id=${FALCON_CLIENT_ID}" \
  --data-urlencode "client_secret=${FALCON_CLIENT_SECRET}" \
  --url "${FALCON_API_URL}/oauth2/token" | jq -r '.access_token')

# Enumerate builds. os: darwin|linux|windows, arch: arm64|amd64
curl -s --get \
  --header 'accept: application/json' \
  --header "Authorization: Bearer ${TOK}" \
  --url "${FALCON_API_URL}/csdownloads/combined/files-download/v2" \
  --data-urlencode 'filter=category:"fcs"+os:"darwin"+arch:"arm64"' \
| jq -r '.resources[] | "\(.file_name)\t\(.file_version)\t\(.file_hash)"'
```

That returns a `download_info.download_url` per build. Download it, **check the hash against `file_hash`**, then extract and put it on your `PATH` (`/opt/homebrew/bin` on Apple Silicon, `/usr/local/bin` on Intel macOS and Linux):

```bash
tar -xzf fcs_*.tar.gz
chmod u+x fcs
fcs version
```

The CLI is also published as a Linux/arm64 container image in the CrowdStrike registry, which is the better fit for containerized pipelines.

### API scopes

| Scope | Permission | Needed for |
|---|---|---|
| Cloud Security Tools Download | Read | Always (download + `fcs update`) |
| Falcon Container CLI | Read/Write | Image scanning |
| Falcon Container Image | Read/Write | Image scanning |
| Infrastructure as Code | Read/Write | IaC scanning |

### Credentials

`fcs configure` writes a profile to `~/.crowdstrike/fcs.json`. Precedence is **command-line flags > environment variables > profile**.

> [!WARNING]
> That precedence bites. A stale `FALCON_CLIENT_ID` / `FALCON_CLIENT_SECRET` exported in your shell will override a perfectly good profile and fail OAuth. If auth fails with a profile you believe is correct, `unset` them and retry.

`--falcon-region` accepts `us-1`, `us-2`, `us-3`, `eu-1`, `us-gov-1`, `us-gov-2`, and is auto-discovered if omitted.

## Scanning

The image is a **positional argument**. The `--image` flag appears in `--help` but `fcs scan image --image alpine:3.21` fails with `image path is required` — use the positional form:

```bash
fcs scan image alpine:3.21                      # from your local store, or pulled by your runtime
fcs scan image ./myimage.tar                    # a compressed image file
fcs scan image myregistry.io/team/app:1.4.2     # private registry
```

The CLI goes through your local container runtime, so **authenticate your runtime first** (`docker login`, `podman login`) for private registries. Supported runtimes: Docker, Podman, containerd (nerdctl and ctr), and CRI-O. Use `--socket` for a non-default socket, e.g. `--socket unix:///var/run/docker.sock`.

Multi-arch images are scanned for **every** platform in the manifest by default, which also means one report file per architecture. Narrow it with `--platform`:

```bash
fcs scan image alpine:3.21 --platform linux/amd64
fcs scan image alpine:3.21 --platform linux/arm64,linux/amd64
fcs scan image mcr.microsoft.com/windows/servercore:ltsc2025 --platform windows/amd64
```

Large images or slow networks can blow past the default 300-second timeout, surfacing as `context deadline exceeded`. Raise it with `--timeout 600`.

### Real output

`fcs scan image debian:10-slim --platform linux/amd64`:

```
📋 Policy Evaluation Results
┌─────────────────────────┬──────────────────────────────────────────┐
│ FIELD                   │ VALUE                                    │
├─────────────────────────┼──────────────────────────────────────────┤
│ Result                  │ NO ACTION                                │
│ Policy Name             │ Supply Chain Policy                      │
│ Policy Type             │ Image Assessment Prevention Policy       │
│ Evaluated At            │ 2026-10-09T13:47:34Z                     │
└─────────────────────────┴──────────────────────────────────────────┘

Total Vulnerabilities: 75 (Critical: 0, High: 1, Medium: 1, Low: 73, Unknown: 0)
Total Detections: 13 (Critical: 0, High: 1, Medium: 11, Low: 1, Unknown: 0)
```

Reports land in `~/.crowdstrike/image_assessment/reports/<image>_<timestamp>.<ext>` unless you pass `--output`.

Two result types come back. **Vulnerabilities** are CVEs in the image's packages, carrying an ExPRT rating, CVSS score, exploit status, and fixed version. **Detections** are misconfigurations, exposed secrets, and CIS findings. `alpine:3.21` is a good minimal demo — it produces 5 vulnerabilities and 24 detections across its 8 manifest platforms, including:

```
Misconfiguration  High    RunningAsRootContainer
CIS               Medium  ADDInstructionInDockerfile
Misconfiguration  Low     UserInstructionNotInDockerfile
```

## Gating a pipeline

Exit codes reflect the image assessment policy:

| Code | Meaning |
|---|---|
| `0` | Image met the policy requirements |
| `1` | Did not meet requirements — **block** |
| `2` | Did not meet requirements — **alert** |

```bash
fcs scan image "$IMAGE" --platform linux/amd64 || {
  echo "image assessment failed policy (exit $?)"
  exit 1
}
```

Note the asymmetry with IaC scans, which exit `40` on this repo purely because of `--fail-on` defaults. For image scans a non-zero exit is a real policy signal.

### GitHub Action

CrowdStrike publishes [`crowdstrike/fcs-action`](https://github.com/marketplace/actions/crowdstrike-fcs-cli-github-action), which also normalizes output for GitHub's SARIF 2.1.0 parser:

```yaml
- name: Scan container image
  uses: crowdstrike/fcs-action@v4.0.1
  id: fcs
  with:
    falcon_client_id: ${{ vars.FALCON_CLIENT_ID }}
    falcon_region: 'us-1'
    scan_type: image
    image: nginx:latest
    output_path: './image-scan-results.json'
    report_formats: json
  env:
    FALCON_CLIENT_SECRET: ${{ secrets.FALCON_CLIENT_SECRET }}

- name: Fail the build
  if: steps.fcs.outputs.exit-code != 0
  run: exit 1
```

## Report formats and filters

`--format` accepts `json` (default), `sarif`, and `cyclonedx-json`.

> [!NOTE]
> `fcs scan image --help` misspells the third value as `cylconedx-json`. That spelling is rejected — the CLI's own error message confirms `Allowed values are: json, sarif, cyclonedx-json`.

`--sbom-only` produces a CycloneDX SBOM with no policy evaluation, vulnerabilities, or detections, and no on-screen output.

Policy outcome is machine-readable in every format: `PolicyResponse.deny` in JSON, `artifacts.properties.policyResponse.deny` in SARIF, `metadata.properties.name="policy:deny"` in SBOM. `.action` alongside it says Prevent or Alert, and is only present when `deny` is true.

Useful filters:

| Flag | Effect |
|---|---|
| `--minimum-severity` | Vulnerabilities at or above `low`/`medium`/`high`/`critical` |
| `--minimum-exprt` | Same, by ExPRT rating |
| `--minimum-score` | CVSS floor, `0.0`–`10.0` |
| `--minimum-detection-severity` | Detections — **on-screen only**, the saved report keeps all |
| `--vuln-fixable-only` | Drop vulnerabilities with no fix (on-screen only) |
| `--exclude-vulnerabilities` | Comma-separated CVE IDs, case-sensitive |
| `--vulnerability-only` | Drop policy evaluation and detections |
| `--show-full-description` | Stop truncating long text with `...` |
| `--no-color` | Monochrome, for logs |

Every flag has an environment-variable equivalent (`FCS_MINIMUM_SEVERITY`, `FCS_NO_COLOR`, and so on).

## Getting results into the console

Local by default, which keeps dev noise out of your tenant. `--upload` is what makes results visible in **Cloud security > Vulnerabilities > Image assessments** (Source column shows `CLI`), retrievable by API, and available to the Kubernetes Admission Controller.

```bash
fcs scan image "$IMAGE" --upload
fcs scan image "$IMAGE" --upload --scan-only   # console only, no local report
```

`--scan-only` requires `--upload`, otherwise results go nowhere. Uploading also switches retention from ephemeral to indefinite, with periodic re-scans for new CVEs.

## Gotchas

- **Assessments are cached by registry + repository + tag + digest.** A matching image returns the *existing* report rather than re-assessing, even if the first assessment came from a different method (registry connection, SHRA). The console's Source column keeps the original method.
- **`docker push` changes the image digest**, so the same image can appear repeatedly in the console under different digests. Use `crane` or `skopeo` to preserve digests.
- **Windows images legitimately have empty `path` fields** on some findings — OS-level CVEs matched by build number or registry identity aren't tied to a file on disk.
- **`--strict-digest`** fails the scan if the image has uncompressed layers that can't be pulled with correct digests. Worth enabling when digest accuracy matters.

## Sources

CrowdStrike product documentation: *About the FCS CLI*, *About Image Assessment with the FCS CLI*, *Assess images with the FCS CLI*, *FCS CLI Image Scan Results*, *FCS CLI Image Scan Filters*, *FCS CLI Command Reference*, *Download the FCS CLI Binary*, *Download the FCS CLI Binary Programmatically*, *Scan Images with the FCS CLI GitHub Action*. Commands, exit codes, flag spellings, and output samples re-verified by running 4.2.3.
