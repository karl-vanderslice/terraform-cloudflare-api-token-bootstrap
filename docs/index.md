# terraform-cloudflare-api-token-bootstrap

## Purpose

This repository bootstraps Terraform-managed creation of a broad Cloudflare API
token for initial platform setup tasks. It is intended for controlled bootstrap
use, not permanent high-privilege operation.

## What this repo manages

It manages Terraform configuration that provisions a Cloudflare token with
broad permissions needed for first-stage automation. It also captures required
variables and outputs for downstream workflows. Because token scope is
intentionally wide at bootstrap time, this repo should be treated as sensitive
operational infrastructure.

## Next steps

Define and enforce a short validity window for bootstrap tokens. Rotate to
narrower, role-specific tokens immediately after initial provisioning. Add
explicit runbook steps for revocation, emergency rotation, and post-bootstrap
permission reduction.
