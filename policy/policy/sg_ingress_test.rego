package sentinelpay.network

import rego.v1

# ALB on 443 open to the world => allowed.
test_alb_443_passes if {
	count(deny) == 0 with input as {"resource_changes": [{
		"address": "aws_security_group.alb",
		"type": "aws_security_group",
		"change": {"after": {"ingress": [{
			"from_port": 443, "to_port": 443, "cidr_blocks": ["0.0.0.0/0"],
		}]}},
	}]}
}

# App SG open to the world on 8001 => denied.
test_app_open_denied if {
	count(deny) == 1 with input as {"resource_changes": [{
		"address": "aws_security_group.app",
		"type": "aws_security_group",
		"change": {"after": {"ingress": [{
			"from_port": 8001, "to_port": 8001, "cidr_blocks": ["0.0.0.0/0"],
		}]}},
	}]}
}

# DB rule open to the world on 5432 => denied.
test_db_rule_open_denied if {
	count(deny) == 1 with input as {"resource_changes": [{
		"address": "aws_security_group_rule.db_world",
		"type": "aws_security_group_rule",
		"change": {"after": {
			"type": "ingress", "from_port": 5432, "to_port": 5432,
			"cidr_blocks": ["0.0.0.0/0"],
		}},
	}]}
}
