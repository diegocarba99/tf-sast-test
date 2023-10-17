terraform {
  # Require Terraform version 1.0 (recommended)
  required_version = "~> 1.0"

  # Require the latest 2.x version of the New Relic provider
  required_providers {
    newrelic = {
      source  = "newrelic/newrelic"
    }
  }
}

provider "newrelic" {
  account_id = 12345   # Your New Relic account ID
  api_key = "NRAK-AAA" # Your New Relic user key
  region = "US"        # US or EU (defaults to US)
}

data "newrelic_entity" "example_app" {
  name = "Your App Name" # Must be an exact match to your application name in New Relic
  domain = "APM" # or BROWSER, INFRA, MOBILE, SYNTH, depending on your entity's domain
  type = "APPLICATION"
}

resource "newrelic_alert_policy" "golden_signal_policy" {
  name = "Golden Signals - ${data.newrelic_entity.example_app.name}"
}

# Response time
resource "newrelic_alert_condition" "response_time_web" {
  policy_id       = newrelic_alert_policy.golden_signal_policy.id
  name            = "High Response Time (Web) - ${data.newrelic_entity.example_app.name}"
  type            = "apm_app_metric"
  entities        = [data.newrelic_entity.example_app.application_id]
  metric          = "response_time_web"
  runbook_url     = "https://www.example.com"
  condition_scope = "application"

  term {
    duration      = 5
    operator      = "above"
    priority      = "critical"
    threshold     = "5"
    time_function = "all"
  }
}

# Low throughput
resource "newrelic_alert_condition" "throughput_web" {
  policy_id       = newrelic_alert_policy.golden_signal_policy.id
  name            = "Low Throughput (Web)"
  type            = "apm_app_metric"
  entities        = [data.newrelic_entity.example_app.application_id]
  metric          = "throughput_web"
  condition_scope = "application"

  # Define a critical alert threshold that will
  # trigger after 5 minutes below 5 requests per minute.
  term {
    priority      = "critical"
    duration      = 5
    operator      = "below"
    threshold     = "5"
    time_function = "all"
  }
}

# Error percentage
resource "newrelic_alert_condition" "error_percentage" {
  policy_id       = newrelic_alert_policy.golden_signal_policy.id
  name            = "High Error Percentage"
  type            = "apm_app_metric"
  entities        = [data.newrelic_entity.example_app.application_id]
  metric          = "error_percentage"
  runbook_url     = "https://www.example.com"
  condition_scope = "application"

  # Define a critical alert threshold that will trigger after 5 minutes above a 5% error rate.
  term {
    duration      = 5
    operator      = "above"
    threshold     = "5"
    time_function = "all"
  }
}

# High CPU usage
resource "newrelic_infra_alert_condition" "high_cpu" {
  policy_id   = newrelic_alert_policy.golden_signal_policy.id
  name        = "High CPU usage"
  type        = "infra_metric"
  event       = "SystemSample"
  select      = "cpuPercent"
  comparison  = "above"
  runbook_url = "https://www.example.com"
  where       = "(`applicationId` = '${data.newrelic_entity.example_app.application_id}')"

  # Define a critical alert threshold that will trigger after 5 minutes above 90% CPU utilization.
  critical {
    duration      = 5
    value         = 90
    time_function = "all"
  }
}

resource "newrelic_notification_destination" "team_email_destination" {
  name = "email-example"
  type = "EMAIL"

  property {
    key = "email"
    value = "team.member1@email.com,team.member2@email.com,team.member3@email.com"
  }
}

resource "newrelic_notification_channel" "team_email_channel" {
  name = "email-example"
  type = "EMAIL"
  destination_id = newrelic_notification_destination.team_email_destination.id
  product = "IINT"

  property {
    key = "subject"
    value = "New Subject"
  }
}

resource "newrelic_workflow" "team_workflow" {
  name = "workflow-example"
  enrichments_enabled = true
  destinations_enabled = true
  workflow_enabled = true
  muting_rules_handling = "NOTIFY_ALL_ISSUES"

  enrichments {
    nrql {
      name = "Log"
      configurations {
       query = "SELECT count(*) FROM Metric"
      }
    }
  }

  issues_filter {
    name = "filter-example"
    type = "FILTER"

    predicates {
      attribute = "accumulations.sources"
      operator = "EXACTLY_MATCHES"
      values = [ "newrelic" ]
    }
  }

  destination_configurations {
    channel_id = newrelic_notification_channel.team_email_channel.id
  }
}

resource "newrelic_alert_channel" "team_email" {
  name = "example"
  type = "email"

  config {
    recipients              = "yourawesometeam@example.com"
    include_json_attachment = "1"
  }
}

resource "newrelic_alert_policy_channel" "golden_signals" {
  policy_id   = newrelic_alert_policy.golden_signal_policy.id
  channel_ids = [newrelic_alert_channel.team_email.id]
}
