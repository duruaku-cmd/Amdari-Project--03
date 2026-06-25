variable "name_prefix" {
  description = "Common name prefix, e.g. sentinelpay-dev."
  type        = string
}

variable "kms_key_arn" {
  description = "Customer-managed CMK (from the data module) used to encrypt the CloudTrail log bucket and trail."
  type        = string
}

# --- toggles for account-gated paid services ---
# This sandbox/Free-Tier account returns SubscriptionRequiredException for
# GuardDuty / Security Hub / Config. The code is written and correct; these
# default to false so `apply` succeeds, and flip to true on a fuller account.
variable "enable_guardduty" {
  description = "Enable GuardDuty (V-CLD-07). Requires an account that can subscribe to GuardDuty."
  type        = bool
  default     = false
}

variable "enable_security_hub" {
  description = "Enable Security Hub with FSBP + CIS standards. Requires a subscribing account."
  type        = bool
  default     = false
}

variable "enable_config" {
  description = "Enable AWS Config recorder + CIS rule pack. Requires a subscribing account."
  type        = bool
  default     = false
}

variable "guardduty_finding_threshold" {
  description = "Minimum GuardDuty finding severity (numeric) that triggers the containment Lambda. 7.0 = High."
  type        = number
  default     = 7.0
}
