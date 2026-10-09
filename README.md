# FCS CLI IaC Examples

Deliberately insecure infrastructure-as-code for exercising the **Falcon Cloud Security (FCS) CLI** IaC scanner and its VS Code extension.

Scanning `examples/` produces **1,163 findings across 32 files** spanning AWS, Azure, GCP, Kubernetes, and containers — useful for demoing the scanner's breadth, validating CI/CD wiring, or confirming a rule change still fires. (Local ruleset, FCS CLI 4.2.3.)

> [!WARNING]
> **Never deploy anything in this repo.** Every file is intentionally misconfigured. All credentials are well-known non-functional placeholders from public vendor documentation (e.g. `AKIAIOSFODNN7EXAMPLE`) — no real secrets are committed.

## Usage

No Falcon credentials needed — `--disable-custom-rules` (`-d`) keeps the scan on the bundled local ruleset, entirely offline.

```bash
# Everything
fcs scan iac -p ./examples --disable-custom-rules

# One platform or scenario
fcs scan iac -p ./examples/kubernetes --disable-custom-rules
fcs scan iac -p ./examples/scenarios/01-internet-exposed-vm-aws --disable-custom-rules

# Narrow the output
fcs scan iac -p ./examples --severities critical,high
fcs scan iac -p ./examples --platforms Kubernetes,Dockerfile
fcs scan iac -p ./examples --categories "Access Control","Encryption"
```

> [!IMPORTANT]
> `--policy-rule local` no longer does anything. As of 4.2.x the flag is marked *deprecated, ignored* in `fcs scan iac --help`, and cloud rules are applied by default whenever credentials are configured. Use `--disable-custom-rules` for a reproducible offline baseline. On this repo the difference is large: 1,163 findings local-only vs. 3,663 with cloud custom rules applied.

For container **image** scanning (`fcs scan image`) — a different mode that requires credentials — see [docs/image-scanning.md](docs/image-scanning.md).

### In VS Code

The extension needs no separate CLI install — it downloads and manages its own `fcs` binary under the extension's global storage.

- **Scan on save** is on by default (`fcs.scanOnSave`) for `*.tf`, `*.tfvars`, `*.yaml`, `*.yml`, `*.json`, and `Dockerfile`. Just save a file and findings appear inline as editor diagnostics.
- **Command Palette** (`Cmd/Ctrl+Shift+P`) → **`FCS: Scan Current File`** to scan on demand, or **`FCS: Scan Workspace`** for everything. Also useful: `FCS: Check CLI Status`, `FCS: Clear All Diagnostics`.

There is no right-click / context menu entry — the extension contributes commands only, so use the palette or a keybinding bound to `fcs.scanFile`.

## How robust is the scan?

The bundled local ruleset carries roughly **1,776 rules across 12 platforms**. Rule counts come from the scanner's own `stats.rule_stats.total_rules`:

| Platform | Rules | | Platform | Rules |
|---|---:|---|---|---:|
| Terraform | 539 | | Dockerfile | 48 |
| Serverless FW | 258 | | Azure ARM | 42 |
| CloudFormation | 248 | | Google Deployment Mgr | 32 |
| Ansible | 213 | | Docker Compose | 21 |
| OpenAPI | 194 | | Pulumi | 21 |
| Kubernetes | 142 | | Crossplane | 18 |

Findings are grouped into 14 categories: Access Control, Availability, Backup, Best Practices, Build Process, Encryption, Insecure Configurations, Insecure Defaults, Networking and Firewall, Observability, Resource Management, Secret Management, Supply-Chain, and Structure and Semantics.

## Example results

Real output from `fcs scan iac --disable-custom-rules`, showing the same tool reasoning about three different clouds.

**AWS** — `examples/terraform/main.tf` → 188 findings (4 critical, 141 high)

```
Critical   RDS DB Instance Publicly Accessible
Critical   S3 Bucket ACL Allows Read Or Write to All Users
Critical   S3 Bucket Access to Any Principal
Critical   S3 Bucket With All Permissions
High       AWS Sensitive Port Is Exposed To Entire Network
High       DB Instance Storage Not Encrypted
High       EBS Volume Encryption Disabled
High       EFS Not Encrypted
```

**Azure** — `examples/terraform/azure.tf` → 14 findings (4 high, 7 medium)

```
High       Default Azure Storage Account Network Access Is Too Permissive
High       MSSQL Server Public Network Access Enabled
High       Passwords And Secrets - Generic Password
High       Storage Container Is Publicly Accessible
Medium     AKS Private Cluster Disabled
Medium     AKS RBAC Disabled
Medium     MSSQL Server Auditing Disabled
Medium     Storage Account Not Forcing HTTPS
```

**GCP** — `examples/terraform/gcp.tf` → 22 findings (1 critical, 4 high, 14 medium)

```
Critical   SQL DB Instance Publicly Accessible
High       GKE Legacy Authorization Enabled
High       Google Storage Bucket Level Access Disabled
High       RDP Access Is Not Restricted
High       SQL DB Instance With SSL Disabled
Medium     Cloud Storage Bucket Is Publicly Accessible
Medium     Cloud Storage Bucket Logging Not Enabled
Medium     Cloud Storage Bucket Versioning Disabled
```

Note that rules are cloud-aware rather than generic: it knows about AKS RBAC, GKE legacy ABAC, and S3 bucket policies as distinct concepts.

## Layout

<p align="center">
  <img src="images/image.png" alt="The examples directory in VS Code, showing one directory per supported IaC platform: ansible, azure-arm, azure-bicep, cloudformation, crossplane, docker-compose, dockerfile, google-deployment-manager, helm, kubernetes, openapi, pulumi, scenarios, secrets, serverless-framework, and terraform" width="420">
</p>

**`examples/<platform>/`** — one directory per supported platform, exercising that platform's rules. Findings per directory:

| | | |
|---|---|---|
| `terraform` (318) | `cloudformation` (79) | `kubernetes` (63) |
| `openapi` (53) | `ansible` (53) | `serverless-framework` (49) |
| `docker-compose` (33) | `google-deployment-manager` (27) | `helm` (26) |
| `secrets` (20) | `dockerfile` (19) | `azure-arm` (12) |
| `azure-bicep` (3) | `crossplane` (3) | `pulumi` (2) |

Files named `*breadth*` exist purely to widen rule coverage across many services (CloudFront, API Gateway, Redshift, EKS, MSK, OpenSearch, SageMaker, Neptune, Glue, CodeBuild, and more).

**`examples/scenarios/`** — realistic end-to-end deployments organized by *attack path* rather than platform. Each has a header comment explaining the exposure it models:

| Scenario | Findings | Models |
|---|---:|---|
| `01-internet-exposed-vm-aws` | 160 | Public subnet + `0.0.0.0/0` SG + IMDSv1 + admin instance profile |
| `05-exposed-admin-ports` | 65 | Docker API, etcd, Redis, Mongo, Jenkins, SMB, VNC open to the internet |
| `06-exposed-kubernetes` | 59 | Dashboard via LoadBalancer + anonymous `cluster-admin` |
| `07-public-data-and-images` | 35 | Public buckets, snapshots/AMIs shared with `all`, unauth Lambda URL |
| `04-public-database` | 33 | RDS/SQL/Cosmos published to the internet, unencrypted, no backups |
| `03-internet-exposed-vm-gcp` | 10 | External IP + allow-all firewall + default SA with full scope |
| `02-internet-exposed-vm-azure` | 7 | Public IP + NSG open on RDP/SSH/WinRM + VM identity as Owner |
| `08`–`10` (Bicep) | 0–2 | Exposed VM, public data services, public AKS + ACR — see caveats |

## Suppression

`examples/terraform/ignore-directives.tf` demonstrates the `fcs-scan` ignore directives.

| Directive | Scope |
|---|---|
| `# fcs-scan ignore-line` | The next line only |
| `# fcs-scan ignore-block` | The whole block below |

`ignore-line` must sit directly above the line a finding **anchors to** — usually the offending attribute, not the `resource` declaration. Suppressed findings leave no audit trail.

## Known caveats

Verified against FCS CLI **4.2.3** with the local ruleset:

- **`--policy-rule` is deprecated and silently ignored.** `fcs scan iac --help` labels it *"(deprecated, ignored) Cloud-based rules are now applied by default."* Older guidance that says `--policy-rule local` gives you an offline scan is wrong on 4.2.x: with credentials configured it still fetched 21 cloud rules contributing 2,565 findings. Only `--disable-custom-rules` actually pins the scan to local rules.
- **A clean IaC scan still exits non-zero.** `--fail-on` defaults to `critical=1,high=1,medium=1,informational=1`, so scanning `examples/` exits **40** even though the scan itself succeeded. Don't treat a non-zero exit as a scan failure in CI without setting `--fail-on` deliberately.
- **Bicep barely registers, and upgrading does not fix it.** The bundled ruleset has no Bicep platform rules, so `.bicep` files only yield embedded-secret findings, and `--platforms` doesn't accept `Bicep` (only `AzureResourceManager`). This is unchanged across 3.3.1, 4.2.1, and 4.2.3 — the docs list Azure Bicep as supported, so the coverage likely only arrives via the cloud/combined ruleset. Transpiling to ARM JSON (`az bicep build`) routes the files through the ARM rules and helps somewhat (scenario 09: 2 → 9 findings). The `.bicep` files are kept as-is to re-test against the combined ruleset.
- **Crossplane and Pulumi coverage is genuinely small** — 18 and 21 rules respectively. Pulumi is also YAML-only.
- **Azure NSG rules only match standalone `azurerm_network_security_rule` resources**, not inline `security_rule` blocks. Scenario 02 declares both for this reason.
- **Unparseable files report 0 findings silently** rather than erroring — if a directory suddenly returns nothing, check the syntax first.
- **`--output-path` mis-parses directories with a dot in the final segment** (e.g. `mktemp -d` paths like `/tmp/tmp.AbC123`), producing `error while performing scan` and no report. Use a dot-free output directory.
- **Environment variables beat the profile.** `FALCON_CLIENT_ID` / `FALCON_CLIENT_SECRET` in your shell override `~/.crowdstrike/fcs.json`, so stale exported credentials will fail auth no matter what `fcs configure` wrote. Symptom is an OAuth failure with a valid-looking profile; `unset` them and retry.

## Rulesets

- **Local** — bundled rules only, results stay on your machine. Requires `--disable-custom-rules` when credentials are present. On `examples/`: **1,163 findings** (28 critical, 540 high, 315 medium, 280 informational) across 32 files.
- **Combined** (default once credentials are configured) — bundled rules plus your CID's custom rules and overrides. On `examples/`: **3,663 findings**, the extra 2,565 coming from 21 cloud rules. Counts here depend on your CID's custom rules, so they aren't reproducible across tenants.

Uploading to the Falcon console is intentionally not the default here, so demo findings don't pollute it:

```bash
fcs scan iac -p ./examples --upload-results --project-name fcs-demo
```
