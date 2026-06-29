# Day 17 Checkov — COMPLETE FILES (overwrite, don't merge)

These are FULL files. OVERWRITE your existing files with them — no copying snippets
into the middle of blocks. That's what caused the earlier edits not to land.

## Files to OVERWRITE (replace entire file)
| Tarball file | Replaces |
| --- | --- |
| compute/ecs.tf            | infra/modules/compute/ecs.tf |
| compute/waf.tf            | infra/modules/compute/waf.tf |
| network/main.tf           | infra/modules/network/main.tf |
| observability/cloudtrail.tf   | infra/modules/observability/cloudtrail.tf |
| observability/containment.tf  | infra/modules/observability/containment.tf |
| observability/honeytoken.tf   | infra/modules/observability/honeytoken.tf |
| data/s3.tf                | infra/modules/data/s3.tf |
| .checkov.yaml             | .checkov.yaml (repo root) |

## NEW file to ADD
| Tarball file | Add as |
| --- | --- |
| network/kms.tf | infra/modules/network/kms.tf  (NEW — network's own KMS key) |

## ONE manual edit (variable) — compute/variables.tf
Append this to `infra/modules/compute/variables.tf` (from compute/variables_ADD.txt):

    variable "kms_key_arn" {
      description = "Customer-managed KMS key ARN for encrypting CloudWatch log groups."
      type        = string
    }

(main.tf already passes `kms_key_arn = module.data.kms_key_arn` to compute — you
confirmed line 68 — so once the variable exists, it wires up.)

## Apply
```powershell
cd "C:\Users\Emmanuel Duruaku\Amdari-Project--03\infra"
terraform fmt -recursive
terraform init -upgrade
terraform validate      # MUST say Success! before pushing
cd ..
git add infra .checkov.yaml
git commit -m "Day 17: KMS-encrypt log groups + SSM, S3 lifecycle, WAF logging, default-SG lockdown, network CMK - clear Checkov"
git push origin main
```

## Expected result
Checkov GREEN. Real fixes resolve CKV_AWS_158/338/337, CKV2_AWS_12/31/76, and the
kyc/trail lifecycle. CKV_AWS_145 + CKV2_AWS_61 remain skipped (gated config bucket +
by-design AES256 log bucket), documented in .checkov.yaml.

## If terraform validate errors
Paste me the error. Do NOT push a broken plan. Most likely cause would be a
duplicate data source (e.g. if cloudtrail.tf and another observability file both
declare data.aws_region.current — they're in the SAME module, so only ONE may
declare it). If validate complains about a duplicate, tell me which and I'll remove
the dupe.
