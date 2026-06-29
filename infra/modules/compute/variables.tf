variable "name_prefix" {
  description = "Common name prefix, e.g. sentinelpay-dev."
  type        = string
}

# --- wiring from other modules ---
variable "vpc_id" {
  description = "VPC ID (network module)."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets for the ALB."
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnets for the Fargate tasks."
  type        = list(string)
}

variable "payments_task_role_arn" {
  description = "payments-api task role ARN (identity module)."
  type        = string
}

variable "payments_exec_role_arn" {
  description = "payments-api execution role ARN (identity module)."
  type        = string
}

variable "kyc_task_role_arn" {
  description = "kyc-api task role ARN (identity module)."
  type        = string
}

variable "kyc_exec_role_arn" {
  description = "kyc-api execution role ARN (identity module)."
  type        = string
}

# --- images (placeholder by default; real images pushed in Week 3) ---
variable "payments_image" {
  description = "Container image for payments-api. Defaults to a public placeholder so the infra stands up before real images exist in ECR."
  type        = string
  default     = "public.ecr.aws/nginx/nginx:stable"
}

variable "kyc_image" {
  description = "Container image for kyc-api (placeholder by default)."
  type        = string
  default     = "public.ecr.aws/nginx/nginx:stable"
}

variable "payments_container_port" {
  description = "Port the payments container listens on. Placeholder nginx uses 80; real app uses 8001."
  type        = number
  default     = 80
}

variable "kyc_container_port" {
  description = "Port the kyc container listens on. Placeholder nginx uses 80; real app uses 8002."
  type        = number
  default     = 80
}

# --- sizing / cost ---
variable "task_cpu" {
  description = "Fargate task CPU units (256 = 0.25 vCPU, the smallest)."
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Fargate task memory in MB (512 is the smallest for 256 CPU)."
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "How many tasks to run per service. 1 keeps cost minimal."
  type        = number
  default     = 1
}

variable "payments_rate_limit" {
  description = "WAF rate-limit: max requests per 5 min per IP to the payments path."
  type        = number
  default     = 1000
}
variable "kms_key_arn" {
  description = "Customer-managed KMS key ARN for encrypting CloudWatch log groups."
  type        = string
}