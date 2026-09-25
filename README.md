# FCS CLI IaC Detection Examples

A deliberately insecure sample repo for exercising the **Falcon Cloud Security (FCS) CLI** IaC scanner — one example per supported platform, each written to trigger real detections.

Use it to demo the [FCS CLI VS Code extension](https://marketplace.visualstudio.com/items?itemName=crowdstrike.fcs-vscode), validate CI/CD pipeline wiring, or learn what the scanner catches.

> [!WARNING]
> **Never deploy anything in this repo.** Every file is intentionally misconfigured — public buckets, wide-open security groups, privileged containers, wildcard IAM. All credentials are well-known non-functional placeholders from public vendor documentation (e.g. `AKIAIOSFODNN7EXAMPLE`); none grant access to anything.

## Quick start

No Falcon credentials are required — the bundled local ruleset works offline.

```bash
# Scan everything
fcs scan iac -p ./examples --policy-rule local

# Per-platform breakdown
./scripts/scan-all.sh

# One platform
fcs scan iac -p ./examples/kubernetes --policy-rule local
```

In VS Code, just open any file under `examples/` — the extension scans on edit and flags findings inline.

## Verified results

Measured with FCS CLI **3.3.1** using the local ruleset (`fcs scan iac --policy-rule local`):

| Platform | Path | Critical | High | Medium | Info | Total |
|---|---|---:|---:|---:|---:|---:|
| Terraform (AWS/Azure/GCP) | `examples/terraform/` | 5 | 150 | 38 | 38 | **231** |
| CloudFormation (YAML + JSON) | `examples/cloudformation/` | 4 | 25 | 31 | 19 | **79** |
| Kubernetes | `examples/kubernetes/` | 0 | 16 | 26 | 21 | **63** |
| OpenAPI | `examples/openapi/` | 0 | 1 | 10 | 42 | **53** |
| Docker Compose | `examples/docker-compose/` | 0 | 12 | 18 | 3 | **33** |
| Google Deployment Manager | `examples/google-deployment-manager/` | 2 | 7 | 17 | 1 | **27** |
| Kubernetes (Helm) | `examples/helm/` | 0 | 5 | 11 | 10 | **26** |
| Serverless Framework | `examples/serverless-framework/` | 1 | 6 | 7 | 7 | **21** |
| Secrets (embedded credentials) | `examples/secrets/` | 0 | 14 | 3 | 3 | **20** |
| Dockerfile | `examples/dockerfile/` | 0 | 5 | 7 | 7 | **19** |
| Ansible | `examples/ansible/` | 3 | 7 | 5 | 1 | **16** |
| Azure Resource Manager | `examples/azure-arm/` | 1 | 3 | 5 | 3 | **12** |
| Crossplane | `examples/crossplane/` | 1 | 2 | 0 | 0 | **3** |
| Azure Bicep | `examples/azure-bicep/` | 0 | 3 | 0 | 0 | **3** |
| Pulumi | `examples/pulumi/` | 1 | 1 | 0 | 0 | **2** |

Counts will shift with CLI version and ruleset. If you configure API credentials, the CLI uses the *combined* ruleset (bundled rules plus your CID's custom rules and overrides), which generally yields more findings.

### Why Crossplane and Pulumi look thin

Their coverage is genuinely small — the local ruleset ships **18 Crossplane rules** and **21 Pulumi rules**, versus hundreds for Terraform. The handful of findings is close to the practical maximum. (Pulumi is also YAML-only; the scanner ignores Pulumi programs written in TypeScript, Python, Go, or C#.)

### Azure Bicep needs a transpile step

CLI 3.3.1's local ruleset has **no Bicep platform rules** — a raw `.bicep` file only produces embedded-secret findings, and `--platforms` doesn't accept `Bicep` (only `AzureResourceManager`). Transpiling to ARM JSON first routes the file through the ARM rules:

```bash
./scripts/scan-bicep.sh
```

That takes `examples/azure-bicep/insecure.bicep` from **3 findings to 15**. The same `.bicep` file is kept as-is so you can re-test when Bicep rules land in a future CLI version or arrive via the cloud ruleset.

## What's in each example

| Platform | File | Representative detections |
|---|---|---|
| Terraform | `examples/terraform/main.tf` | Public S3 ACL + bucket policy, no encryption/versioning/logging, world-open security group, IMDSv1, unencrypted EBS/EFS/SQS/SNS, public unencrypted RDS, wildcard IAM policy, weak CloudTrail |
| Terraform | `examples/terraform/azure.tf` | Storage over HTTP with TLS 1.0 and public blobs, NSG open on 22/3389, SQL Server public with `0.0.0.0-255.255.255.255` firewall, AKS without RBAC, Key Vault without purge protection |
| Terraform | `examples/terraform/gcp.tf` | Bucket public to `allUsers`, firewall open to `0.0.0.0/0`, VM with serial port + full-scope default SA + shielded VM off, GKE legacy ABAC, public Cloud SQL without SSL, `roles/owner` to `allAuthenticatedUsers` |
| Terraform | `examples/terraform/ignore-directives.tf` | Demonstrates **suppression** rather than detection — see below |
| CloudFormation | `examples/cloudformation/insecure-stack.yaml` | `PublicReadWrite` bucket, open security group, wildcard managed policy, role assumable by `*`, public unencrypted RDS, IMDSv1, plain HTTP listener |
| CloudFormation | `examples/cloudformation/insecure-stack.json` | JSON-syntax equivalent: public bucket, open SG, wildcard IAM, unencrypted volume, DynamoDB without PITR |
| Azure Bicep | `examples/azure-bicep/insecure.bicep` | Storage without HTTPS, public container, NSG open to Internet, VM with password auth, SQL open firewall, Key Vault without soft delete, App Service with remote debugging |
| Azure ARM | `examples/azure-arm/azuredeploy.json` | Same shape as the Bicep file in raw ARM JSON, plus a plaintext `string` password param instead of `securestring` |
| Kubernetes | `examples/kubernetes/insecure-deployment.yaml` | `hostNetwork`/`hostPID`/`hostIPC`, privileged root container with `CAP_ALL`, `:latest` image, no resource limits or probes, host root + Docker socket mounts, plaintext Secret, wildcard ClusterRole bound to `system:anonymous`, Ingress without TLS |
| Helm | `examples/helm/fcs-demo-chart/` | Insecure `values.yaml` defaults rendered through a templated Deployment |
| Dockerfile | `examples/dockerfile/Dockerfile` | `:latest` base, secrets in `ENV`/`ARG`, unpinned `apt-get`, `curl \| bash`, TLS verification disabled, `ADD` from URL, `chmod 777`, passwordless sudo, runs as root, no `HEALTHCHECK` |
| Docker Compose | `examples/docker-compose/docker-compose.yml` | `privileged`, host namespaces, `cap_add: ALL`, unconfined seccomp/AppArmor, host root + Docker socket mounts, hardcoded credentials, `MYSQL_ALLOW_EMPTY_PASSWORD` |
| Ansible | `examples/ansible/insecure-playbook.yml` | `mode: "0777"`, `validate_certs: false`, `curl \| bash`, unquoted variable in a shell command, passwordless sudo, `PermitRootLogin yes`, firewall stopped, insecure AWS module calls |
| Google Deployment Manager | `examples/google-deployment-manager/config.yaml` | Bucket ACL to `allUsers`, firewall open to all ports, VM with serial port + IP forwarding, public Cloud SQL, GKE with legacy ABAC and logging/monitoring off |
| Crossplane | `examples/crossplane/insecure-resources.yaml` | Public S3 `Bucket`, public unencrypted `RDSInstance`, open `SecurityGroup`, wildcard IAM `Policy` |
| Pulumi | `examples/pulumi/Pulumi.yaml` | Public bucket, open security group, public unencrypted RDS, wildcard IAM policy, unencrypted EBS/SQS |
| OpenAPI | `examples/openapi/insecure-api.yaml` | `http://` server, basic auth, API key in query string, OAuth2 implicit flow with wildcard scope, operations with `security: []`, missing error responses |
| Serverless Framework | `examples/serverless-framework/serverless.yml` | EOL `nodejs12.x`, tracing off, plaintext secrets in `environment`, wildcard IAM statement, unauthenticated HTTP events, public bucket, DynamoDB without PITR |
| Secrets | `examples/secrets/hardcoded-secrets.tf` | Hardcoded provider keys, passwords, connection strings with inline credentials, vendor-style API keys, JWT, private key material |

## Demonstrating suppression

`examples/terraform/ignore-directives.tf` shows the `fcs-scan` ignore directives. An `ignore-block` suppresses a wide-open security group entirely, an `ignore-line` suppresses a critical public-ACL finding, and a third unsuppressed resource still reports.

```bash
fcs scan iac -p examples/terraform/ignore-directives.tf --policy-rule local
```

Delete a directive and re-scan to watch the suppressed findings reappear.

| Directive | Scope |
|---|---|
| `# fcs-scan ignore-line` | The next line only |
| `# fcs-scan ignore-block` | The entire block or resource below |

Comment syntax: `#` for Terraform, YAML, Kubernetes, Dockerfile, and Ansible; `//` also works for Terraform; `;` for Ansible INI inventories.

> [!IMPORTANT]
> `ignore-line` must sit directly above the line the finding **anchors to** — usually the offending *attribute*, not the `resource` declaration. Placing `# fcs-scan ignore-line` above `resource "aws_s3_bucket_acl"` suppresses nothing, because the public-ACL rule reports on the `acl = "public-read"` line a few lines further down. Use `ignore-block` when you want the whole resource covered regardless of where the finding lands.

> [!NOTE]
> Suppressed findings are excluded from reports and leave **no audit trail**. Document the rationale separately if you use suppressions in production.

## Useful scan variations

```bash
# Filter by severity
fcs scan iac -p ./examples --severities critical,high

# Filter by platform
fcs scan iac -p ./examples --platforms Kubernetes,Dockerfile

# Filter by rule category
fcs scan iac -p ./examples --categories "Access Control","Encryption"

# See what secrets scanning contributes by turning it off
fcs scan iac -p ./examples/secrets --disable-secrets-scan

# Machine-readable reports
fcs scan iac -p ./examples --report-formats json,csv,sarif --output-path ./scan-reports

# Gate a pipeline on severity thresholds (nonzero exit)
fcs scan iac -p ./examples --fail-on "critical=1,high=5"

# Drive it all from the config file in this repo
fcs scan iac -c fcs_iac_config.json
```

Available categories: `Access Control`, `Availability`, `Backup`, `Best Practices`, `Build Process`, `Encryption`, `Insecure Configurations`, `Insecure Defaults`, `Networking and Firewall`, `Observability`, `Resource Management`, `Secret Management`, `Supply-Chain`, `Structure and Semantics`.

Available platforms: `Ansible`, `AzureResourceManager`, `CloudFormation`, `Crossplane`, `DockerCompose`, `Dockerfile`, `GoogleDeploymentManager`, `Kubernetes`, `OpenAPI`, `Pulumi`, `ServerlessFW`, `Terraform`.

## Rulesets: local vs combined

- **Local** — rules bundled with the CLI. Default when no credentials are configured. Results stay on your machine and never reach the Falcon console. Best for local development and for this repo.
- **Combined** — bundled rules plus custom rules and overrides from your CID. Used automatically once the CLI is configured with an API client ID and secret. Force local-only with `--disable-custom-rules` or `FCS_IAC_DISABLE_CUSTOM_RULES`.

To upload results to the Falcon console (intentionally *not* the default here, so you don't pollute it with demo findings):

```bash
fcs configure   # one-time: stores credentials in ~/.crowdstrike/fcs.json
fcs scan iac -p ./examples --upload-results --project-name fcs-demo
```

If the CLI can't reach the cloud for the remote ruleset, it falls back to local rules and logs that it couldn't retrieve remote rules.

## Repo layout

```
.
├── examples/
│   ├── ansible/
│   ├── azure-arm/
│   ├── azure-bicep/
│   ├── cloudformation/
│   ├── crossplane/
│   ├── docker-compose/
│   ├── dockerfile/
│   ├── google-deployment-manager/
│   ├── helm/fcs-demo-chart/
│   ├── kubernetes/
│   ├── openapi/
│   ├── pulumi/
│   ├── secrets/
│   ├── serverless-framework/
│   └── terraform/
├── scripts/
│   ├── scan-all.sh        # per-platform finding counts
│   └── scan-bicep.sh      # Bicep transpile-then-scan workaround
├── fcs_iac_config.json    # example scan config (fcs scan iac -c)
└── README.md
```

## Notes

- **Terraform module resolution** — the scanner resolves and scans referenced Terraform modules (up to 10 levels deep), which means it may reach out to public registries and S3 buckets. Nothing here references external modules, so scans stay offline. If you add modules, run `terraform init -upgrade` first so a stale local cache doesn't skew results.
- **`.gitignore` is respected** by default; pass `--exclude-gitignore` to scan ignored paths too.
- **`scan-reports/`** is gitignored, so generated reports won't be committed.
