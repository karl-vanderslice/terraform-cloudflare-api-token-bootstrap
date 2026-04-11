provider "cloudflare" {
  email   = var.cloudflare_email
  api_key = var.cloudflare_global_api_key
}

data "cloudflare_accounts" "all" {}

data "cloudflare_accounts" "named" {
  count = var.cloudflare_account_name != null ? 1 : 0
  name  = var.cloudflare_account_name
}

data "cloudflare_account_api_token_permission_groups_list" "all" {
  account_id = local.target_account_id
}

data "cloudflare_zones" "all" {
  account = {
    id = local.target_account_id
  }
  max_items = 1000
}

locals {
  target_account_id = coalesce(
    var.cloudflare_account_id,
    var.cloudflare_account_name != null ? data.cloudflare_accounts.named[0].result[0].id : null,
    data.cloudflare_accounts.all.result[0].id
  )

  allowed_permission_scopes = toset([
    "com.cloudflare.api.account",
    "com.cloudflare.api.account.zone",
  ])

  # Collect every available permission group in supported scopes.
  superuser_permission_group_ids = distinct([
    for group in data.cloudflare_account_api_token_permission_groups_list.all.result : group.id
    if length(setintersection(toset(group.scopes), local.allowed_permission_scopes)) > 0
  ])

  # Cloudflare allows at most 300 permission groups per policy.
  superuser_permission_group_chunks = chunklist(local.superuser_permission_group_ids, 300)

  base_superuser_resources = {
    "com.cloudflare.api.account.${local.target_account_id}" = "*"
  }

  zone_superuser_resources = {
    for zone in data.cloudflare_zones.all.result :
    "com.cloudflare.api.account.zone.${zone.id}" => "*"
  }

  superuser_resources = merge(local.base_superuser_resources, local.zone_superuser_resources)
}

check "account_selector_inputs" {
  assert {
    condition = !(
      var.cloudflare_account_id != null &&
      var.cloudflare_account_name != null
    )
    error_message = "Set only one of cloudflare_account_id or cloudflare_account_name."
  }
}

resource "cloudflare_account_token" "superuser" {
  account_id = local.target_account_id
  name       = var.token_name

  policies = [
    for permission_group_chunk in local.superuser_permission_group_chunks : {
      effect = "allow"
      permission_groups = [
        for id in permission_group_chunk : {
          id = id
        }
      ]
      resources = jsonencode(local.superuser_resources)
    }
  ]

  condition = length(var.allowed_cidrs) > 0 ? {
    request_ip = {
      in = var.allowed_cidrs
    }
  } : null
}
