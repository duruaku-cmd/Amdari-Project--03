# Policy: No IAM wildcard-on-wildcard in customer-managed policies.
# The brief's hard rule: no policy may grant Action "*" on Resource "*".
package sentinelpay.iam

import rego.v1

# aws_iam_policy and aws_iam_role_policy carry a JSON "policy" document.
policy_resources := {"aws_iam_policy", "aws_iam_role_policy", "aws_iam_user_policy", "aws_iam_group_policy"}

deny contains msg if {
	some r in input.resource_changes
	r.type in policy_resources
	doc := json.unmarshal(r.change.after.policy)
	some stmt in as_array(doc.Statement)
	stmt.Effect == "Allow"
	has_wildcard(stmt.Action)
	has_wildcard(stmt.Resource)
	msg := sprintf(
		"IAM WILDCARD: '%s' grants Action '*' on Resource '*'. Every policy must scope at least one dimension (principle: least privilege, no god-mode policies).",
		[r.address],
	)
}

# Action/Resource may be a string or a list; normalise to a set and test for "*".
has_wildcard(field) if field == "*"

has_wildcard(field) if {
	is_array(field)
	"*" in field
}

as_array(x) := x if is_array(x)

as_array(x) := [x] if not is_array(x)
