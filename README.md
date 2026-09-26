# Cloudflare API token bootstrap

Create one account-owned Cloudflare API token with Terraform. The default
`read_only` mode grants available read permissions for the selected account,
its zones, and its R2 buckets. Set `token_mode = "admin"` to retain the broad
account and zone permissions used by the original bootstrap configuration.

This repository uses local Terraform state. It does not configure HCP Terraform,
store bootstrap credentials in variables, or configure a downstream MCP server.

## Scope and limits

The token belongs to **one explicitly selected Cloudflare account**. Policies
cover that account, all current and future zones in it, and, in read-only mode,
all R2 buckets in it. Cloudflare assigns permissions to distinct account, zone,
and bucket resource scopes, so Terraform builds a separate policy for each.
Permission groups come from Cloudflare's account-token API at plan time. Read-only
mode selects groups whose names end in `Read` or `Read-Only`, plus the
documented read-only `Account Security Center Insights` group. Review the
planned permission changes whenever Cloudflare adds groups.

An account-owned token cannot grant user-scoped permissions, cover other
accounts, or access products that do not support account tokens. Cloudflare
maintains a [product compatibility matrix](https://developers.cloudflare.com/fundamentals/api/get-started/account-owned-tokens/).
If your MCP server needs user resources or multiple accounts, create a
user-owned token with Cloudflare's
[Read All Resources template](https://developers.cloudflare.com/fundamentals/api/reference/template/)
in the dashboard instead. That token has the user's access boundary and is not
managed by this repository. A read-only token also does not make an MCP server's
tools read-only; configure the server's allowed tools separately.

## Quick start

You need Nix, access to the target Cloudflare account as a Super Administrator,
and a bootstrap credential authorized for **Account API Tokens Write** on that
account. Find the account ID in the Cloudflare dashboard. Cloudflare documents
[account-token creation requirements](https://developers.cloudflare.com/fundamentals/api/get-started/account-owned-tokens/)
and the [token creation API permission](https://developers.cloudflare.com/api/resources/accounts/subresources/tokens/methods/create/).

1. Enter the development shell and set the account ID:

   ```sh
   nix develop
   cp terraform.tfvars.example terraform.tfvars
   ```

   Replace the example ID in the ignored `terraform.tfvars`. Leave
   `token_mode` unset for read-only access. Set `token_mode = "admin"` only
   for the original broad bootstrap use case.

2. Supply a bootstrap credential using one of the paths in
   [Bootstrap authentication](#bootstrap-authentication). Keep it outside
   Terraform variables and the repository.

3. Check the configuration and inspect the actual plan:

   ```sh
   just ci
   just init
   just plan
   ```

   Confirm the account ID, token name, resource scopes, permission groups, and
   that the plan changes only the intended token. `just plan` calls Cloudflare
   but does not create a token.

4. Create or update the token:

   ```sh
   just apply
   ```

   Terraform asks for approval. Retrieve `api_token_value` with
   `terraform output -raw api_token_value` in a private terminal, or pipe it
   directly into the secret transport owned by your MCP server. This command
   prints the secret; never log or save its output in the repository. The non-secret
   `api_token_id` is available with `just show-token-id`. Do not place the
   token value in an MCP config committed to Git.

5. Remove the bootstrap credential from the shell:

   ```sh
   unset CLOUDFLARE_API_TOKEN CLOUDFLARE_API_KEY CLOUDFLARE_EMAIL
   ```

   Keep the local state secure while the token exists. The token value remains
   in state even though Terraform marks its output sensitive.

## Bootstrap authentication

Cloudflare's Terraform provider reads `CLOUDFLARE_API_TOKEN` or the legacy
`CLOUDFLARE_API_KEY` and `CLOUDFLARE_EMAIL` environment variables. It does not
accept a Cloudflare username and password directly. Use the dashboard login to
create a short-lived bootstrap token, or use Wrangler's browser login and pass
its access token into the shell. Cloudflare documents the
[provider environment variables](https://developers.cloudflare.com/api/terraform/)
and [Wrangler authentication commands](https://developers.cloudflare.com/workers/wrangler/commands/general/).

### Short-lived bootstrap API token

In **Manage Account > Account API Tokens**, create a token for the selected
account with `Account API Tokens Write`. Set a short expiration and, if useful,
a client IP restriction. The bootstrap token is separate from the token that
this repository creates. Enter its value without shell echo or history:

```sh
read -rsp 'Bootstrap API token: ' CLOUDFLARE_API_TOKEN
printf '\n'
export CLOUDFLARE_API_TOKEN
```

The read-only output token cannot create another token. Creating an
account-owned token still requires write-capable bootstrap authority.

### Wrangler browser login

If you already have Wrangler installed, log in using your normal Cloudflare
dashboard account. Wrangler can keep its OAuth refresh credential in the OS
keyring with `--use-keyring`; its default storage is a plaintext local file.
The Terraform provider does not read Wrangler's login itself. Move only the
short-lived access token into the current shell:

```sh
unset CLOUDFLARE_API_TOKEN CLOUDFLARE_API_KEY CLOUDFLARE_EMAIL
wrangler login --use-keyring
IFS= read -r CLOUDFLARE_API_TOKEN < <(wrangler auth token)
export CLOUDFLARE_API_TOKEN
```

The shell bridge requires Bash. If the access token expires between plan and
apply, repeat the `read` and `export` lines to obtain a refreshed token.
The Wrangler login must have enough Cloudflare authorization to create account
tokens; if Cloudflare rejects it, use the short-lived bootstrap API token path.
Run `wrangler logout` when you want to revoke Wrangler's OAuth session.
Wrangler is optional and is not a dependency of this Nix shell.

### Global API key

The legacy Global API Key works with the account email, but is long-lived and
broad. Use it only if a scoped bootstrap token or Wrangler login is unavailable:

```sh
read -rp 'Cloudflare account email: ' CLOUDFLARE_EMAIL
read -rsp 'Global API key: ' CLOUDFLARE_API_KEY
printf '\n'
export CLOUDFLARE_EMAIL CLOUDFLARE_API_KEY
```

Keep `CLOUDFLARE_API_TOKEN` unset when using this path. Never put any of these
credentials in `terraform.tfvars`, `.env`, command arguments, or saved plans.

## Local state and migration

The local backend writes `terraform.tfstate` and backup files beside the
configuration. These files contain the created token value in plaintext.
`.gitignore` excludes them and local plan and variable files. Keep the
directory accessible only to the operator, back up state through an encrypted
secret storage process, and delete backups through that process when no longer
needed. Losing state does not revoke the token; revoke it in Cloudflare if the
value or state is exposed.

If this repository was already applied through HCP Terraform, **migrate its
state before applying this local backend**. In the existing initialized
working directory, take a protected state backup using your approved secret
transport. After updating the configuration, run
`terraform init -migrate-state` and inspect the migration prompt and
resulting local state.
Do not run `terraform init -reconfigure` against an existing remote state:
that disconnects Terraform from the managed token and can produce a duplicate
token on the next apply. The repository does not run this migration for you.

Existing state addresses migrate from
`cloudflare_account_token.superuser` to `cloudflare_account_token.bootstrap`
through a Terraform `moved` block. Changing from the old broad token to
`read_only` intentionally changes its permissions. Review that plan before
apply. Existing output names also change to `api_token_id` and
`api_token_value`.

## Development

`just fmt` formats Terraform. `just test` runs validation and input
regression tests without Cloudflare credentials. `just ci` runs the Nix
quality checks and tests. `just terraform-docs` refreshes the generated
reference below. `just install-hooks` installs the repository's Nix-managed
Git hooks.

## Terraform reference

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0 |
| <a name="requirement_cloudflare"></a> [cloudflare](#requirement\_cloudflare) | >= 5.0, < 6.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_cloudflare"></a> [cloudflare](#provider\_cloudflare) | 5.19.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [cloudflare_account_token.bootstrap](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/account_token) | resource |
| [cloudflare_account_api_token_permission_groups_list.all](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/data-sources/account_api_token_permission_groups_list) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allowed_cidrs"></a> [allowed\_cidrs](#input\_allowed\_cidrs) | Optional client IP CIDR allow-list. Empty permits use from any client IP. | `list(string)` | `[]` | no |
| <a name="input_cloudflare_account_id"></a> [cloudflare\_account\_id](#input\_cloudflare\_account\_id) | Cloudflare account ID that owns the token and defines its resource boundary. | `string` | n/a | yes |
| <a name="input_token_mode"></a> [token\_mode](#input\_token\_mode) | Permission mode: read\_only grants account, zone, and R2 bucket read groups; admin grants all account and zone groups. | `string` | `"read_only"` | no |
| <a name="input_token_name"></a> [token\_name](#input\_token\_name) | Optional token name. Defaults to cloudflare-read-only or cloudflare-admin. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_token_id"></a> [api\_token\_id](#output\_api\_token\_id) | ID of the account-owned API token. |
| <a name="output_api_token_value"></a> [api\_token\_value](#output\_api\_token\_value) | Account-owned API token secret. Terraform stores this value in local state. |
<!-- END_TF_DOCS -->
