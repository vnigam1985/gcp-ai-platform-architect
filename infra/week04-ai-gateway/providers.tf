# Same in every week. Each week is its own Terraform root with local state;
# later weeks read earlier weeks' outputs from ../weekNN/terraform.tfstate.
terraform {
  required_version = ">= 1.9"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "google" {
  project               = var.project_id
  region                = var.region
  billing_project       = var.project_id
  user_project_override = true
  default_labels = {
    workload    = "ai-platform-lab"
    cost-center = "learning"
    managed-by  = "terraform"
  }
}

variable "project_id" {
  description = "Your lab project ID. Use a NEW project just for this course."
  type        = string
}

variable "region" {
  description = "Montreal. Change only if you understand the data residency lesson in weeks 2 and 3."
  type        = string
  default     = "northamerica-northeast1"
}

variable "prefix" {
  description = "Short name used in every resource name."
  type        = string
  default     = "aiplat"
}
