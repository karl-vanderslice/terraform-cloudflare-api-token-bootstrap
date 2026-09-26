output "api_token_id" {
  description = "ID of the account-owned API token."
  value       = cloudflare_account_token.bootstrap.id
}

output "api_token_value" {
  description = "Account-owned API token secret. Terraform stores this value in local state."
  value       = cloudflare_account_token.bootstrap.value
  sensitive   = true
}
