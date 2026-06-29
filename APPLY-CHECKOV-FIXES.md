# Apply Checkov Fixes — Exact Steps (clears the 25 remaining)

This wires your customer-managed KMS key into the modules that need it and adds
the missing encryption/retention/lifecycle/logging. Apply in order, then
`terraform validate`, then push.

## KEY INSIGHT (why this is structured this way)
- `observability` ALREADY receives `var.kms_key_arn` (it's wired in main.tf) — so
  cloudtrail/containment/honeytoken just USE it, no plumbing needed.
- `compute` does NOT receive the key yet — add the variable + pass it in main.tf.
- `network` is created BEFORE `data`, so it CANNOT use data's key (cycle). It gets
  its OWN small KMS key (new file network/kms.tf).
- The `config` bucket findings are on a resource with count=0 (gated off) — skipped.

---

## STEP 1 — compute module (KMS on ECS log groups)
1a. In `modules/compute/ecs.tf`, replace the two `aws_cloudwatch_log_group`
    blocks (payments, kyc) with the versions in `01_compute_ecs_loggroups.tf`.
1b. Add the variable from `02_compute_variables_add.tf` to
    `modules/compute/variables.tf`.
1c. In `infra/main.tf`, add ONE line to the `module "compute"` block:
        kms_key_arn = module.data.kms_key_arn
    (see 03_main_compute_call.tf)

## STEP 2 — network module (own KMS key + flow log + default SG)
2a. Create new file `modules/network/kms.tf` from `04_network_kms_and_fixes.tf`
    (the aws_kms_key.network + alias + the data sources).
2b. Add `data "aws_region" "current" {}` to network (if not already present).
2c. In `modules/network/main.tf`, replace the `aws_cloudwatch_log_group.flow`
    block and ADD the `aws_default_security_group.default` resource — both in
    `05_network_flowlog_and_defaultsg.tf`.

## STEP 3 — observability module (uses existing var.kms_key_arn)
3a. cloudtrail.tf: replace `aws_cloudwatch_log_group.trail` + add the trail
    bucket lifecycle — `06_observability_cloudtrail.tf`.
3b. containment.tf: replace `aws_cloudwatch_log_group.containment` —
    `07_observability_containment.tf`.
3c. honeytoken.tf: add `key_id = var.kms_key_arn` to both SSM params —
    `08_observability_honeytoken.tf`.

## STEP 4 — data module (S3 lifecycle)
4a. Add the two lifecycle blocks from `09_data_s3_lifecycle.tf` to
    `modules/data/s3.tf`.

## STEP 5 — compute WAF (logging + Log4j)
5a. Add the WAF log group + logging config from `10_compute_waf.tf` to
    `modules/compute/waf.tf`. Ensure KnownBadInputs managed rule is present
    (see the commented block) for CKV2_AWS_76.

## STEP 6 — skips (already in the new .checkov.yaml, but confirm)
The updated `.checkov.yaml` (35 skips) adds: CKV_AWS_91, CKV_AWS_18, CKV_AWS_21,
CKV_AWS_145 — all justified (no log-target bucket in lab; config bucket gated off;
log-target buckets use AES256 by design).

---

## STEP 7 — validate locally, then push
```
cd infra
terraform fmt -recursive
terraform init -upgrade
terraform validate     # MUST say "Success!" before pushing
cd ..
git add infra .checkov.yaml
git commit -m "Day 17: wire KMS into compute/network, encrypt log groups + SSM, S3 lifecycle, WAF logging - clear Checkov"
git push origin main
```

If `terraform validate` errors, paste the error — do NOT push a broken plan.
