# DNS configuration for webapp team

locals {
  root_domain = trimsuffix(data.terraform_remote_state.organization.outputs.dns_zone_info.dns_name, ".")
}

# Create a DNS zone for webapp subdomain in this project
resource "google_dns_managed_zone" "webapp" {
  project     = google_project.tenant_app.project_id
  name        = "webapp-zone"
  dns_name    = "webapp.${local.root_domain}."
  description = "DNS zone for webapp team subdomain"

  labels = {
    compliance     = "iso27001-soc2-gdpr"
    data_residency = "eu"
    managed_by     = "terraform"
  }
}

# DNS record for the main webapp
resource "google_dns_record_set" "webapp" {
  project      = google_project.tenant_app.project_id
  managed_zone = google_dns_managed_zone.webapp.name
  name         = "webapp.${local.root_domain}."
  type         = "A"
  ttl          = 300
  
  # This should come from the actual LoadBalancer service
  rrdatas = ["34.14.43.4"] # TODO: Reference from kubernetes_service data source
}

# DNS records for each environment
resource "google_dns_record_set" "environment_records" {
  for_each = toset(["dev", "staging", "qa", "pre-prod", "prod"])
  
  project      = google_project.tenant_app.project_id
  managed_zone = google_dns_managed_zone.webapp.name
  name         = "${each.key}.webapp.${local.root_domain}."
  type         = "A"
  ttl          = 300
  
  # TODO: These should be dynamically set based on actual deployments
  rrdatas = each.key == "dev" ? ["34.14.43.4"] : ["35.241.5.173"] # Placeholder for non-dev
}

# CNAME for www subdomain
resource "google_dns_record_set" "www_webapp" {
  project      = google_project.tenant_app.project_id
  managed_zone = google_dns_managed_zone.webapp.name
  name         = "www.webapp.${local.root_domain}."
  type         = "CNAME"
  ttl          = 300
  
  rrdatas = ["webapp.${local.root_domain}."]
}

# Outputs for other modules to use
output "dns_records" {
  description = "DNS records managed by this project"
  value = {
    webapp = google_dns_record_set.webapp.name
    environments = {
      for env, record in google_dns_record_set.environment_records : 
      env => record.name
    }
  }
}

# Output NS records that need to be added to parent zone
output "dns_delegation" {
  description = "NS records to add to the parent DNS zone for delegation"
  value = {
    zone_name   = google_dns_managed_zone.webapp.dns_name
    nameservers = google_dns_managed_zone.webapp.name_servers
    instructions = "Add these NS records to the parent zone (${local.root_domain}) to delegate webapp.${local.root_domain} to this project"
  }
}