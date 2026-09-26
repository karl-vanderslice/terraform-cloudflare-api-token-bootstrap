variable "cloudflare_account_id" {
  description = "Cloudflare account ID that owns the token and defines its resource boundary."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F]{32}$", var.cloudflare_account_id))
    error_message = "cloudflare_account_id must be a 32-character hexadecimal Cloudflare account ID."
  }
}

variable "token_mode" {
  description = "Permission mode: read_only grants account, zone, and R2 bucket read groups; admin grants all account and zone groups."
  type        = string
  default     = "read_only"

  validation {
    condition     = contains(["read_only", "admin"], var.token_mode)
    error_message = "token_mode must be read_only or admin."
  }
}

variable "token_name" {
  description = "Optional token name. Defaults to cloudflare-read-only or cloudflare-admin."
  type        = string
  default     = null

  validation {
    condition     = var.token_name == null || (length(trimspace(var.token_name)) > 0 && length(var.token_name) <= 120)
    error_message = "token_name must contain 1 to 120 characters when set."
  }
}

variable "allowed_cidrs" {
  description = "Optional client IP CIDR allow-list. Empty permits use from any client IP."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for cidr in var.allowed_cidrs : can(cidrhost(cidr, 0))])
    error_message = "Each allowed_cidrs value must be a valid CIDR."
  }
}
