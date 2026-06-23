# =====================================================================
# Database credential rotation.
# RDS manage_master_user_password (in rds.tf) already creates a
# Secrets-Manager-managed master secret encrypted with our CMK and rotates
# it on an AWS-managed schedule. We surface its ARN and document the choice.
#
# This satisfies: "runtime secrets in Secrets Manager with documented
# rotation; secrets in env/code/state are not acceptable." The app will read
# this secret at runtime (wired in the compute module on Day 11).
# =====================================================================

# The managed master-user secret created by RDS (see manage_master_user_password).
# Exposed as data so other modules/outputs can reference its ARN.
locals {
  # RDS returns the managed secret as a nested attribute once created.
  db_master_secret_arn = try(aws_db_instance.main.master_user_secret[0].secret_arn, null)
}

# A separate application secret could hold a non-admin DB user; for Day 10 we
# document that the rotation requirement is met by the RDS-managed master
# secret above. A dedicated app-user secret with a rotation Lambda is a
# defensible Day 11/extension addition (noted in the ADR).
