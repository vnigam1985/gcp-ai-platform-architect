# =============================================================================
# Week 8: let GitHub Actions deploy, with no stored keys
# -----------------------------------------------------------------------------
#   - Workload Identity Federation pool + GitHub provider, restricted to YOUR
#     fork (Google requires an attribute condition for GitHub)
#   - A release service account GitHub can impersonate, with only:
#       push images, build with Cloud Build, deploy Cloud Run, run the gate job
#   - The release gate: a Cloud Run JOB inside the VPC that asks the app the
#     golden questions and fails if any answer breaks a rule
# =============================================================================

data "terraform_remote_state" "w1" {
  backend = "local"
  config  = { path = "${path.module}/../week01-landing-zone/terraform.tfstate" }
}
data "terraform_remote_state" "w4" {
  backend = "local"
  config  = { path = "${path.module}/../week04-ai-gateway/terraform.tfstate" }
}
data "terraform_remote_state" "w5" {
  backend = "local"
  config  = { path = "${path.module}/../week05-private-app/terraform.tfstate" }
}

locals {
  net = data.terraform_remote_state.w1.outputs
  gw  = data.terraform_remote_state.w4.outputs
  app = data.terraform_remote_state.w5.outputs
}

variable "github_repo" {
  description = "Your fork, as owner/name"
  type        = string
}

variable "deploy_gate" {
  description = "false until the gate image exists. make week8 handles the order."
  type        = bool
  default     = false
}

data "google_project" "lab" {
  project_id = var.project_id
}

# ------------------------------------------- Workload Identity Federation ----
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "${var.prefix}-github"
  display_name              = "GitHub Actions"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub OIDC"
  attribute_mapping = {
    "google.subject"        = "assertion.sub"
    "attribute.repository"  = "assertion.repository"
    "attribute.environment" = "assertion.environment"
  }
  # Only your fork, only its "lab" environment.
  attribute_condition = "assertion.repository == '${var.github_repo}' && assertion.environment == 'lab'"
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "release" {
  account_id   = "${var.prefix}-github-release"
  display_name = "GitHub release pipeline"
}

resource "google_service_account_iam_member" "github_can_impersonate" {
  service_account_id = google_service_account.release.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repo}"
}

resource "google_project_iam_member" "release" {
  for_each = toset([
    "roles/artifactregistry.writer",
    "roles/cloudbuild.builds.editor",
    "roles/run.developer",
    "roles/aiplatform.viewer", # read what's deployed for the inventory check
    "roles/serviceusage.serviceUsageConsumer",
    "roles/storage.admin",  # Cloud Build source uploads
    "roles/logging.viewer", # read the gate job output
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.release.email}"
}

# Deploying a Cloud Run revision "acts as" the runtime service accounts.
resource "google_project_iam_member" "release_act_as" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.release.email}"
}

# ------------------------------------------------------ the gate job ---------
resource "google_service_account" "gate" {
  account_id   = "${var.prefix}-release-gate"
  display_name = "Release gate job: no roles"
}

resource "google_cloud_run_v2_job" "gate" {
  count               = var.deploy_gate ? 1 : 0
  name                = "release-gate"
  location            = var.region
  deletion_protection = false

  template {
    task_count = 1
    template {
      service_account = google_service_account.gate.email
      max_retries     = 0
      timeout         = "900s"
      vpc_access {
        network_interfaces {
          network    = local.net.network_id
          subnetwork = local.net.serverless_subnet_id
        }
        egress = "ALL_TRAFFIC"
      }
      containers {
        image = "${local.gw.registry}/release-gate:latest"
        args  = ["--url", local.app.app_url]
      }
    }
  }
}

output "workload_identity_provider" { value = google_iam_workload_identity_pool_provider.github.name }
output "release_service_account" { value = google_service_account.release.email }
