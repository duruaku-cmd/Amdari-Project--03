package sentinelpay.s3

import rego.v1

# A fully-locked public access block => no denials.
test_locked_bucket_passes if {
	count(deny) == 0 with input as {"resource_changes": [{
		"address": "aws_s3_bucket_public_access_block.kyc",
		"type": "aws_s3_bucket_public_access_block",
		"change": {"after": {
			"block_public_acls": true,
			"block_public_policy": true,
			"ignore_public_acls": true,
			"restrict_public_buckets": true,
		}},
	}]}
}

# A partially-open block => one denial.
test_open_block_denied if {
	count(deny) == 1 with input as {"resource_changes": [{
		"address": "aws_s3_bucket_public_access_block.bad",
		"type": "aws_s3_bucket_public_access_block",
		"change": {"after": {
			"block_public_acls": false,
			"block_public_policy": true,
			"ignore_public_acls": true,
			"restrict_public_buckets": true,
		}},
	}]}
}

# A public ACL => one denial.
test_public_acl_denied if {
	count(deny) == 1 with input as {"resource_changes": [{
		"address": "aws_s3_bucket_acl.bad",
		"type": "aws_s3_bucket_acl",
		"change": {"after": {"acl": "public-read"}},
	}]}
}
