mock_provider "cloudflare" {}

run "reject_invalid_account_id" {
  command = plan

  variables {
    cloudflare_account_id = "not-an-account-id"
  }

  expect_failures = [var.cloudflare_account_id]
}

run "reject_unknown_mode" {
  command = plan

  variables {
    cloudflare_account_id = "0123456789abcdef0123456789abcdef"
    token_mode            = "write"
  }

  expect_failures = [var.token_mode]
}

run "reject_empty_permission_catalog" {
  command = plan

  variables {
    cloudflare_account_id = "0123456789abcdef0123456789abcdef"
  }

  expect_failures = [cloudflare_account_token.bootstrap]
}
