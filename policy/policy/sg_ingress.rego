# Policy: No 0.0.0.0/0 ingress except the ALB on 80/443.
# Defends V-CLD-01 / C-05 (flat network, world-open ports). Any security group
# rule open to the internet is denied unless it belongs to the ALB SG and is
# restricted to the standard web ports.
package sentinelpay.network

import rego.v1

# Inline ingress blocks on aws_security_group.
deny contains msg if {
	some r in input.resource_changes
	r.type == "aws_security_group"
	some ingress in object.get(r.change.after, "ingress", [])
	"0.0.0.0/0" in object.get(ingress, "cidr_blocks", [])
	not is_alb_web_rule(r, ingress)
	msg := sprintf(
		"OPEN INGRESS: '%s' allows 0.0.0.0/0 on ports %d-%d. World-open ingress is only permitted on the ALB security group for 80/443 (principle: no compute is internet-addressable; only the edge load balancer faces the internet).",
		[r.address, ingress.from_port, ingress.to_port],
	)
}

# Standalone aws_security_group_rule resources.
deny contains msg if {
	some r in input.resource_changes
	r.type == "aws_security_group_rule"
	after := r.change.after
	after.type == "ingress"
	"0.0.0.0/0" in object.get(after, "cidr_blocks", [])
	not is_alb_web_port(after.from_port, after.to_port)
	msg := sprintf(
		"OPEN INGRESS: '%s' allows 0.0.0.0/0 on ports %d-%d, which is not an ALB web port (80/443).",
		[r.address, after.from_port, after.to_port],
	)
}

# An ALB rule is acceptable when it is the ALB SG and the port is 80 or 443.
is_alb_web_rule(r, ingress) if {
	contains(r.address, "alb")
	is_alb_web_port(ingress.from_port, ingress.to_port)
}

is_alb_web_port(from, to) if {
	from == to
	from in {80, 443}
}
