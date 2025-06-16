# Provider configurations for accessing shared GKE clusters

# Kubernetes provider for non-production cluster
provider "kubernetes" {
  alias = "nonprod"
  
  host                   = "https://${data.terraform_remote_state.shared_gke.outputs.gke_clusters.non_production.endpoint}"
  cluster_ca_certificate = base64decode(data.google_container_cluster.nonprod.master_auth[0].cluster_ca_certificate)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "gke-gcloud-auth-plugin"
  }
}

# Kubernetes provider for production cluster  
provider "kubernetes" {
  alias = "prod"
  
  host                   = "https://${data.terraform_remote_state.shared_gke.outputs.gke_clusters.production.endpoint}"
  cluster_ca_certificate = base64decode(data.google_container_cluster.prod.master_auth[0].cluster_ca_certificate)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "gke-gcloud-auth-plugin"
  }
}

# Data sources to get cluster details
data "google_container_cluster" "nonprod" {
  name     = data.terraform_remote_state.shared_gke.outputs.gke_clusters.non_production.cluster_name
  location = data.terraform_remote_state.shared_gke.outputs.gke_clusters.non_production.location
  project  = data.terraform_remote_state.shared_gke.outputs.gke_clusters.non_production.project_id
}

data "google_container_cluster" "prod" {
  name     = data.terraform_remote_state.shared_gke.outputs.gke_clusters.production.cluster_name
  location = data.terraform_remote_state.shared_gke.outputs.gke_clusters.production.location
  project  = data.terraform_remote_state.shared_gke.outputs.gke_clusters.production.project_id
}