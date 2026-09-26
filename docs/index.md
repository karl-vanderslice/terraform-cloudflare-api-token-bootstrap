# Cloudflare API token bootstrap

This repository creates a user-owned Cloudflare Read All Resources token by
default. Its read permissions cover every account and zone available to the
authenticated user and the user's own resources. An explicit `admin` mode
retains the original broad account-owned token for one selected account.

The [repository README](https://github.com/karl-vanderslice/terraform-cloudflare-api-token-bootstrap#readme)
covers setup, Wrangler login, local state, mode changes, and migration. Its
generated Terraform reference lists the exact inputs and outputs.
