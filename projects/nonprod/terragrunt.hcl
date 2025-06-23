# Nonprod project terragrunt configuration
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git::https://github.com/u2i/u2i-terraform-modules.git//webapp-project?ref=v1.42.0"
}

inputs = {
  project_id       = "u2i-tenant-webapp"
  environment      = "nonprod"
  root_domain      = "u2i.dev"
  billing_account  = "017E25-21F01C-DF5C27"
  primary_region   = "europe-west1"
  github_org       = "u2i"
  github_repo      = "webapp-team-infrastructure"
  gke_project_id   = "u2i-tenant-webapp"
  resource_version = "v1"
}