# Naming Migration Plan: Boundary-Stage-Tier

## Overview
Migrate from current environment-based naming to orthogonal boundary-stage-tier scheme.

## Axis Definitions

| Axis | Purpose | Values | Example |
|------|---------|--------|---------|
| **Boundary** | Security/compliance boundary | `prod`, `nonprod` | GCP project isolation |
| **Stage** | Instance users interact with | `prod`, `staging`, `preprod`, `qa`, `dev`, `preview-{id}` | What site humans visit |
| **Tier** | Resource sizing | `standard`, `perf`, `ci`, `preview` | Infrastructure size |
| **Mode** | Runtime configuration | `production`, `development`, `test` | App config (Rails/Elixir style) |

## Current → New Mapping

### GCP Projects (Keep as-is)
- `u2i-tenant-webapp` → `webapp-nonprod` (contains all non-production stages)
- `u2i-tenant-webapp-prod` → `webapp-prod` (contains production stages)

### Kubernetes Namespaces
Current: `webapp-team` (single namespace)
New pattern: `{boundary}-{stage}-{tier}`
- `nonprod-dev-standard` (default dev environment)
- `nonprod-qa-standard` (QA testing)
- `nonprod-staging-standard` (production-like testing)
- `nonprod-preview-42-preview` (PR preview)
- `prod-preprod-standard` (final validation)
- `prod-prod-standard` (live production)
- `prod-prod-perf` (performance testing in prod boundary)

### Cloud Deploy Configuration

#### Targets
Current:
- `non-prod-webapp-cluster` → Multiple targets per stage
- `prod-webapp-cluster` → Multiple targets per stage

New:
```
# In nonprod project
nonprod-dev-cluster
nonprod-qa-cluster
nonprod-staging-cluster
nonprod-preview-cluster  # Shared for all previews

# In prod project
prod-preprod-cluster
prod-prod-cluster
```

#### Profiles (Skaffold)
Current: `non-prod`, `prod`
New: Based on tier
- `tier-standard`
- `tier-perf`
- `tier-ci`
- `tier-preview`

### Resource Naming

Pattern: `webapp-{stage}-{resource-type}`

Examples:
- Static IPs: `webapp-dev-ip`, `webapp-staging-ip`, `webapp-prod-ip`
- Certificates: `webapp-cert-dev`, `webapp-cert-staging`, `webapp-cert-prod`
- Ingresses: `webapp-ingress-dev`, `webapp-ingress-staging`, `webapp-ingress-prod`

### Labels/Tags

Standard labels on all resources:
```yaml
labels:
  app: webapp
  team: webapp-team
  boundary: nonprod|prod
  stage: dev|qa|staging|preprod|prod|preview-{id}
  tier: standard|perf|ci|preview
  mode: production|development|test
```

## Migration Steps

### Phase 1: Prepare Infrastructure
1. Update terraform modules to support new naming
2. Add boundary/stage/tier variables
3. Create label standards

### Phase 2: Create New Resources
1. Deploy new namespaces with proper names
2. Set up RBAC and resource quotas per namespace
3. Configure network policies

### Phase 3: Update Applications
1. Modify deployment scripts to use new naming
2. Update Skaffold profiles for tiers
3. Update Cloud Deploy pipeline

### Phase 4: Migrate Existing Deployments
1. Deploy to new namespaces
2. Update DNS/ingress
3. Validate and switch traffic
4. Clean up old resources

### Phase 5: Update Documentation
1. Update READMEs
2. Create naming convention guide
3. Update CI/CD documentation

## Benefits
- Clear separation of concerns
- Predictable resource naming
- Easy filtering/querying by label
- Supports multiple stages in same project
- Enables tier-based resource allocation
- Simplifies PR preview deployments