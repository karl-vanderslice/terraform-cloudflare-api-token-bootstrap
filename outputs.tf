output "superuser_api_token_id" {
  description = "ID of the generated superuser API token."
  value       = cloudflare_account_token.superuser.id
}

output "superuser_api_token_value" {
  description = "Generated API token value. Store it securely; Cloudflare returns it only at creation time."
  value       = cloudflare_account_token.superuser.value
  sensitive   = true
}
