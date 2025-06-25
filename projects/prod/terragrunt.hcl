# Production project terragrunt configuration
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git::https://github.com/u2i/u2i-terraform-modules.git//modules/webapp-complete?ref=v2.0.0"
}

inputs = {
  project_id      = "u2i-tenant-webapp-prod"
  environment     = "prod"
  root_domain     = "u2i.com"
  billing_account = "017E25-21F01C-DF5C27"
  primary_region  = "europe-west1"
  github_org      = "u2i"
  github_repo     = "webapp-team-infrastructure"
}