# Policy: No public S3 buckets.
# Defends V-CLD-03 (public KYC bucket). A bucket is a violation if it has a
# public-access-block resource that does not set all four protections to true,
# or if any public ACL is requested.
package sentinelpay.s3

import rego.v1

deny contains msg if {
	some r in input.resource_changes
	r.type == "aws_s3_bucket_public_access_block"
	change := r.change.after
	not all_blocks_true(change)
	msg := sprintf(
		"S3 PUBLIC ACCESS: '%s' must set block_public_acls, block_public_policy, ignore_public_acls, and restrict_public_buckets all to true (principle: data buckets must never be publicly reachable).",
		[r.address],
	)
}

all_blocks_true(change) if {
	change.block_public_acls == true
	change.block_public_policy == true
	change.ignore_public_acls == true
	change.restrict_public_buckets == true
}

deny contains msg if {
	some r in input.resource_changes
	r.type == "aws_s3_bucket_acl"
	acl := r.change.after.acl
	acl in {"public-read", "public-read-write", "authenticated-read"}
	msg := sprintf(
		"S3 PUBLIC ACL: '%s' requests a public ACL ('%s'). Public ACLs on SentinelPay buckets are forbidden.",
		[r.address, acl],
	)
}
