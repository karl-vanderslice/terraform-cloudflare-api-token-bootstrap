provider "cloudflare" {}

data "cloudflare_api_token_permission_groups_list" "all" {
  count     = var.token_mode == "read_only" ? 1 : 0
  max_items = 10000
}

data "cloudflare_user" "current" {
  count = var.token_mode == "read_only" && var.cloudflare_user_id == null ? 1 : 0
}

data "cloudflare_account_api_token_permission_groups_list" "all" {
  count      = var.token_mode == "admin" ? 1 : 0
  account_id = var.cloudflare_account_id
}

locals {
  # User tokens follow Cloudflare's Read All Resources template: every
  # account and zone available to the user, plus the user's own resources.
  read_scopes = {
    account = "com.cloudflare.api.account"
    zone    = "com.cloudflare.api.account.zone"
    user    = "com.cloudflare.api.user"
  }

  read_user_id = var.token_mode == "admin" ? "" : (
    var.cloudflare_user_id != null ? var.cloudflare_user_id : data.cloudflare_user.current[0].id
  )

  read_resources = {
    account = jsonencode({ "com.cloudflare.api.account.*" = "*" })
    zone    = jsonencode({ "com.cloudflare.api.account.zone.*" = "*" })
    user = jsonencode({
      "com.cloudflare.api.user.${local.read_user_id}" = "*"
    })
  }

  # Read groups are identified by Cloudflare's names. The Insights group is
  # documented as read-only despite lacking the usual Read suffix.
  read_group_ids = var.token_mode == "read_only" ? {
    for scope_name, scope_id in local.read_scopes : scope_name => sort(distinct([
      for group in data.cloudflare_api_token_permission_groups_list.all[0].result : group.id
      if contains(group.scopes, scope_id) && (
        endswith(group.name, " Read") ||
        endswith(group.name, " Read-Only") ||
        group.name == "Account Security Center Insights"
      )
    ]))
  } : {}

  read_policies = flatten([
    for scope_name, ids in local.read_group_ids : [
      for chunk in chunklist(ids, 300) : {
        effect            = "allow"
        permission_groups = [for id in chunk : { id = id }]
        resources         = local.read_resources[scope_name]
      }
    ]
  ])

  # Admin mode keeps the original account-owned account and zone permissions.
  admin_scopes = {
    account = "com.cloudflare.api.account"
    zone    = "com.cloudflare.api.account.zone"
  }

  # Keep the resource expression evaluable in read-only mode, where the
  # account ID is intentionally absent. Admin's precondition rejects it.
  admin_account_id = var.cloudflare_account_id != null ? var.cloudflare_account_id : ""

  admin_resources = {
    account = jsonencode({
      "com.cloudflare.api.account.${local.admin_account_id}" = "*"
    })
    zone = jsonencode({
      "com.cloudflare.api.account.${local.admin_account_id}" = {
        "com.cloudflare.api.account.zone.*" = "*"
      }
    })
  }

  admin_group_ids = var.token_mode == "admin" ? {
    for scope_name, scope_id in local.admin_scopes : scope_name => sort(distinct([
      for group in data.cloudflare_account_api_token_permission_groups_list.all[0].result : group.id
      if contains(group.scopes, scope_id)
    ]))
  } : {}

  admin_policies = flatten([
    for scope_name, ids in local.admin_group_ids : [
      for chunk in chunklist(ids, 300) : {
        effect            = "allow"
        permission_groups = [for id in chunk : { id = id }]
        resources         = local.admin_resources[scope_name]
      }
    ]
  ])
}

moved {
  from = cloudflare_account_token.superuser
  to   = cloudflare_account_token.bootstrap
}

moved {
  from = cloudflare_account_token.bootstrap
  to   = cloudflare_account_token.bootstrap[0]
}

resource "cloudflare_api_token" "read_all" {
  count    = var.token_mode == "read_only" ? 1 : 0
  name     = var.token_name != null ? var.token_name : "cloudflare-read-all"
  policies = local.read_policies

  condition = length(var.allowed_cidrs) > 0 ? {
    request_ip = {
      in = var.allowed_cidrs
    }
  } : null

  lifecycle {
    precondition {
      condition     = length(local.read_group_ids.account) > 0 && length(local.read_group_ids.zone) > 0 && length(local.read_group_ids.user) > 0
      error_message = "Cloudflare returned no account, zone, or user read permission groups."
    }
  }
}

resource "cloudflare_account_token" "bootstrap" {
  count      = var.token_mode == "admin" ? 1 : 0
  account_id = var.cloudflare_account_id
  name       = var.token_name != null ? var.token_name : "cloudflare-admin"
  policies   = local.admin_policies

  condition = length(var.allowed_cidrs) > 0 ? {
    request_ip = {
      in = var.allowed_cidrs
    }
  } : null

  lifecycle {
    precondition {
      condition     = var.cloudflare_account_id != null && length(local.admin_group_ids.account) > 0 && length(local.admin_group_ids.zone) > 0
      error_message = "Admin mode requires cloudflare_account_id and account and zone permission groups."
    }
  }
}
