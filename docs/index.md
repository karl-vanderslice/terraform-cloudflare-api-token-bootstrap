# Cloudflare API token bootstrap

This repository creates one account-owned Cloudflare token for a selected
account. The default is broad read access to account, zone, and R2 bucket
resources. An explicit `admin` mode retains broad account and zone
permissions for bootstrap work.

Start with the [repository README](https://github.com/karl-vanderslice/terraform-cloudflare-api-token-bootstrap#readme)
for setup, authentication, local state, and migration instructions. Its
generated Terraform reference lists the exact inputs and outputs.

Read-only access follows Cloudflare's token permission groups and product
support. Cloudflare account-owned tokens do not cover user-scoped resources or
every Cloudflare product. Review the [account token compatibility
matrix](https://developers.cloudflare.com/fundamentals/api/get-started/account-owned-tokens/)
before assigning the credential to a client.
