mock_provider "cloudflare" {}

run "reject_invalid_user_id" {
  command = plan

  variables {
    cloudflare_user_id = "not-a-user-id"
  }

  expect_failures = [var.cloudflare_user_id]
}

run "reject_invalid_account_id" {
  command = plan

  variables {
    cloudflare_account_id = "not-an-account-id"
    cloudflare_user_id    = "0123456789abcdef0123456789abcdef"
  }

  expect_failures = [var.cloudflare_account_id, cloudflare_api_token.read_all[0]]
}

run "reject_unknown_mode" {
  command = plan

  variables {
    token_mode = "write"
  }

  expect_failures = [var.token_mode]
}

run "reject_empty_permission_catalog" {
  command = plan

  variables {
    cloudflare_user_id = "0123456789abcdef0123456789abcdef"
  }

  expect_failures = [cloudflare_api_token.read_all[0]]
}

run "admin_mode_uses_account_token" {
  command = plan

  variables {
    token_mode            = "admin"
    cloudflare_account_id = "0123456789abcdef0123456789abcdef"
  }

  expect_failures = [cloudflare_account_token.bootstrap[0]]
}
