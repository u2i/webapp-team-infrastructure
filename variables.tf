# Variables for tenant example deployment

variable "billing_account" {
  description = "Billing account ID for tenant projects"
  type        = string
}

variable "primary_region" {
  description = "Primary region for resources (Belgium/EU deployment)"
  type        = string
  default     = "europe-west1"
}