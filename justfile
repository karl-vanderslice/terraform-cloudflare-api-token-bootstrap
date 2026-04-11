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
  nix develop -c pre-commit run --all-files --show-diff-on-failure

install-hooks:
  nix develop -c pre-commit install --install-hooks

ci:
  nix flake check --print-build-logs
  just lint

show-token-id:
  nix develop -c terraform output -raw superuser_api_token_id

show-token-value:
  nix develop -c terraform output -raw superuser_api_token_value
