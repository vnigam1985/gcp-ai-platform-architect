# =============================================================================
# Week 3: guardrails as code
# -----------------------------------------------------------------------------
# Always (works in any project):
#   1. Model Armor template for the bank: prompt injection and jailbreak,
#      harmful content and sensitive data. The gateway (week 4) calls it on
#      every prompt and every answer. Toronto, because Model Armor isn't in Montreal.
#
# Only if your project is in a Google Cloud Organization (var.enable_org_policies):
#   3. Org policy vertexai.allowedModels: only the approved model can be called
#   4. Org policy gcp.resourceLocations: resources only in Canada
#
# Personal Gmail projects have no Organization, so org policies and VPC Service
# Controls aren't available. The README explains what they'd add and how to get
# a free Organization if you want to practise them.
# =============================================================================

data "terraform_remote_state" "w2" {
  backend = "local"
  config  = { path = "${path.module}/../week02-private-model/terraform.tfstate" }
}

locals {
  model = data.terraform_remote_state.w2.outputs.model
}

variable "enable_org_policies" {
  description = "Set true only if the project belongs to a Google Cloud Organization and you have the Organization Policy Administrator role."
  type        = bool
  default     = false
}

# ---------------------------------------------------- 1. Model Armor ---------
variable "model_armor_location" {
  description = "Model Armor isn't offered in Montreal (October 2026). Toronto is the closest Canadian location; it has no malicious-URL filter."
  type        = string
  default     = "northamerica-northeast2"
}

resource "google_model_armor_template" "bank" {
  location    = var.model_armor_location
  template_id = "${var.prefix}-bank-assistant"

  filter_config {
    pi_and_jailbreak_filter_settings {
      filter_enforcement = "ENABLED"
      confidence_level   = "MEDIUM_AND_ABOVE"
    }
    sdp_settings {
      basic_config {
        filter_enforcement = "ENABLED" # credit card numbers and other common sensitive data
      }
    }
    rai_settings {
      rai_filters {
        filter_type      = "HATE_SPEECH"
        confidence_level = "MEDIUM_AND_ABOVE"
      }
      rai_filters {
        filter_type      = "HARASSMENT"
        confidence_level = "MEDIUM_AND_ABOVE"
      }
      rai_filters {
        filter_type      = "DANGEROUS"
        confidence_level = "MEDIUM_AND_ABOVE"
      }
      rai_filters {
        filter_type      = "SEXUALLY_EXPLICIT"
        confidence_level = "MEDIUM_AND_ABOVE"
      }
    }
  }

  template_metadata {
    log_sanitize_operations = true
    log_template_operations = true
  }
}

# ------------------------------------- 3 + 4. org policies (optional) --------
resource "google_org_policy_policy" "allowed_models" {
  count  = var.enable_org_policies ? 1 : 0
  name   = "projects/${var.project_id}/policies/vertexai.allowedModels"
  parent = "projects/${var.project_id}"
  spec {
    rules {
      values {
        allowed_values = ["is:publishers/google/models/${local.model}:predict"]
      }
    }
  }
}

resource "google_org_policy_policy" "resource_locations" {
  count  = var.enable_org_policies ? 1 : 0
  name   = "projects/${var.project_id}/policies/gcp.resourceLocations"
  parent = "projects/${var.project_id}"
  spec {
    rules {
      values {
        allowed_values = ["in:northamerica-northeast1-locations", "in:northamerica-northeast2-locations"]
      }
    }
  }
}

output "model_armor_template" { value = google_model_armor_template.bank.id }
output "model_armor_template_id" { value = google_model_armor_template.bank.template_id }
output "model_armor_location" { value = var.model_armor_location }
