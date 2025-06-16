# Security Configuration Notes

## Current Limitation: Workload Identity Federation

### Issue
The organization-level Workload Identity Federation is currently configured to only allow the `u2i/gcp-org-compliance` repository:

```
member = "principalSet://iam.googleapis.com/${workload_identity_pool}/attribute.repository/u2i/gcp-org-compliance"
```

### Impact
- Tenant repositories cannot use the existing workload identity setup
- Infrastructure workflows fail with "invalid_target" authentication errors
- This prevents the GitOps workflow from functioning properly

### Required Fix (Production)
Update the organization configuration to support tenant repositories:

1. **Option A: Expand existing pool**
   ```hcl
   # Allow multiple repositories
   member = "principalSet://iam.googleapis.com/${workload_identity_pool}/attribute.repository_owner/u2i"
   ```

2. **Option B: Create tenant-specific service accounts**
   ```hcl
   # Separate service account per tenant with restricted permissions
   resource "google_service_account" "tenant_terraform" {
     account_id   = "terraform-tenant-${var.tenant_name}"
     display_name = "Terraform SA for ${var.tenant_name}"
   }
   ```

3. **Option C: Use PAM with just-in-time access**
   ```hcl
   # Zero standing privilege with PAM elevation for tenant changes
   ```

### Temporary Solution
For demonstration purposes, this repository uses service account keys, but this should be replaced with proper workload identity federation in production.

### Security Best Practices
- ✅ Zero standing privilege model
- ✅ Least privilege access
- ✅ Audit logging for all operations
- ❌ Service account keys (temporary only)
- 🔄 Workload Identity Federation (needs configuration)

## Next Steps
1. Update organization gitops.tf to support tenant repositories
2. Create tenant-specific service accounts with scoped permissions  
3. Implement PAM elevation for write operations
4. Remove service account keys from workflows