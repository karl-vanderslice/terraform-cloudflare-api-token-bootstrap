variable "cloudflare_email" {
  description = "Cloudflare account email used with the global API key."
  type        = string
}

variable "cloudflare_global_api_key" {
  description = "Cloudflare Global API Key for bootstrapping the token."
  type        = string
  sensitive   = true
}

variable "token_name" {
  description = "Name for the superuser API token."
  type        = string
  default     = "terraform-superuser"

  validation {
    condition     = length(trimspace(var.token_name)) > 0
    error_message = "token_name must not be empty."
  }
}

variable "cloudflare_account_id" {
  description = "Optional Cloudflare account ID. If unset, the first account returned by the API is used."
  type        = string
  default     = null
  nullable    = true
}

variable "cloudflare_account_name" {
  description = "Optional Cloudflare account name. Used when cloudflare_account_id is not set."
  type        = string
  default     = null
  nullable    = true
}

variable "allowed_cidrs" {
  description = "Optional CIDR allow-list for API token usage. Leave empty for no IP restriction."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for cidr in var.allowed_cidrs : can(cidrhost(cidr, 0))
    ])
    error_message = "Each value in allowed_cidrs must be a valid CIDR notation string."
  }
}
