# Cloudflare API token bootstrap

Create a Cloudflare API token with Terraform and keep its state locally. The
default `read_only` mode creates a **user-owned Read All Resources token** for
an MCP client. It grants available read permissions across every account and
zone that the authenticated user can access, plus the user's own resources.
Set `token_mode = "admin"` to keep the original broad, account-owned bootstrap
token for one selected account.

## Access model

Cloudflare's [Read All Resources template](https://developers.cloudflare.com/fundamentals/api/reference/template/)
combines account, zone, and user read permissions with all-account and all-zone
resources. This configuration discovers the current user-token permission
groups and builds a separate policy for each scope. It selects groups whose
names end in `Read` or `Read-Only`, plus the documented read-only
`Account Security Center Insights` group. Cloudflare can add or rename
groups, so inspect each plan before applying permission changes.

User tokens inherit the user's access. A token cannot read resources that its
owner cannot access, and a read permission does not make every MCP tool
read-only. Configure the MCP server's tool allowlist separately. Cloudflare
documents the [permission scopes](https://developers.cloudflare.com/fundamentals/api/reference/permissions/)
and [user versus account token behavior](https://developers.cloudflare.com/fundamentals/api/get-started/account-owned-tokens/).

The `admin` mode retains all available account and zone permission groups for
one explicit `cloudflare_account_id`. It creates an account-owned token, not a
user token. Switching modes changes token ownership and plans to revoke the
old token and create the other one. Review the plan and coordinate the MCP
credential handoff before applying a mode change.

## Quick start

You need Nix and a bootstrap credential that can create **user-owned** API
tokens. Cloudflare's [Create Additional Tokens template](https://developers.cloudflare.com/fundamentals/api/how-to/create-via-api/)
grants that capability. A Wrangler browser session may also work if its OAuth
grant has the required access.

1. Enter the development shell, or run `direnv allow` once if you use direnv:

   ```sh
   nix develop
   ```

   The shell provides Terraform, Wrangler, and the `just` task runner. The
   tracked `.envrc` loads the same flake when direnv is enabled. Copy
   `terraform.tfvars.example` to ignored `terraform.tfvars` only when you
   want to set an optional input. Read-only mode needs no account ID.

2. Supply a credential from [Bootstrap authentication](#bootstrap-authentication).
   Keep it outside Terraform variables and the repository.

3. Validate and review the plan:

   ```sh
   just ci
   just init
   just plan
   ```

   Confirm the token type, permission groups, resource scopes, and any
   replacement of an existing token. If the current-user lookup fails because
   the bootstrap credential lacks `User Details Read`, set
   `cloudflare_user_id` in `terraform.tfvars` and plan again.

4. Apply the reviewed plan:

   ```sh
   just apply
   ```

   Terraform asks for approval. Retrieve the sensitive output with
   `terraform output -raw api_token_value` in a private terminal, or pipe it
   into the secret transport owned by your MCP server. That command prints
   the secret; never log or commit its output. `just show-token-id` prints
   the non-secret token ID.

5. Remove the bootstrap credential from the shell:

   ```sh
   unset CLOUDFLARE_API_TOKEN CLOUDFLARE_API_KEY CLOUDFLARE_EMAIL
   ```

   Keep the local state protected while the token exists.

## Bootstrap authentication

The Cloudflare provider reads `CLOUDFLARE_API_TOKEN` or the legacy
`CLOUDFLARE_API_KEY` and `CLOUDFLARE_EMAIL` environment variables. It does
not accept a username and password directly. Cloudflare documents the
[provider environment variables](https://developers.cloudflare.com/api/terraform/).

### Short-lived API token

Sign in to the Cloudflare dashboard with your normal credentials. Under
**My Profile > API Tokens**, create a temporary token from **Create Additional
Tokens**. Restrict its lifetime and client IP if practical. Enter the token
into the current shell without echoing it or putting it in shell history:

```sh
read -rsp 'Bootstrap API token: ' CLOUDFLARE_API_TOKEN
printf '\n'
export CLOUDFLARE_API_TOKEN
```

The template grants `API Tokens Write`, which can create user tokens. It does
not necessarily grant `User Details Read`. If Terraform cannot look up the
current user's ID, supply `cloudflare_user_id` from a trusted user-profile
record. Cloudflare's [current-user API](https://developers.cloudflare.com/api/resources/user/methods/get/)
returns that ID when the credential has `User Details Read`.

### Wrangler browser login

The development shell includes Wrangler. Use its browser OAuth flow, then
pass the access token to Terraform without printing it:

```sh
unset CLOUDFLARE_API_TOKEN CLOUDFLARE_API_KEY CLOUDFLARE_EMAIL
wrangler login
IFS= read -r CLOUDFLARE_API_TOKEN < <(wrangler auth token)
export CLOUDFLARE_API_TOKEN
```

This shell bridge requires Bash. The provider does not read Wrangler's
session automatically. Repeat the `read` and `export` lines if the access
token expires before apply. The pinned Wrangler package stores OAuth
credentials in a local config file during login; run `wrangler logout` after
the bootstrap to revoke the session and remove that file. Do not print
`wrangler auth token` to the terminal. If Cloudflare rejects the OAuth
credential for token creation, use the short-lived API token path.
Cloudflare documents [Wrangler login and token retrieval](https://developers.cloudflare.com/workers/wrangler/commands/general/).

### Global API key

The Global API Key works with the account email but is long-lived and broad.
Use it only if the other paths are unavailable:

```sh
read -rp 'Cloudflare account email: ' CLOUDFLARE_EMAIL
read -rsp 'Global API key: ' CLOUDFLARE_API_KEY
printf '\n'
export CLOUDFLARE_EMAIL CLOUDFLARE_API_KEY
```

Keep `CLOUDFLARE_API_TOKEN` unset on this path. Do not put credentials in
`terraform.tfvars`, `.env`, command arguments, or saved plans.

## Admin mode

Copy `terraform.tfvars.example` to ignored `terraform.tfvars`, then set:

```hcl
token_mode            = "admin"
cloudflare_account_id = "0123456789abcdef0123456789abcdef"
```

Use a bootstrap credential with **Account API Tokens Write** and the
required account role. Cloudflare documents the
[account-token requirements](https://developers.cloudflare.com/fundamentals/api/get-started/account-owned-tokens/).
Review the broad policy before `just apply`.

## Local state and existing deployments

The local backend writes `terraform.tfstate` and backups beside the
configuration. State contains the output token value in plaintext even though
Terraform marks the output sensitive. `.gitignore` excludes state, variables,
plans, and generated files. Keep this directory private and back up state
through an encrypted secret storage process. Losing state does not revoke
the token.

If an earlier version used HCP Terraform, migrate its state before applying
the local backend. In the existing initialized working directory, take a
protected backup, update the configuration, then run
`terraform init -migrate-state`. Inspect the migration prompt and local
state. Do not use `terraform init -reconfigure` on that existing remote
state: it disconnects the managed token.

Terraform moves existing `cloudflare_account_token.superuser` or
`cloudflare_account_token.bootstrap` state to
`cloudflare_account_token.bootstrap[0]` for admin mode. The new default
read-only mode instead plans a **new user token and removal of any previously
managed account token**. Complete the MCP credential handoff before approving
that plan. Output names remain `api_token_id` and `api_token_value`.

## Development

`just fmt` formats Terraform. `just test` runs validation and input
regression tests without Cloudflare credentials. `just ci` runs the Nix
quality checks and tests. `just terraform-docs` refreshes the generated
reference below. `just install-hooks` installs the Nix-managed Git hooks.

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
| [cloudflare_api_token.read_all](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/api_token) | resource |
| [cloudflare_account_api_token_permission_groups_list.all](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/data-sources/account_api_token_permission_groups_list) | data source |
| [cloudflare_api_token_permission_groups_list.all](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/data-sources/api_token_permission_groups_list) | data source |
| [cloudflare_user.current](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/data-sources/user) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allowed_cidrs"></a> [allowed\_cidrs](#input\_allowed\_cidrs) | Optional client IP CIDR allow-list. Empty permits use from any client IP. | `list(string)` | `[]` | no |
| <a name="input_cloudflare_account_id"></a> [cloudflare\_account\_id](#input\_cloudflare\_account\_id) | Account ID required only in admin mode. | `string` | `null` | no |
| <a name="input_cloudflare_user_id"></a> [cloudflare\_user\_id](#input\_cloudflare\_user\_id) | Optional user ID for the read-only token. If unset, the provider looks up the authenticated user. | `string` | `null` | no |
| <a name="input_token_mode"></a> [token\_mode](#input\_token\_mode) | read\_only creates a user-owned Read All Resources token; admin keeps the account-owned broad token. | `string` | `"read_only"` | no |
| <a name="input_token_name"></a> [token\_name](#input\_token\_name) | Optional token name. Defaults to cloudflare-read-all or cloudflare-admin. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_token_id"></a> [api\_token\_id](#output\_api\_token\_id) | ID of the token created in the selected mode. |
| <a name="output_api_token_value"></a> [api\_token\_value](#output\_api\_token\_value) | Token secret. Terraform stores this value in local state. |
<!-- END_TF_DOCS -->
