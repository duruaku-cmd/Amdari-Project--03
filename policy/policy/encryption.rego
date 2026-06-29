# Policy: Encryption at rest is mandatory.
# Defends V-CLD-02. RDS instances must have storage_encrypted = true; S3 buckets
# must have a server-side encryption configuration; ElastiCache replication
# groups must have at_rest_encryption_enabled = true.
package sentinelpay.encryption

import rego.v1

# RDS must be encrypted.
deny contains msg if {
	some r in input.resource_changes
	r.type == "aws_db_instance"
	object.get(r.change.after, "storage_encrypted", false) != true
	msg := sprintf(
		"UNENCRYPTED RDS: '%s' must set storage_encrypted = true with a customer-managed KMS key (principle: all data at rest is encrypted).",
		[r.address],
	)
}

# ElastiCache must be encrypted at rest.
deny contains msg if {
	some r in input.resource_changes
	r.type == "aws_elasticache_replication_group"
	object.get(r.change.after, "at_rest_encryption_enabled", false) != true
	msg := sprintf(
		"UNENCRYPTED CACHE: '%s' must set at_rest_encryption_enabled = true.",
		[r.address],
	)
}

# Every S3 bucket in the plan must have a matching SSE configuration resource.
deny contains msg if {
	some bucket in input.resource_changes
	bucket.type == "aws_s3_bucket"
	bucket_addr := bucket.address
	not has_sse_config(bucket_addr)
	msg := sprintf(
		"UNENCRYPTED S3: bucket '%s' has no aws_s3_bucket_server_side_encryption_configuration. Default encryption is mandatory.",
		[bucket_addr],
	)
}

# True if some SSE config resource references the same bucket label.
has_sse_config(bucket_addr) if {
	some r in input.resource_changes
	r.type == "aws_s3_bucket_server_side_encryption_configuration"
	# match on the resource label (text after the last '.')
	bucket_label(r.address) == bucket_label(bucket_addr)
}

bucket_label(addr) := label if {
	parts := split(addr, ".")
	label := parts[count(parts) - 1]
}
