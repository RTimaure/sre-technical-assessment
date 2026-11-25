# alerts.tf - fx-quote-service availability SLO and burn-rate alerts 
#********************************************************************************************
# Uses Datadog's slo alert burn_rate() query over a 30d SLO target (99.9% availability)
# SLO burn-rate alerts based on Datadog's documented burn-rate methodology:
# https://docs.datadoghq.com/es/service_level_objectives/burn_rate/
#*********************************************************************************************
# Monitors a 30-day SLO with a 99.9% availability target | error budget = 0.1%.
# Both long and short windows must exceed the threshold:
# - The long window detects sustained degradation
# - The short window confirms the issue is ongoing.
#---------------------------------------------------------------------------------------------
# Fast burn (long_window = "1h", short_window = "5m", threshold = 14.4):
# Projects 2% error-budget consumption over 1h.
# Detects severe incidents requiring rapid response.
# A sustained burn rate of 14.4x would exhaust the 30-day error budget in approximately 2 days.
#-----------------------------------------------------------------------------------------------
# Slow burn (long_window = "6h", short_window = "30m", threshold = 6):
# Projects 5% error-budget consumption over 6h.
# Detects persistent degradation, such as upstream errors or Redis performance issues.
# A sustained burn rate of 6x would exhaust the 30-day error budget in approximately 5 days
#------------------------------------------------------------------------------------------------
# Very slow burn (long_window = "3d", short_window = "6h", threshold = 1):
# Projects 10% error-budget consumption over 3d (1 x 72h / 720h).
# Detects silent, steady degradation that never crosses the 6x threshold
# -> ticket, review in working hours.
# A sustained burn rate of 1x exhausts the budget exactly at the end of the 30 days.
# ------------------------------------------------------------------------------------------------

#Provider configuration
terraform {
  required_version = ">= 1.3.0"

  required_providers {
    datadog = {
      source  = "DataDog/datadog"
      version = "~> 4.0"
    }
  }
}

# API/APP keys are read from the environment: DD_API_KEY and DD_APP_KEY.
# For non-US1 sites set datadog_api_url (e.g. "https://api.datadoghq.eu" for EU).
# When null, the provider falls back to DD_HOST or its default site.
provider "datadog" {
  api_url = var.datadog_api_url
}

# ---------------------------------------------------------------------------
#  Variables
# ---------------------------------------------------------------------------

variable "datadog_api_url" {
  description = "Datadog API URL for non-default sites (null = provider default / DD_HOST)."
  type        = string
  default     = null
}

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

variable "trace_metric_prefix" {
  description = "APM trace metric prefix. Depends on the tracer/framework span name (e.g. trace.http.request, trace.flask.request, trace.servlet.request). Verify in Metrics Explorer."
  type        = string
  default     = "trace.http.request"
}

variable "excluded_resources" {
  description = "resource_name values to exclude from the SLI (health checks, readiness probes, metrics endpoints...)."
  type        = list(string)
  default     = []
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

#---------------------------------------------------------------------------
# Locals: SLI query pieces
# ---------------------------------------------------------------------------
# Local variables used to construct the SLI queries for the SLO and burn-rate monitors.
locals {
  # e.g. "service:fx-quote-service,env:prod,!resource_name:get_/health"
  sli_scope = join(",", concat(
    ["service:${var.service_name}", "env:${var.env}"],
    [for r in var.excluded_resources : "!resource_name:${r}"]
  ))

  #SLI queries for the SLO and burn-rate monitors.
  sli_total  = "sum:${var.trace_metric_prefix}.hits{${local.sli_scope}}.as_count()"

  #sli errors counts all 5xx errors, including 502/503/504 upstream errors and 500 internal server errors.
  sli_errors = "sum:${var.trace_metric_prefix}.errors{${local.sli_scope}}.as_count()"
}

# ---------------------------------------------------------------------------
# SLO as code
# ---------------------------------------------------------------------------
resource "datadog_service_level_objective" "availability" {
  name        = "[${var.service_name}] Availability"
  type        = "metric"
  description = "99.9% of quote requests succeed (spans without error status) over a rolling 30 days. Excludes resources listed in excluded_resources."

  query {
    # good events = all requests - requests flagged as error
    numerator = "${local.sli_total} - ${local.sli_errors}"
    # total events (including errors)
    denominator = local.sli_total
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
  # burn_rate().over() must match the SLO timeframe (30d).
  query = "burn_rate(\"${datadog_service_level_objective.availability.id}\").over(\"30d\").long_window(\"1h\").short_window(\"5m\") > 14.4"

  message = <<-EOT
    {{#is_alert}}
    ${var.service_name} availability SLO is experiencing a FAST error budget burn rate (>14.4x).
    Check error rates, upstream rate provider status, Redis health, and recent deploys.
    Runbook: ${var.runbook_url}
    Dashboard: ${var.dashboard_url}
    ${var.page_handle}
    {{/is_alert}}

    # Alert is in warning state, but not yet critical. No page yet; watch closely.
    {{#is_warning}}
    ${var.service_name} error budget burn rate is elevated (>10x) and approaching the paging threshold. No page yet; watch closely.
    Runbook: ${var.runbook_url}
    Dashboard: ${var.dashboard_url}
    ${var.ticket_handle}
    {{/is_warning}}

    # Alert has recovered. No page, but review customer impact and open a post-incident review if needed.
    {{#is_recovery}}
    ${var.service_name}: burn rate is back under the threshold. Review customer impact and open a post-incident review if needed.
    ${var.page_handle}
    ${var.ticket_handle}
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
    ${var.service_name} availability SLO is experiencing a sustained error budget burn rate (>6x).
    Review persistent provider errors, latency/timeout behavior, Redis degradation, a bad release and error budget consumption with the team.
    Runbook: ${var.runbook_url}
    Dashboard: ${var.dashboard_url}
    ${var.ticket_handle}
    {{/is_alert}}

    # Alert is in warning state, but not yet critical. No page yet; watch closely.
    {{#is_warning}}
    ${var.service_name} error budget burn rate is elevated (>4x). Keep an eye on provider errors and Redis health.
    Dashboard: ${var.dashboard_url}
    ${var.ticket_handle}
    {{/is_warning}}

    # Alert has recovered. No page, but review customer impact and open a post-incident review if needed.
    {{#is_recovery}}
    ${var.service_name}: slow burn has stopped. Record the cause in the ticket.
    ${var.ticket_handle}
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

# ---------------------------------------------------------------------------
# Very slow burn: ticket only, review in working hours
# ---------------------------------------------------------------------------
resource "datadog_monitor" "availability_very_slow_burn" {
  name = "[${var.service_name}] Error budget very slow burn (>1x, 3d)"
  type = "slo alert"

  # Query for the very slow burn alert using Datadog's burn_rate() function.
  query = "burn_rate(\"${datadog_service_level_objective.availability.id}\").over(\"30d\").long_window(\"3d\").short_window(\"6h\") > 1"

  message = <<-EOT
    {{#is_alert}}
    ${var.service_name} has been consuming its error budget faster than sustainable for 3 days (>1x).
    At this pace the 30-day budget will be exhausted before the window ends. Plan reliability work or a release freeze.
    Runbook: ${var.runbook_url}
    Dashboard: ${var.dashboard_url}
    ${var.ticket_handle}
    {{/is_alert}}
    {{#is_recovery}}
    ${var.service_name}: sustained burn is back to a sustainable rate. Record the cause in the ticket.
    ${var.ticket_handle}
    {{/is_recovery}}
  EOT

  monitor_thresholds {
    critical = 1.0
  }

  priority = 3

  tags = [
    "service:${var.service_name}",
    "tier:tier-1",
    "slo:availability",
    "burn-rate:very-slow",
    "managed-by:terraform"
  ]
}