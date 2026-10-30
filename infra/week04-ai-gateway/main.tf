# =============================================================================
# Week 4: the AI gateway
# -----------------------------------------------------------------------------
# Google's managed AI gateway is Apigee, and its AI policies (LLMTokenQuota,
# PromptTokenLimit, SanitizeUserPrompt) need an Intermediate environment, about
# USD 1,460 a month (October 2026). Too much for a lab. So this course runs the
# same open-source gateway as week 0, LiteLLM, on Cloud Run. The README
# compares the two so you can explain the choice in an interview.
#
#   - Artifact Registry for the gateway and app images
#   - Cloud SQL for PostgreSQL (smallest tier, PRIVATE IP only) for team keys
#   - Secret Manager: the gateway admin key and the database URL
#   - A gateway service account that may call models and Model Armor, nothing else
#   - Cloud Run service "ai-gateway":
#       ingress INTERNAL only (no internet callers),
#       Direct VPC egress for private ranges (to reach Cloud SQL),
#       Model Armor on every prompt and answer
# =============================================================================

data "terraform_remote_state" "w1" {
  backend = "local"
  config  = { path = "${path.module}/../week01-landing-zone/terraform.tfstate" }
}
data "terraform_remote_state" "w2" {
  backend = "local"
  config  = { path = "${path.module}/../week02-private-model/terraform.tfstate" }
}
data "terraform_remote_state" "w3" {
  backend = "local"
  config  = { path = "${path.module}/../week03-guardrails/terraform.tfstate" }
}

locals {
  net   = data.terraform_remote_state.w1.outputs
  model = data.terraform_remote_state.w2.outputs.model
  armor = data.terraform_remote_state.w3.outputs
  repo  = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.images.repository_id}"
}

variable "deploy_gateway" {
  description = "false on the first run (no image yet). make week4 builds the image and sets it to true."
  type        = bool
  default     = false
}

variable "gateway_image_tag" {
  type    = string
  default = "v1"
}

# -------------------------------------------------------- registry -----------
resource "google_artifact_registry_repository" "images" {
  repository_id = "${var.prefix}-images"
  location      = var.region
  format        = "DOCKER"
  description   = "AI gateway and bank app images"
}

# ------------------------------------------ Cloud SQL, private IP only -------
resource "google_compute_global_address" "psa" {
  name          = "${var.prefix}-google-services"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 20
  network       = local.net.network_id
}

resource "google_service_networking_connection" "psa" {
  network                 = local.net.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.psa.name]
}

resource "random_password" "db" {
  length  = 32
  special = false
}

resource "random_password" "master_key" {
  length  = 40
  special = false
}

resource "google_sql_database_instance" "keys" {
  name                = "${var.prefix}-gateway-keys"
  database_version    = "POSTGRES_16"
  region              = var.region
  deletion_protection = false # lab only
  depends_on          = [google_service_networking_connection.psa]

  settings {
    edition           = "ENTERPRISE"
    tier              = "db-f1-micro" # shared core, no SLA: fine for a lab
    availability_type = "ZONAL"
    disk_size         = 10
    ip_configuration {
      ipv4_enabled    = false
      private_network = local.net.network_id
    }
    backup_configuration {
      enabled = false # lab only
    }
  }
}

resource "google_sql_database" "litellm" {
  name     = "litellm"
  instance = google_sql_database_instance.keys.name
}

resource "google_sql_user" "litellm" {
  name     = "litellm"
  instance = google_sql_database_instance.keys.name
  password = random_password.db.result
}

# ----------------------------------------------------------- secrets ---------
resource "google_secret_manager_secret" "master_key" {
  secret_id = "${var.prefix}-gateway-master-key"
  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "master_key" {
  secret      = google_secret_manager_secret.master_key.id
  secret_data = "sk-${random_password.master_key.result}"
}

resource "google_secret_manager_secret" "db_url" {
  secret_id = "${var.prefix}-gateway-database-url"
  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "db_url" {
  secret      = google_secret_manager_secret.db_url.id
  secret_data = "postgresql://litellm:${random_password.db.result}@${google_sql_database_instance.keys.private_ip_address}:5432/litellm"
}

# ------------------------------------------------------- identity ------------
resource "google_service_account" "gateway" {
  account_id   = "${var.prefix}-ai-gateway"
  display_name = "AI gateway: may call models and Model Armor"
}

resource "google_project_iam_member" "gateway" {
  for_each = toset(["roles/aiplatform.user", "roles/modelarmor.user"])
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.gateway.email}"
}

resource "google_secret_manager_secret_iam_member" "gateway" {
  for_each  = { master = google_secret_manager_secret.master_key.id, db = google_secret_manager_secret.db_url.id }
  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.gateway.email}"
}

# ------------------------------------------------------- Cloud Run -----------
resource "google_cloud_run_v2_service" "gateway" {
  count               = var.deploy_gateway ? 1 : 0
  name                = "ai-gateway"
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_INTERNAL_ONLY"
  deletion_protection = false
  # Network ingress is internal only, and the gateway checks its own team keys,
  # so Cloud Run's IAM invoker check is turned off. Production adds it back.
  invoker_iam_disabled = true

  template {
    service_account = google_service_account.gateway.email
    scaling {
      min_instance_count = 0
      max_instance_count = 2
    }
    vpc_access {
      network_interfaces {
        network    = local.net.network_id
        subnetwork = local.net.serverless_subnet_id
      }
      egress = "PRIVATE_RANGES_ONLY"
    }
    containers {
      image = "${local.repo}/ai-gateway:${var.gateway_image_tag}"
      ports {
        container_port = 8080
      }
      resources {
        limits = { cpu = "1", memory = "2Gi" }
      }
      env {
        name  = "BANK_MODEL"
        value = "vertex_ai/${local.model}"
      }
      env {
        name  = "GCP_PROJECT"
        value = var.project_id
      }
      env {
        name  = "VERTEX_LOCATION"
        value = var.region
      }
      env {
        name  = "MODEL_ARMOR_TEMPLATE"
        value = local.armor.model_armor_template_id
      }
      env {
        name  = "MODEL_ARMOR_LOCATION"
        value = local.armor.model_armor_location
      }
      env {
        name  = "LITELLM_LOCAL_MODEL_COST_MAP"
        value = "True"
      }
      env {
        name = "LITELLM_MASTER_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.master_key.secret_id
            version = "latest"
          }
        }
      }
      env {
        name = "DATABASE_URL"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_url.secret_id
            version = "latest"
          }
        }
      }
      startup_probe {
        initial_delay_seconds = 10
        period_seconds        = 10
        failure_threshold     = 30 # first start runs database migrations
        http_get {
          path = "/health/liveliness"
        }
      }
    }
  }

  depends_on = [google_project_iam_member.gateway, google_secret_manager_secret_iam_member.gateway]
}

output "registry" { value = local.repo }
output "gateway_url" { value = var.deploy_gateway ? google_cloud_run_v2_service.gateway[0].uri : "" }
output "master_key_secret" { value = google_secret_manager_secret.master_key.secret_id }
output "sql_instance" { value = google_sql_database_instance.keys.name }
