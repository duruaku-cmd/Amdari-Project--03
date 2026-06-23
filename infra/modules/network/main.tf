# =====================================================================
# MODULE: network  (Day 9)
# A segmented VPC: public + private subnets across >= 2 AZs, with
# VPC Flow Logs (closes V-CLD-08). Replaces the "flat VPC" the red
# team found (challenge C-05).
# =====================================================================

locals {
  module_name = "network"
  # Pick the first az_count AZs available in the region.
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # How many NAT gateways to create, derived from the chosen strategy.
  nat_count = var.nat_strategy == "none" ? 0 : (var.nat_strategy == "per_az" ? var.az_count : 1)

  # Carve the VPC /16 into /20 subnets. Public subnets first, then private.
  public_subnet_cidrs  = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i)]
  private_subnet_cidrs = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i + 8)]
}

data "aws_availability_zones" "available" {
  state = "available"
}

# ---------------- VPC ----------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${var.name_prefix}-vpc" }
}

# ---------------- Internet Gateway (for public subnets only) ----------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.name_prefix}-igw" }
}

# ---------------- Public subnets ----------------
resource "aws_subnet" "public" {
  count                   = var.az_count
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.name_prefix}-public-${local.azs[count.index]}"
    Tier = "public"
  }
}

# ---------------- Private subnets (where app compute lives) ----------------
resource "aws_subnet" "private" {
  count             = var.az_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]
  # NOTE: no public IP. These are unreachable from the internet by design.
  tags = {
    Name = "${var.name_prefix}-private-${local.azs[count.index]}"
    Tier = "private"
  }
}

# ---------------- Public route table: route to the internet ----------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "${var.name_prefix}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = var.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ---------------- NAT Gateways (outbound-only for private subnets) ----------------
# Elastic IPs, one per NAT gateway.
resource "aws_eip" "nat" {
  count  = local.nat_count
  domain = "vpc"
  tags   = { Name = "${var.name_prefix}-nat-eip-${count.index}" }
}

resource "aws_nat_gateway" "main" {
  count         = local.nat_count
  allocation_id = aws_eip.nat[count.index].id
  # Place NAT in a public subnet (it needs the internet gateway).
  subnet_id  = aws_subnet.public[count.index].id
  tags       = { Name = "${var.name_prefix}-nat-${count.index}" }
  depends_on = [aws_internet_gateway.main]
}

# ---------------- Private route tables ----------------
# One private route table per AZ so each can point at its own/nearest NAT.
resource "aws_route_table" "private" {
  count  = var.az_count
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.name_prefix}-private-rt-${local.azs[count.index]}" }
}

# Add a default route through NAT only when NAT exists.
resource "aws_route" "private_nat" {
  count                  = local.nat_count == 0 ? 0 : var.az_count
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  # If single NAT, every private RT uses NAT[0]; if per_az, use the matching one.
  nat_gateway_id = var.nat_strategy == "per_az" ? aws_nat_gateway.main[count.index].id : aws_nat_gateway.main[0].id
}

resource "aws_route_table_association" "private" {
  count          = var.az_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# ---------------- VPC Flow Logs (closes V-CLD-08) ----------------
resource "aws_cloudwatch_log_group" "flow" {
  name              = "/sentinelpay/${var.name_prefix}/vpc-flow-logs"
  retention_in_days = var.flow_log_retention_days
}

# Role that lets the VPC Flow Logs service write to CloudWatch.
data "aws_iam_policy_document" "flow_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "flow" {
  name               = "${var.name_prefix}-vpc-flow-logs"
  assume_role_policy = data.aws_iam_policy_document.flow_assume.json
}

# Scoped policy: write logs to THIS log group only. No wildcard-on-wildcard.
data "aws_iam_policy_document" "flow_write" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = ["${aws_cloudwatch_log_group.flow.arn}:*"]
  }
}

resource "aws_iam_role_policy" "flow" {
  name   = "${var.name_prefix}-vpc-flow-logs-write"
  role   = aws_iam_role.flow.id
  policy = data.aws_iam_policy_document.flow_write.json
}

resource "aws_flow_log" "main" {
  vpc_id          = aws_vpc.main.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow.arn
  log_destination = aws_cloudwatch_log_group.flow.arn
  tags            = { Name = "${var.name_prefix}-flow-log" }
}
