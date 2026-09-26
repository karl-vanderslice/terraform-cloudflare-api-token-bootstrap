provider "cloudflare" {}

data "cloudflare_account_api_token_permission_groups_list" "all" {
  account_id = var.cloudflare_account_id
}

locals {
  # Cloudflare grants permissions per resource scope. Keep separate policies so
  # a zone or R2 bucket permission cannot inherit an account-wide resource.
  permission_scopes = {
    account = "com.cloudflare.api.account"
    zone    = "com.cloudflare.api.account.zone"
    bucket  = "com.cloudflare.edge.r2.bucket"
  }

  permission_resources = {
    account = jsonencode({
      "com.cloudflare.api.account.${var.cloudflare_account_id}" = "*"
    })
    zone = jsonencode({
      "com.cloudflare.api.account.${var.cloudflare_account_id}" = {
        "com.cloudflare.api.account.zone.*" = "*"
      }
    })
    bucket = jsonencode({
      "com.cloudflare.api.account.${var.cloudflare_account_id}" = {
        "com.cloudflare.edge.r2.bucket.*" = "*"
      }
    })
  }

  # Cloudflare names read permissions with a Read suffix. Its documented
  # Account Security Center Insights permission is also read-only.
  permission_group_ids = {
    for scope_name, scope_id in local.permission_scopes : scope_name => sort(distinct([
      for group in data.cloudflare_account_api_token_permission_groups_list.all.result : group.id
      if contains(group.scopes, scope_id) && (scope_name != "bucket" || var.token_mode == "read_only") && (
        var.token_mode == "admin" ||
        endswith(group.name, " Read") ||
        endswith(group.name, " Read-Only") ||
        group.name == "Account Security Center Insights"
      )
    ]))
  }

  # Cloudflare accepts at most 300 permission groups in one policy.
  policies = flatten([
    for scope_name, ids in local.permission_group_ids : [
      for chunk in chunklist(ids, 300) : {
        effect            = "allow"
        permission_groups = [for id in chunk : { id = id }]
        resources         = local.permission_resources[scope_name]
      }
    ]
  ])
}

moved {
  from = cloudflare_account_token.superuser
  to   = cloudflare_account_token.bootstrap
}

resource "cloudflare_account_token" "bootstrap" {
  account_id = var.cloudflare_account_id
  name       = var.token_name != null ? var.token_name : "cloudflare-${replace(var.token_mode, "_", "-")}"
  policies   = local.policies

  condition = length(var.allowed_cidrs) > 0 ? {
    request_ip = {
      in = var.allowed_cidrs
    }
  } : null

  lifecycle {
    precondition {
      condition     = length(local.permission_group_ids.account) > 0 && length(local.permission_group_ids.zone) > 0
      error_message = "Cloudflare returned no account or zone permission groups for the selected mode."
    }
  }
}
