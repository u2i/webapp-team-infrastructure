# Production project terragrunt configuration
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git::https://github.com/u2i/u2i-terraform-modules.git//webapp-project?ref=f38e4590892e3cc2e45c531a0d2ec0aa690290c8"
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