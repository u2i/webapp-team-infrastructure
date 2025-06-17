# Example Tenant Project with Cloud Deploy Pipeline
# This demonstrates how a tenant deploys to shared GKE clusters
# Testing complete WIF setup with project permissions

terraform {
  required_version = ">= 1.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20"
    }
  }

  backend "gcs" {
    bucket = "u2i-tfstate"
    prefix = "tenant-webapp-team"
  }
}

provider "google" {
  user_project_override = true
  billing_project       = "u2i-tenant-webapp"
  project               = "u2i-tenant-webapp"
}

# Get organization and GKE outputs
data "terraform_remote_state" "organization" {
  backend = "gcs"
  config = {
    bucket = "u2i-tfstate"
    prefix = "organization"
  }
}

data "terraform_remote_state" "shared_gke" {
  backend = "gcs"
  config = {
    bucket = "u2i-tfstate"
    prefix = "shared-gke"
  }
}

# Example tenant project - this would be a customer/team project
resource "google_project" "tenant_app" {
  name            = "u2i-tenant-webapp"
  project_id      = "u2i-tenant-webapp"
  billing_account = var.billing_account
  folder_id       = data.terraform_remote_state.organization.outputs.folder_structure.compliant

  labels = {
    environment    = "multi-environment"
    purpose        = "tenant-application"
    compliance     = "iso27001-soc2-gdpr"
    data_residency = "eu"
    region         = "belgium"
    gdpr_compliant = "true"
    tenant         = "webapp-team"
  }
}

# Enable required APIs for the tenant project
resource "google_project_service" "tenant_apis" {
  for_each = toset([
    "clouddeploy.googleapis.com",
    "cloudbuild.googleapis.com",
    "container.googleapis.com",
    "artifactregistry.googleapis.com",
    "storage.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com"
  ])

  project = google_project.tenant_app.project_id
  service = each.key

  disable_on_destroy = false
}

# Artifact Registry for container images
resource "google_artifact_registry_repository" "webapp_images" {
  project       = google_project.tenant_app.project_id
  location      = var.primary_region
  repository_id = "webapp-images"
  description   = "Container images for webapp tenant"
  format        = "DOCKER"

  labels = {
    environment    = "multi-environment"
    compliance     = "iso27001-soc2-gdpr"
    data_residency = "eu"
    gdpr_compliant = "true"
  }

  depends_on = [google_project_service.tenant_apis]
}

# Cloud Deploy service account
resource "google_service_account" "cloud_deploy_sa" {
  project      = google_project.tenant_app.project_id
  account_id   = "cloud-deploy-sa"
  display_name = "Cloud Deploy Service Account"
  description  = "Service account for Cloud Deploy pipeline"
}

# Cloud Deploy delivery pipeline
resource "google_clouddeploy_delivery_pipeline" "webapp_pipeline" {
  project     = google_project.tenant_app.project_id
  location    = var.primary_region
  name        = "webapp-delivery-pipeline"
  description = "Delivery pipeline for webapp from dev to staging to production"

  serial_pipeline {
    stages {
      target_id = google_clouddeploy_target.nonprod_target.name
      profiles  = ["nonprod"]
    }

    stages {
      target_id = google_clouddeploy_target.prod_target.name
      profiles  = ["prod"]

      # Standard deployment strategy
    }
  }

  labels = {
    environment    = "multi-environment"
    compliance     = "iso27001-soc2-gdpr"
    data_residency = "eu"
    gdpr_compliant = "true"
  }

  depends_on = [google_project_service.tenant_apis]
}

# Non-production GKE target
resource "google_clouddeploy_target" "nonprod_target" {
  project     = google_project.tenant_app.project_id
  location    = var.primary_region
  name        = "nonprod-gke"
  description = "Non-production GKE cluster target"

  gke {
    cluster = "projects/${data.terraform_remote_state.shared_gke.outputs.projects_created["u2i-gke-nonprod"].project_id}/locations/${var.primary_region}/clusters/nonprod-autopilot"
  }

  execution_configs {
    usages           = ["RENDER", "DEPLOY"]
    service_account  = google_service_account.cloud_deploy_sa.email
    artifact_storage = "gs://${google_storage_bucket.deployment_artifacts.name}"
  }

  labels = {
    environment    = "non-production"
    compliance     = "iso27001-soc2-gdpr"
    data_residency = "eu"
    gdpr_compliant = "true"
  }

  depends_on = [google_project_service.tenant_apis]
}

# Production GKE target
resource "google_clouddeploy_target" "prod_target" {
  project     = google_project.tenant_app.project_id
  location    = var.primary_region
  name        = "prod-gke"
  description = "Production GKE cluster target"

  gke {
    cluster = "projects/${data.terraform_remote_state.shared_gke.outputs.projects_created["u2i-gke-prod"].project_id}/locations/${var.primary_region}/clusters/prod-autopilot"
  }

  execution_configs {
    usages           = ["RENDER", "DEPLOY"]
    service_account  = google_service_account.cloud_deploy_sa.email
    artifact_storage = "gs://${google_storage_bucket.deployment_artifacts.name}"
  }

  # Require manual approval for production
  require_approval = true

  labels = {
    environment    = "production"
    compliance     = "iso27001-soc2-gdpr"
    data_residency = "eu"
    gdpr_compliant = "true"
  }

  depends_on = [google_project_service.tenant_apis]
}

# Storage bucket for deployment artifacts
resource "google_storage_bucket" "deployment_artifacts" {
  project  = google_project.tenant_app.project_id
  name     = "${google_project.tenant_app.project_id}-deploy-artifacts"
  location = var.primary_region

  # Compliance settings
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
  }

  labels = {
    environment    = "multi-environment"
    compliance     = "iso27001-soc2-gdpr"
    data_residency = "eu"
    gdpr_compliant = "true"
  }
}

# IAM permissions for Cloud Deploy service account on shared GKE clusters
resource "google_project_iam_member" "cloud_deploy_nonprod_access" {
  project = data.terraform_remote_state.shared_gke.outputs.projects_created["u2i-gke-nonprod"].project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.cloud_deploy_sa.email}"
}

resource "google_project_iam_member" "cloud_deploy_prod_access" {
  project = data.terraform_remote_state.shared_gke.outputs.projects_created["u2i-gke-prod"].project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.cloud_deploy_sa.email}"
}

# IAM permissions for Cloud Deploy service account on tenant project
resource "google_project_iam_member" "cloud_deploy_tenant_permissions" {
  for_each = toset([
    "roles/clouddeploy.jobRunner",
    "roles/container.clusterViewer",
    "roles/artifactregistry.reader",
    "roles/storage.objectAdmin"
  ])

  project = google_project.tenant_app.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.cloud_deploy_sa.email}"
}

# Create tenant namespace in shared clusters
resource "kubernetes_namespace" "webapp_nonprod" {
  provider = kubernetes.nonprod

  metadata {
    name = "webapp-team"

    labels = {
      "tenant"                             = "webapp-team"
      "environment"                        = "non-production"
      "compliance"                         = "iso27001-soc2-gdpr"
      "data-residency"                     = "eu"
      "gdpr-compliant"                     = "true"
      "pod-security.kubernetes.io/enforce" = "restricted"
      "pod-security.kubernetes.io/audit"   = "restricted"
      "pod-security.kubernetes.io/warn"    = "restricted"
    }

    annotations = {
      "tenant-project" = google_project.tenant_app.project_id
      "created-by"     = "terraform"
    }
  }
}

resource "kubernetes_namespace" "webapp_prod" {
  provider = kubernetes.prod

  metadata {
    name = "webapp-team"

    labels = {
      "tenant"                             = "webapp-team"
      "environment"                        = "production"
      "compliance"                         = "iso27001-soc2-gdpr"
      "data-residency"                     = "eu"
      "gdpr-compliant"                     = "true"
      "pod-security.kubernetes.io/enforce" = "restricted"
      "pod-security.kubernetes.io/audit"   = "restricted"
      "pod-security.kubernetes.io/warn"    = "restricted"
    }

    annotations = {
      "tenant-project" = google_project.tenant_app.project_id
      "created-by"     = "terraform"
    }
  }
}

# Resource quota for tenant namespace
resource "kubernetes_resource_quota" "webapp_nonprod_quota" {
  provider = kubernetes.nonprod

  metadata {
    name      = "webapp-team-quota"
    namespace = kubernetes_namespace.webapp_nonprod.metadata[0].name
  }

  spec {
    hard = {
      "requests.cpu"    = "2"
      "requests.memory" = "4Gi"
      "limits.cpu"      = "4"
      "limits.memory"   = "8Gi"
      "pods"            = "10"
      "services"        = "5"
    }
  }
}

resource "kubernetes_resource_quota" "webapp_prod_quota" {
  provider = kubernetes.prod

  metadata {
    name      = "webapp-team-quota"
    namespace = kubernetes_namespace.webapp_prod.metadata[0].name
  }

  spec {
    hard = {
      "requests.cpu"    = "4"
      "requests.memory" = "8Gi"
      "limits.cpu"      = "8"
      "limits.memory"   = "16Gi"
      "pods"            = "20"
      "services"        = "10"
    }
  }
}

# Network policies for tenant isolation
resource "kubernetes_network_policy" "webapp_isolation_nonprod" {
  provider = kubernetes.nonprod

  metadata {
    name      = "webapp-team-isolation"
    namespace = kubernetes_namespace.webapp_nonprod.metadata[0].name
  }

  spec {
    pod_selector {}

    policy_types = ["Ingress", "Egress"]

    # Allow ingress from same namespace and ingress controllers
    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = kubernetes_namespace.webapp_nonprod.metadata[0].name
          }
        }
      }
    }

    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = "gke-system"
          }
        }
      }
    }

    # Allow egress to DNS, same namespace, and external (for business logic)
    egress {
      to {
        namespace_selector {
          match_labels = {
            name = "kube-system"
          }
        }
      }
      ports {
        port     = "53"
        protocol = "UDP"
      }
    }

    egress {
      to {
        namespace_selector {
          match_labels = {
            name = kubernetes_namespace.webapp_nonprod.metadata[0].name
          }
        }
      }
    }

    # Allow egress to external services
    egress {
      to {}
      ports {
        port     = "443"
        protocol = "TCP"
      }
    }

    egress {
      to {}
      ports {
        port     = "80"
        protocol = "TCP"
      }
    }
  }
}

resource "kubernetes_network_policy" "webapp_isolation_prod" {
  provider = kubernetes.prod

  metadata {
    name      = "webapp-team-isolation"
    namespace = kubernetes_namespace.webapp_prod.metadata[0].name
  }

  spec {
    pod_selector {}

    policy_types = ["Ingress", "Egress"]

    # Allow ingress from same namespace and ingress controllers
    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = kubernetes_namespace.webapp_prod.metadata[0].name
          }
        }
      }
    }

    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = "gke-system"
          }
        }
      }
    }

    # Allow egress to DNS, same namespace, and external (for business logic)
    egress {
      to {
        namespace_selector {
          match_labels = {
            name = "kube-system"
          }
        }
      }
      ports {
        port     = "53"
        protocol = "UDP"
      }
    }

    egress {
      to {
        namespace_selector {
          match_labels = {
            name = kubernetes_namespace.webapp_prod.metadata[0].name
          }
        }
      }
    }

    # Allow egress to external services
    egress {
      to {}
      ports {
        port     = "443"
        protocol = "TCP"
      }
    }

    egress {
      to {}
      ports {
        port     = "80"
        protocol = "TCP"
      }
    }
  }
}

# Tenant Compliance Module - All features disabled by default
# Note: Module temporarily commented out due to private repo access in GitHub Actions
# To enable, uncomment the module block below and configure repository access
#
# module "webapp_compliance" {
#   source = "github.com/u2i/terraform-google-compliance-modules//modules/tenant-compliance?ref=v1.6.1"
#
#   tenant_project_id = google_project.tenant_app.project_id
#   tenant_name       = "webapp-team"
#   tenant_namespace  = "webapp-team"
#   region            = var.primary_region
#
#   # GKE configuration
#   gke_nonprod_project = data.terraform_remote_state.shared_gke.outputs.projects_created["u2i-gke-nonprod"].project_id
#   gke_prod_project    = data.terraform_remote_state.shared_gke.outputs.projects_created["u2i-gke-prod"].project_id
#
#   # All compliance features disabled by default
#   enable_scoped_iam            = false
#   enable_binary_authorization  = false
#   enable_production_approval   = false
#   enable_rbac_separation       = false
#   enable_compliance_monitoring = false
#   enable_network_policies      = false
#   enable_admission_controllers = false
#   enable_secret_management     = false
# }
