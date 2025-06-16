# WebApp Team Infrastructure

This repository contains the Terraform infrastructure configuration for the WebApp Team's tenant project, following ISO 27001, SOC 2 Type II, and GDPR compliance requirements.

## 🏗️ Infrastructure Overview

### Components Managed
- **Tenant Project**: `u2i-tenant-webapp` with full compliance labeling
- **Cloud Deploy Pipeline**: Multi-environment deployment with approval gates
- **Kubernetes Namespaces**: Team-specific namespaces on shared GKE clusters
- **IAM & RBAC**: Scoped permissions for team access
- **Artifact Registry**: Private container registry for team images
- **Storage**: Deployment artifacts and compliance logging

### Compliance Features
- **ISO 27001**: Change management and access controls
- **SOC 2 Type II**: Audit logging and approval workflows
- **GDPR**: EU data residency (europe-west1) and data protection

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

## 🚀 Getting Started

### Prerequisites
- Access to `u2i-tenant-webapp` GCP project
- Membership in infrastructure team Slack channel
- GitHub repository access with proper permissions

### Making Infrastructure Changes
1. Create feature branch: `git checkout -b infra/your-change`
2. Modify Terraform files
3. Commit and push: `git commit -am "Your change description"`
4. Create PR to main branch
5. Review Terraform plan in PR comments
6. Merge PR (triggers Slack approval workflow)
7. Approve via Slack to apply changes

### Directory Structure
```
webapp-team-infrastructure/
├── main.tf                    # Main Terraform configuration
├── variables.tf               # Input variables
├── terraform.tfvars          # Variable values
├── outputs.tf                # Output values
├── providers.tf              # Provider configuration
├── clouddeploy.yaml          # Cloud Deploy pipeline config
├── k8s-infra/                # Kubernetes infrastructure manifests
│   ├── namespace.yaml        # Team namespace configuration
│   ├── rbac.yaml            # Role-based access controls
│   ├── network-policy.yaml  # Network security policies
│   └── resource-quota.yaml  # Resource limits and quotas
└── .github/workflows/        # GitOps automation
    ├── terraform-plan.yml   # Plan and validation
    └── terraform-apply.yml  # Apply with Slack approval
```

## 🔧 Configuration

### Environment Variables
- `TF_VERSION`: Terraform version (1.6.6)
- `PROJECT_ID`: Target GCP project (u2i-tenant-webapp)

### Required Secrets
- `SLACK_BOT_TOKEN`: Slack integration for approvals
- Workload Identity Federation handles GCP authentication

### Slack Integration
- Channel: `#infrastructure-approvals`
- Approval buttons for infrastructure changes
- Automatic notifications on apply completion

## 📋 Compliance Checklist

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