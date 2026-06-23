# Root outputs are surfaced from module outputs as the modules get built out.
# Empty on Day 8 by design; populated from Day 9 onward.
output "name_prefix" {
  description = "The common name prefix for this environment."
  value       = local.name_prefix
}
