# In infra/main.tf, the `module "compute"` block: ADD this line
# (data module is created before compute, so module.data.kms_key_arn is available):

  kms_key_arn = module.data.kms_key_arn

# So the compute block becomes:
#
# module "compute" {
#   source      = "./modules/compute"
#   name_prefix = local.name_prefix
#   vpc_id             = module.network.vpc_id
#   public_subnet_ids  = module.network.public_subnet_ids
#   private_subnet_ids = module.network.private_subnet_ids
#   payments_task_role_arn = module.identity.payments_task_role_arn
#   payments_exec_role_arn = module.identity.payments_exec_role_arn
#   kyc_task_role_arn      = module.identity.kyc_task_role_arn
#   kyc_exec_role_arn      = module.identity.kyc_exec_role_arn
#   kms_key_arn            = module.data.kms_key_arn   # <-- ADD THIS
# }
