output "api_token_id" {
  description = "ID of the token created in the selected mode."
  value       = var.token_mode == "read_only" ? cloudflare_api_token.read_all[0].id : cloudflare_account_token.bootstrap[0].id
}

output "api_token_value" {
  description = "Token secret. Terraform stores this value in local state."
  value       = var.token_mode == "read_only" ? cloudflare_api_token.read_all[0].value : cloudflare_account_token.bootstrap[0].value
  sensitive   = true
}
