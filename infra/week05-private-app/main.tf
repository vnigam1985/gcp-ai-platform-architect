# =============================================================================
# Week 5: run the bank assistant privately on Cloud Run
# -----------------------------------------------------------------------------
#   - The Maple Leaf Bank app on Cloud Run, ingress INTERNAL only
#   - Direct VPC egress for ALL traffic, so its calls to the gateway come from
#     the VPC and pass the gateway's internal-only ingress
#   - Its own service account with NO roles: it can't call Gemini directly
#   - Its gateway team key in Secret Manager (make week5 creates it)
# =============================================================================

data "terraform_remote_state" "w1" {
  backend = "local"
  config  = { path = "${path.module}/../week01-landing-zone/terraform.tfstate" }
}
data "terraform_remote_state" "w4" {
  backend = "local"
  config  = { path = "${path.module}/../week04-ai-gateway/terraform.tfstate" }
}

locals {
  net = data.terraform_remote_state.w1.outputs
  gw  = data.terraform_remote_state.w4.outputs
}

variable "deploy_app" {
  description = "false until the image and team key exist. make week5 handles the order."
  type        = bool
  default     = false
}

variable "app_image_tag" {
  type    = string
  default = "v1"
}

resource "google_service_account" "app" {
  account_id   = "${var.prefix}-bank-app"
  display_name = "Bank app: no Google Cloud roles on purpose"
}

resource "google_secret_manager_secret" "team_key" {
  secret_id = "${var.prefix}-bank-app-gateway-key"
  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}

resource "google_secret_manager_secret_iam_member" "app" {
  secret_id = google_secret_manager_secret.team_key.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.app.email}"
}

resource "google_cloud_run_v2_service" "app" {
  count                = var.deploy_app ? 1 : 0
  name                 = "bank-assistant"
  location             = var.region
  ingress              = "INGRESS_TRAFFIC_INTERNAL_ONLY"
  deletion_protection  = false
  invoker_iam_disabled = true # lab only: internal ingress is the only door

  template {
    service_account = google_service_account.app.email
    scaling {
      min_instance_count = 0
      max_instance_count = 2
    }
    vpc_access {
      network_interfaces {
        network    = local.net.network_id
        subnetwork = local.net.serverless_subnet_id
      }
      egress = "ALL_TRAFFIC"
    }
    containers {
      image = "${local.gw.registry}/maple-bank-assistant:${var.app_image_tag}"
      ports {
        container_port = 8000
      }
      resources {
        limits = { cpu = "1", memory = "512Mi" }
      }
      env {
        name  = "LLM_MODE"
        value = "llm"
      }
      env {
        name  = "OPENAI_BASE_URL"
        value = "${local.gw.gateway_url}/v1"
      }
      env {
        name  = "MODEL"
        value = "bank-chat"
      }
      env {
        name = "OPENAI_API_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.team_key.secret_id
            version = "latest"
          }
        }
      }
    }
  }

  depends_on = [google_secret_manager_secret_iam_member.app]
}

output "app_url" { value = var.deploy_app ? google_cloud_run_v2_service.app[0].uri : "" }
output "team_key_secret" { value = google_secret_manager_secret.team_key.secret_id }
