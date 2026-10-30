# Week 0: a budget alert on the lab project BEFORE you deploy anything else.
# A budget only alerts. It never stops spending. `make destroy` stops spending.
# Needs the Billing Account Costs Manager role (or Billing Account Administrator)
# on the billing account. Alerts go to billing admins and users by default.

variable "billing_account" {
  description = "Billing account ID, like 0X0X0X-0X0X0X-0X0X0X (gcloud billing accounts list)"
  type        = string
}

variable "monthly_limit" {
  description = "In your billing account's currency."
  type        = number
  default     = 100
}

data "google_project" "lab" {
  project_id = var.project_id
}

resource "google_billing_budget" "lab" {
  billing_account = var.billing_account
  display_name    = "${var.prefix}-ai-platform-lab"

  budget_filter {
    projects = ["projects/${data.google_project.lab.number}"]
  }

  amount {
    specified_amount {
      units = tostring(var.monthly_limit)
    }
  }

  threshold_rules {
    threshold_percent = 0.5
  }
  threshold_rules {
    threshold_percent = 0.9
  }
  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "FORECASTED_SPEND"
  }
}
