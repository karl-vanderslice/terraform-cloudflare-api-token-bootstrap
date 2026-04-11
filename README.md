# Terraform Cloudflare API Token Bootstrap

Creates a Cloudflare account API token with effectively superuser access by:

- Authenticating with a Cloudflare user Global API Key.
- Detecting the target account (or using an explicit account ID).
- Loading all account API token permission groups via the v5 list data source.
- Granting those permissions over the account and all zones in that account.

By default, the token includes account and account-zone scoped permissions.

## Files

- `main.tf`: Provider config, permission group discovery, and token resource.
- `variables.tf`: Inputs, including global API key.
- `outputs.tf`: Token ID and sensitive token value.
- `terraform.tfvars.example`: Example input values.

## Usage

1. Create your variables file:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Fill in `terraform.tfvars` with your Cloudflare email and global API key.

3. Enter the Nix dev shell:

   ```bash
   nix develop
   ```

4. Install Git hooks once per clone:

   ```bash
   just install-hooks
   ```

5. Run local quality and security checks:

   ```bash
   just ci
   ```

6. Initialize and apply:

   ```bash
   terraform init
   terraform apply
   ```

7. Read the sensitive token output when apply completes, then store it in your secret manager.

## Sensible defaults

- `token_name` defaults to `terraform-superuser`.
- `allowed_cidrs` defaults to empty (`[]`) so no IP restriction is applied by default.
- If `allowed_cidrs` is provided, a token IP allow-list condition is added.
- `cloudflare_account_id` defaults to `null`; when set, it is used directly.
- `cloudflare_account_name` defaults to `null`; when account ID is unset, this name is used.
- If both are unset, the first account returned by the API is used.

## Provider version

This configuration targets Cloudflare Terraform provider v5+.

## Security note

This token is intentionally broad for bootstrap workflows. After bootstrapping, consider rotating to narrower-scoped tokens per automation use case.

## Justfile helpers

- `just fmt` runs `terraform fmt -recursive`.
- `just init` initializes Terraform in the Nix shell.
- `just validate` runs `terraform init -backend=false` and `terraform validate`.
- `just plan` runs plan in the Nix shell.
- `just apply` runs apply in the Nix shell.
- `just checkov` runs Checkov against Terraform files.
- `just lint` runs all Nix-defined checks (including hooks) via `nix flake check`.
- `just install-hooks` enters the Nix dev shell to install git hooks from `nix-pre-commit-hooks`.
- `just ci` runs the same Nix-defined checks used by CI.
- `just show-token-id` prints the token ID.
- `just show-token-value` prints the token value.

## Security and secret hygiene

- `.gitignore` excludes local state and variable files, including `terraform.tfvars`.
- Git hooks are managed by `https://github.com/serokell/nix-pre-commit-hooks` from the Nix flake.
- Terraform format, Checkov, and secret scanning are enforced as Nix flake checks.

## CI/CD

GitHub Actions is configured at `.github/workflows/ci.yml` to run on push and pull requests.

- `nix flake check` only, with all quality/security gates defined in the flake.
