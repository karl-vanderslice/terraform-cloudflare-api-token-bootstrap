# AGENTS

## Snapshot

- Purpose: this repo bootstraps broad-scope Cloudflare API token access for
  initial platform setup.
- Load order: load this file first. Repo-local prompt/skill overlays are not
  present yet.
- Primary docs: `README.md`, `docs/index.md`, and generated `terraform-docs`
  reference blocks.

## Working Rules

- Keep Terraform variable, output, and module descriptions complete enough for
  `terraform-docs`; generated Markdown is the canonical reference surface.
- Prefer `just` targets in docs when they exist instead of duplicating raw
  Terraform and shell commands.
- Keep bootstrap risk, scope, and rotation guidance in explanation docs rather
  than mixing it into generated reference tables.
- Do not add duplicate overview pages such as `docs/README.md`.
