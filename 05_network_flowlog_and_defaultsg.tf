# In modules/network/main.tf:

# (a) REPLACE the aws_cloudwatch_log_group.flow block with:
resource "aws_cloudwatch_log_group" "flow" {
  name              = "/sentinelpay/${var.name_prefix}/vpc-flow-logs"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.network.arn
}

# (b) ADD this new resource anywhere in modules/network/main.tf
#     (CKV2_AWS_12: lock the VPC's default security group to deny all):
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id
  # No ingress and no egress rules = the default SG denies all traffic.
  tags = { Name = "${var.name_prefix}-default-sg-locked" }
}
