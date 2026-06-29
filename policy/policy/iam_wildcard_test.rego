package sentinelpay.iam

import rego.v1

test_scoped_policy_passes if {
	count(deny) == 0 with input as {"resource_changes": [{
		"address": "aws_iam_role_policy.scoped",
		"type": "aws_iam_role_policy",
		"change": {"after": {"policy": "{\"Statement\":[{\"Effect\":\"Allow\",\"Action\":[\"s3:GetObject\"],\"Resource\":\"*\"}]}"}},
	}]}
}

test_wildcard_policy_denied if {
	count(deny) == 1 with input as {"resource_changes": [{
		"address": "aws_iam_role_policy.god",
		"type": "aws_iam_role_policy",
		"change": {"after": {"policy": "{\"Statement\":[{\"Effect\":\"Allow\",\"Action\":\"*\",\"Resource\":\"*\"}]}"}},
	}]}
}
