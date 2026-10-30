# =============================================================================
# Week 2: a private path to Gemini, and proof that it's private
# -----------------------------------------------------------------------------
#   - A service account that may call models (roles/aiplatform.user), nothing else
#   - A small test VM with NO external IP, using that service account, reachable
#     only through IAP (no bastion, no public SSH). It shuts down every evening.
#   - Gemini is called on its REGIONAL endpoint in Montreal, never `global`,
#     reached through Private Google Access (no internet route exists)
#   - Data Access audit logs for the Agent Platform API turned on (off by default)
#
# Gemini is a Google API with a public endpoint. On Google Cloud, "private"
# means: workloads have no internet path, reach Google APIs over Google's network
# with Private Google Access, use a regional endpoint, and (with an Organization)
# sit inside a VPC Service Controls perimeter. Week 3 covers the perimeter.
# =============================================================================

data "terraform_remote_state" "w1" {
  backend = "local"
  config  = { path = "${path.module}/../week01-landing-zone/terraform.tfstate" }
}

locals {
  net = data.terraform_remote_state.w1.outputs
}

variable "model" {
  description = "Gemini model the lab is approved to use, called on the regional endpoint. See weeks/02-private-model/README.md."
  type        = string
  default     = "gemini-3.5-flash"
}

variable "zone" {
  type    = string
  default = "northamerica-northeast1-a"
}

resource "google_service_account" "jumpbox" {
  account_id   = "${var.prefix}-jumpbox"
  display_name = "Test VM: may call models, nothing else"
}

resource "google_project_iam_member" "jumpbox_ai" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.jumpbox.email}"
}

data "google_project" "lab" {
  project_id = var.project_id
}

# The instance schedule runs as the Compute Engine service agent, which needs
# permission to stop the VM.
resource "google_project_iam_member" "scheduler_can_stop" {
  project = var.project_id
  role    = "roles/compute.instanceAdmin.v1"
  member  = "serviceAccount:service-${data.google_project.lab.number}@compute-system.iam.gserviceaccount.com"
}

resource "google_compute_resource_policy" "evening_stop" {
  name   = "${var.prefix}-stop-at-19"
  region = var.region
  instance_schedule_policy {
    vm_stop_schedule {
      schedule = "0 19 * * *"
    }
    time_zone = "America/Toronto"
  }
}

resource "google_compute_instance" "jumpbox" {
  name         = "${var.prefix}-jumpbox"
  machine_type = "e2-small"
  zone         = var.zone
  tags         = ["jumpbox"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64" # Ubuntu ships python3 and curl; the VM has no internet to install anything
      size  = 10
    }
  }

  network_interface {
    subnetwork = local.net.subnet_id
    # No access_config block = no external IP.
  }

  service_account {
    email  = google_service_account.jumpbox.email
    scopes = ["cloud-platform"]
  }

  shielded_instance_config {
    enable_secure_boot = true
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  resource_policies = [google_compute_resource_policy.evening_stop.id]
  depends_on        = [google_project_iam_member.scheduler_can_stop]
}

# Data Access audit logs for the model API are OFF by default. Turn them on so
# every model call leaves a record of who called what.
resource "google_project_iam_audit_config" "aiplatform" {
  project = var.project_id
  service = "aiplatform.googleapis.com"
  audit_log_config {
    log_type = "DATA_READ"
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

output "model" { value = var.model }
output "jumpbox" { value = google_compute_instance.jumpbox.name }
output "zone" { value = var.zone }
output "jumpbox_sa" { value = google_service_account.jumpbox.email }
