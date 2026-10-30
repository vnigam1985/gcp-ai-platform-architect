# =============================================================================
# Week 6: detect and respond
# -----------------------------------------------------------------------------
#   - An email notification channel
#   - Log-based metrics + alerts on the gateway's own logs:
#       burst of 401 (guessed, stolen or revoked keys)
#       burst of 429 (limits hit: a runaway app or a cost attack)
#   - Log-based alert when someone changes or deletes the Model Armor template,
#     or changes the project's audit logging (attackers turn logging off first)
#   - Log-based alert when Model Armor blocks a prompt (from the gateway logs)
# =============================================================================

variable "email" {
  type = string
}

resource "google_monitoring_notification_channel" "email" {
  display_name = "AI platform on-call"
  type         = "email"
  labels = {
    email_address = var.email
  }
}

locals {
  gateway_filter = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"ai-gateway\""
  signals = {
    "gateway-401" = { match = "\"401 Unauthorized\"", threshold = 20, text = "Burst of 401 at the AI gateway: guessed, stolen or revoked keys" }
    "gateway-429" = { match = "\"429 Too Many Requests\"", threshold = 30, text = "Burst of 429 at the AI gateway: a runaway app or a cost attack (OWASP LLM Top 10: unbounded consumption)" }
  }
}

resource "google_logging_metric" "gateway" {
  for_each = local.signals
  name     = "${var.prefix}-${each.key}"
  filter   = "${local.gateway_filter} AND textPayload:${each.value.match}"
  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
  }
}

resource "google_monitoring_alert_policy" "gateway" {
  for_each     = local.signals
  display_name = each.value.text
  combiner     = "OR"
  conditions {
    display_name = each.key
    condition_threshold {
      filter          = "resource.type = \"cloud_run_revision\" AND metric.type = \"logging.googleapis.com/user/${google_logging_metric.gateway[each.key].name}\""
      comparison      = "COMPARISON_GT"
      threshold_value = each.value.threshold
      duration        = "0s"
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_SUM"
      }
    }
  }
  notification_channels = [google_monitoring_notification_channel.email.id]
}

locals {
  log_alerts = {
    "controls-changed" = {
      title = "AI controls changed: Model Armor template or audit logging"
      # Fully bracketed: in the Logging query language OR binds tighter than AND.
      filter = "(protoPayload.serviceName=\"modelarmor.googleapis.com\" AND (protoPayload.methodName:\"UpdateTemplate\" OR protoPayload.methodName:\"DeleteTemplate\")) OR (protoPayload.methodName=\"SetIamPolicy\" AND protoPayload.serviceData.policyDelta.auditConfigDeltas:*)"
    }
    "prompt-blocked" = {
      title = "Model Armor blocked a prompt at the AI gateway"
      # The exact log text depends on the LiteLLM version. Check it in week 6 and adjust.
      filter = "${local.gateway_filter} AND (textPayload:\"Model Armor\" OR textPayload:\"model_armor\")"
    }
  }
}

resource "google_monitoring_alert_policy" "logs" {
  for_each     = local.log_alerts
  display_name = each.value.title
  combiner     = "OR"
  conditions {
    display_name = each.key
    condition_matched_log {
      filter = each.value.filter
    }
  }
  alert_strategy {
    notification_rate_limit {
      period = "300s"
    }
  }
  notification_channels = [google_monitoring_notification_channel.email.id]
}

output "notification_channel" { value = google_monitoring_notification_channel.email.id }
