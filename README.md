# FCS CLI IaC Examples

Deliberately insecure infrastructure-as-code for exercising the **Falcon Cloud Security (FCS) CLI** IaC scanner and its VS Code extension.

Scanning `examples/` produces roughly **1,000 findings across 29 files** — useful for demoing the scanner, validating CI/CD wiring, or checking that a rule change still fires.

> [!WARNING]
> **Never deploy anything in this repo.** Every file is intentionally misconfigured. All credentials are well-known non-functional placeholders from public vendor documentation (e.g. `AKIAIOSFODNN7EXAMPLE`) — no real secrets are committed.

## Usage

No Falcon credentials needed; the CLI's bundled local ruleset works offline.

```bash
# Everything
fcs scan iac -p ./examples --policy-rule local

# One platform or scenario
fcs scan iac -p ./examples/kubernetes --policy-rule local
fcs scan iac -p ./examples/scenarios/01-internet-exposed-vm-aws --policy-rule local

# Narrow the output
fcs scan iac -p ./examples --severities critical,high
fcs scan iac -p ./examples --platforms Kubernetes,Dockerfile
```

In VS Code, just open any file under `examples/` — the extension scans on save and shows findings inline.

## Layout

**`examples/<platform>/`** — one directory per platform the FCS CLI supports, each exercising that platform's rules:

| | | |
|---|---|---|
| `terraform` (231) | `cloudformation` (79) | `kubernetes` (63) |
| `openapi` (53) | `docker-compose` (33) | `google-deployment-manager` (27) |
| `helm` (26) | `serverless-framework` (21) | `secrets` (20) |
| `dockerfile` (19) | `ansible` (16) | `azure-arm` (12) |
| `azure-bicep` (3) | `crossplane` (3) | `pulumi` (2) |

**`examples/scenarios/`** — realistic end-to-end deployments organized by *attack path* rather than by platform. Each has a header comment explaining the exposure it models:

| Scenario | Findings | Models |
|---|---:|---|
| `01-internet-exposed-vm-aws` | 160 | Public subnet + `0.0.0.0/0` SG + IMDSv1 + admin instance profile |
| `05-exposed-admin-ports` | 65 | Docker API, etcd, Redis, Mongo, Jenkins, SMB, VNC open to the internet |
| `06-exposed-kubernetes` | 59 | Dashboard via LoadBalancer + anonymous `cluster-admin` |
| `07-public-data-and-images` | 35 | Public buckets, snapshots/AMIs shared with `all`, unauth Lambda URL |
| `04-public-database` | 33 | RDS/SQL/Cosmos published to the internet, unencrypted, no backups |
| `03-internet-exposed-vm-gcp` | 10 | External IP + allow-all firewall + default SA with full scope |
| `02-internet-exposed-vm-azure` | 7 | Public IP + NSG open on RDP/SSH/WinRM + VM identity as Owner |
| `08`–`10` (Bicep) | 0–2 | Exposed VM, public data services, public AKS + ACR — see caveat below |

## Suppression

`examples/terraform/ignore-directives.tf` demonstrates the `fcs-scan` ignore directives.

| Directive | Scope |
|---|---|
| `# fcs-scan ignore-line` | The next line only |
| `# fcs-scan ignore-block` | The whole block below |

`ignore-line` must sit directly above the line a finding **anchors to** — usually the offending attribute, not the `resource` declaration. Suppressed findings leave no audit trail.

## Known caveats

Verified against FCS CLI **3.3.1** with the local ruleset:

- **Bicep barely registers.** The bundled local ruleset has no Bicep platform rules, so `.bicep` files only yield embedded-secret findings, and `--platforms` doesn't accept `Bicep`. Transpiling to ARM JSON (`az bicep build`) routes them through the ARM rules and helps somewhat (scenario 09: 2 → 9 findings). The `.bicep` files are kept as-is so they light up when Bicep rules arrive in a newer CLI or via the cloud ruleset.
- **Crossplane and Pulumi coverage is genuinely small** — 18 and 21 rules respectively, versus hundreds for Terraform. Pulumi is also YAML-only.
- **Azure NSG rules only match standalone `azurerm_network_security_rule` resources**, not inline `security_rule` blocks. Scenario 02 declares both for this reason.
- **Unparseable files report 0 findings silently** rather than erroring — if a directory suddenly returns nothing, check the syntax first.
- **`--output-path` mis-parses directories with a dot in the final segment** (e.g. `mktemp -d` paths like `/tmp/tmp.AbC123`), producing `error while performing scan` and no report. Use a dot-free output directory.

## Rulesets

- **Local** (default without credentials) — bundled rules, results stay on your machine.
- **Combined** — bundled rules plus your CID's custom rules and overrides; used automatically once credentials are configured. Force local-only with `--disable-custom-rules`.

Uploading to the Falcon console is intentionally not the default here, so demo findings don't pollute it:

```bash
fcs scan iac -p ./examples --upload-results --project-name fcs-demo
```
