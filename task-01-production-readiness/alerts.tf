# alerts.tf - fx-quote-service availability SLO and burn-rate alerts 
#****************************************************************************************
# Uses Datadog's slo alert burn_rate() query over a 30d SLO target (99.9% availability)
# SLO burn-rate alerts based on Datadog's documented burn-rate methodology:
# https://docs.datadoghq.com/es/service_level_objectives/burn_rate/
#****************************************************************************************
# Monitors a 30-day SLO with a 99.9% availability target | error budget = 0.1%.
# Both long and short windows must exceed the threshold:
# - The long window detects sustained degradation
# - The short window confirms the issue is ongoing.
#----------------------------------------------------------------------------------------
# Fast burn (long_window = "1h", short_window = "5m", threshold = 14.4):
# Projects 2% error-budget consumption over 1h.
# Detects severe incidents requiring rapid response.
# A sustained burn rate of 14.4x would exhaust the 30-day error budget in approximately 2 days.
#----------------------------------------------------------------------------------------
# Slow burn (long_window = "6h", short_window = "30m", threshold = 6):
# Projects 5% error-budget consumption over 6h.
# Detects persistent degradation, such as upstream errors or Redis performance issues.
# A sustained burn rate of 6x would exhaust the 30-day error budget in approximately 5 days
#--------------------------------------------------------------------------------

#Provider configuration
terraform {
  required_providers {
    datadog = {
      source  = "DataDog/datadog"
      version = "~> 4.0"
    }
  }
}

# ---------------------------------------------------------------------------
#  Variables
# ---------------------------------------------------------------------------

variable "service_name" {
  description = "Service name as tagged in Datadog."
  type        = string
  default     = "fx-quote-service"
}

variable "env" {
  description = "Environment tag."
  type        = string
  default     = "prod"
}

variable "runbook_url" {
  description = "Runbook for fx-quote-service incidents."
  type        = string
}

variable "dashboard_url" {
  description = "Service dashboard."
  type        = string
}

variable "page_handle" {
  description = "Paging integration handle for the on-call rotation (fast burn)."
  type        = string
  default     = "@pagerduty-fx-quote-service"
}

variable "ticket_handle" {
  description = "Non-paging channel for slow burn."
  type        = string
  default     = "@slack-fx-quote-service-alerts"
}


# ---------------------------------------------------------------------------
# SLO as code
# ---------------------------------------------------------------------------
resource "datadog_service_level_objective" "availability" {
  name        = "[${var.service_name}] Availability"
  type        = "metric"
  description = "99.9% of quote requests succeed (no 5xx) over a rolling 30 days."

  query {
    #all successful requests (no 5xx)
    numerator   = "sum:trace.http.request.hits{service:${var.service_name},env:${var.env}}.as_count() - sum:trace.http.request.errors{service:${var.service_name},env:${var.env}}.as_count()" 
    #all requests (including errors)
    denominator = "sum:trace.http.request.hits{service:${var.service_name},env:${var.env}}.as_count()"
  }

  thresholds {
    timeframe = "30d"
    target    = 99.9
    warning   = 99.95
  }

  tags = [
    "service:${var.service_name}",
    "tier:tier-1",
    "slo:availability",
    "managed-by:terraform"
  ]
}

# ---------------------------------------------------------------------------
# Fast burn: pages on-call
# ---------------------------------------------------------------------------
resource "datadog_monitor" "availability_fast_burn" {
  name    = "[${var.service_name}] Error budget fast burn (>14.4x)"
  type    = "slo alert"

  # Query for the fast burn alert using Datadog's burn_rate() function.
  query = "burn_rate(\"${datadog_service_level_objective.availability.id}\").over(\"30d\").long_window(\"1h\").short_window(\"5m\") > 14.4"

  message = <<-EOT
    {{#is_alert}}
     ${var.service_name} availability SLO is experiencing a fast error budget burn rate.
    Check error rates, upstream rate provider status, Redis health, and recent deploys.
    Runbook: ${var.runbook_url} 
    Dashboard: ${var.dashboard_url}
    ${var.page_handle}
    {{/is_alert}}
    {{#is_recovery}}
    Burn rate is back under the threshold. Review customer impact and open a post-incident review if needed.
    {{/is_recovery}}
  EOT


#Burn rate thresholds for the alert.
  monitor_thresholds {
    critical = 14.4 
    warning  = 10.0
  }

  priority = 1

  tags = [
    "service:${var.service_name}",
    "tier:tier-1",
    "slo:availability",
    "burn-rate:fast",
    "managed-by:terraform"
  ]
}

# ---------------------------------------------------------------------------
# Slow burn: ticket / Slack, no page
# ---------------------------------------------------------------------------
resource "datadog_monitor" "availability_slow_burn" {
  name = "[${var.service_name}] Error budget slow burn (>6x)"
  type = "slo alert"

  # Query for the slow burn alert using Datadog's burn_rate() function.
  query = "burn_rate(\"${datadog_service_level_objective.availability.id}\").over(\"30d\").long_window(\"6h\").short_window(\"30m\") > 6"

  message = <<-EOT
    {{#is_alert}}
    ${var.service_name} availability SLO is experiencing a sustained error budget burn rate.
    Review persistent provider errors, latency/timeout behavior, Redis degradation, a bad release and error budget consumption with the team.

    Runbook: ${var.runbook_url}
    Dashboard: ${var.dashboard_url}
    ${var.ticket_handle}
    {{/is_alert}}
    {{#is_recovery}}
    Slow burn has stopped. Record the cause in the ticket.
    {{/is_recovery}}
  EOT

  monitor_thresholds {
    critical = 6.0
    warning  = 4.0
  }

  priority = 2

  tags = [
    "service:${var.service_name}",
    "tier:tier-1",
    "slo:availability",
    "burn-rate:slow",
    "managed-by:terraform"
  ]
}

