default:
  @just --list

fmt:
  nix develop -c terraform fmt -recursive

init:
  nix develop -c terraform init -upgrade

validate:
  nix develop -c terraform init -backend=false
  nix develop -c terraform validate

plan:
  nix develop -c terraform plan

apply:
  nix develop -c terraform apply -auto-approve

checkov:
  nix develop -c checkov -d . --config-file .checkov.yaml

lint:
  nix flake check --print-build-logs

pre-commit:
  nix build .#checks.x86_64-linux.pre-commit

install-hooks:
  nix develop -c true

ci:
  just lint

terraform-docs:
  nix develop -c terraform-docs markdown table --output-file README.md --output-mode inject .

show-token-id:
  nix develop -c terraform output -raw superuser_api_token_id

show-token-value:
  nix develop -c terraform output -raw superuser_api_token_value
