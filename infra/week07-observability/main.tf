# =============================================================================
# Week 7: observability and FinOps
# -----------------------------------------------------------------------------
#   - A Cloud Monitoring dashboard: Gemini input and output tokens, model calls
#     and latency (from the platform's own metrics), plus gateway 401/429
#   - An alert when output tokens in a day go over the allowance
#
# Gemini's token metrics are BETA (October 2026):
#   aiplatform.googleapis.com/publisher/online_serving/token_count
#   on resource aiplatform.googleapis.com/PublisherModel, label "type" = input/output
# Per-team spend comes from the gateway, which records it per team key.
# =============================================================================

data "terraform_remote_state" "w6" {
  backend = "local"
  config  = { path = "${path.module}/../week06-security/terraform.tfstate" }
}

variable "daily_output_token_allowance" {
  type    = number
  default = 200000
}

locals {
  tokens = "metric.type=\"aiplatform.googleapis.com/publisher/online_serving/token_count\" resource.type=\"aiplatform.googleapis.com/PublisherModel\""
  calls  = "metric.type=\"aiplatform.googleapis.com/publisher/online_serving/model_invocation_count\" resource.type=\"aiplatform.googleapis.com/PublisherModel\""
}

resource "google_monitoring_dashboard" "ai" {
  dashboard_json = jsonencode({
    displayName = "AI platform: Gemini usage and gateway health"
    gridLayout = {
      columns = 2
      widgets = [
        {
          title = "Tokens per hour, input vs output"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = local.tokens
                  aggregation = {
                    alignmentPeriod    = "3600s"
                    perSeriesAligner   = "ALIGN_SUM"
                    crossSeriesReducer = "REDUCE_SUM"
                    groupByFields      = ["metric.label.\"type\""]
                  }
                }
              }
              plotType = "STACKED_BAR"
            }]
          }
        },
        {
          title = "Model calls per 5 minutes, by model"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = local.calls
                  aggregation = {
                    alignmentPeriod    = "300s"
                    perSeriesAligner   = "ALIGN_SUM"
                    crossSeriesReducer = "REDUCE_SUM"
                    groupByFields      = ["resource.label.\"model_user_id\""]
                  }
                }
              }
              plotType = "LINE"
            }]
          }
        },
        {
          title = "Gateway: blocked (401) and throttled (429)"
          xyChart = {
            dataSets = [
              for m in ["gateway-401", "gateway-429"] : {
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"logging.googleapis.com/user/${var.prefix}-${m}\" resource.type=\"cloud_run_revision\""
                    aggregation = {
                      alignmentPeriod    = "300s"
                      perSeriesAligner   = "ALIGN_SUM"
                      crossSeriesReducer = "REDUCE_SUM"
                    }
                  }
                }
                plotType = "LINE"
              }
            ]
          }
        },
        {
          title = "How to read this"
          text = {
            content = "Tokens are what you pay for. Throttles (429) mean a team hit its limit. 401 means blocked callers. Per-team spend: the gateway's /key/list (see the week 7 README). Token metrics are BETA; if a chart is empty, check the metric in Metrics Explorer."
            format  = "MARKDOWN"
          }
        },
      ]
    }
  })
}

resource "google_monitoring_alert_policy" "daily_tokens" {
  display_name = "AI FinOps: output tokens over the daily allowance"
  combiner     = "OR"
  conditions {
    display_name = "output tokens per day"
    condition_threshold {
      filter          = "${local.tokens} metric.label.\"type\"=\"output\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.daily_output_token_allowance
      duration        = "0s"
      aggregations {
        alignment_period     = "86400s"
        per_series_aligner   = "ALIGN_SUM"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }
  notification_channels = [data.terraform_remote_state.w6.outputs.notification_channel]
}
