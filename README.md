# WebApp Team Infrastructure

This repository contains the Terragrunt-based infrastructure deployment for the WebApp team across multiple environments.

## 🏗️ Repository Structure

```
webapp-team-infrastructure/
├── environments/           # Environment-specific configurations
│   ├── dev/               # Development environment
│   ├── staging/           # Staging environment  
│   ├── qa/                # QA environment
│   ├── pre-prod/          # Pre-production environment
│   └── prod/              # Production environment
├── terragrunt.hcl         # Root Terragrunt configuration
└── k8s-infra/             # Kubernetes manifests
```

## 🔧 Module Architecture

This repository uses a three-layer module architecture:

1. **Generic Modules** (`terraform-google-compliance-modules`): Reusable GCP modules
2. **U2I Modules** (`u2i-terraform-modules`): U2I-specific wrappers with compliance policies
3. **Environment Deployments** (this repo): Simple environment configurations

## 📁 Projects

- **Non-Production**: `u2i-tenant-webapp` (dev, staging, qa)
- **Production**: `u2i-tenant-webapp-prod` (prod, pre-prod)

## 🚀 Getting Started

### Deploy an Environment

```bash
cd environments/dev
terragrunt plan
terragrunt apply
```

### Deploy All Environments

```bash
terragrunt run-all apply
```

### Destroy an Environment

```bash
cd environments/dev
terragrunt destroy
```

## 🔒 GitOps Workflow

### Infrastructure Changes Process
1. **Pull Request** → Terraform plan generated and validated
2. **Slack Approval** → Infrastructure team approval required
3. **Terraform Apply** → Changes applied with full audit trail
4. **Verification** → Post-apply health checks

### Approval Requirements
- **Non-destructive changes**: Auto-approved after 2 minutes
- **Destructive changes**: Manual Slack approval required
- **Emergency changes**: Force apply with enhanced audit logging

## 📋 Environment Configuration

Each environment uses the U2I webapp-base module with environment-specific overrides:

```hcl
terraform {
  source = "../../../u2i-terraform-modules/modules/u2i-webapp-base"
}

inputs = {
  enable_cloud_deploy      = true
  enable_artifact_registry = true
  # Environment-specific overrides
}
```

## 💾 State Management

Terraform state is stored in GCS buckets with CMEK encryption:
- Non-Production: `u2i-tenant-webapp-tfstate`
- Production: `u2i-tenant-webapp-prod-tfstate`

## 🔐 Security & Compliance

All deployments enforce U2I security standards:
- ✅ CMEK encryption with 90-day rotation
- ✅ EU-only data residency (europe-west1)
- ✅ Compliance labels for ISO 27001, SOC 2, GDPR
- ✅ Private GKE nodes
- ✅ Binary authorization for production
- ✅ Vulnerability scanning

## 📝 Compliance Checklist

Before infrastructure changes:
- [ ] Changes follow least privilege principle
- [ ] EU data residency maintained (europe-west1)
- [ ] Proper resource labeling for compliance
- [ ] Security policies not weakened
- [ ] Audit logging maintained
- [ ] Change has business justification

## 🆘 Support

- **Infrastructure Team**: `#infrastructure-approvals` Slack channel
- **Security Issues**: `security-team@u2i.com`
- **Compliance Questions**: `compliance@u2i.com`
- **Platform Support**: `platform-team@u2i.com`

## 🔍 Monitoring & Audit

### Audit Logs
All infrastructure changes are logged to:
- **GCP Cloud Logging**: `webapp-team-infrastructure` log stream
- **GitHub Actions**: Complete workflow execution history
- **Slack**: Approval and notification history

### Compliance Reporting
Infrastructure changes are tracked for:
- ISO 27001 change management requirements
- SOC 2 Type II audit trails
- GDPR data protection compliance

## 🌟 Adding a New Environment

1. Create a new directory under `environments/`
2. Add `terragrunt.hcl` and `env.hcl`
3. Configure environment-specific inputs
4. Run `terragrunt init && terragrunt apply`

## 📦 Dependencies

- Terraform >= 1.6
- Terragrunt >= 0.54
- Google Cloud SDK
- GitHub repository access
- Slack workspace access