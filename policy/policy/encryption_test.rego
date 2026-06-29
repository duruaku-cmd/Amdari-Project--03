package sentinelpay.encryption

import rego.v1

test_encrypted_rds_passes if {
	count(deny) == 0 with input as {"resource_changes": [{
		"address": "aws_db_instance.main",
		"type": "aws_db_instance",
		"change": {"after": {"storage_encrypted": true}},
	}]}
}

test_unencrypted_rds_denied if {
	count(deny) == 1 with input as {"resource_changes": [{
		"address": "aws_db_instance.bad",
		"type": "aws_db_instance",
		"change": {"after": {"storage_encrypted": false}},
	}]}
}

# A bucket with a matching SSE config => allowed.
test_bucket_with_sse_passes if {
	count(deny) == 0 with input as {"resource_changes": [
		{
			"address": "aws_s3_bucket.kyc",
			"type": "aws_s3_bucket",
			"change": {"after": {}},
		},
		{
			"address": "aws_s3_bucket_server_side_encryption_configuration.kyc",
			"type": "aws_s3_bucket_server_side_encryption_configuration",
			"change": {"after": {}},
		},
	]}
}

# A bucket with NO SSE config => denied.
test_bucket_without_sse_denied if {
	count(deny) == 1 with input as {"resource_changes": [{
		"address": "aws_s3_bucket.naked",
		"type": "aws_s3_bucket",
		"change": {"after": {}},
	}]}
}
