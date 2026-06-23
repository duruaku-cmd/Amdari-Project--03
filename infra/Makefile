# Developer experience for the SentinelPay infra root (D-04 quality bar).
# Usage: make init | make fmt | make validate | make plan | make apply | make destroy

TF := terraform

.PHONY: init fmt validate plan apply destroy

init:        ## Initialise providers and the S3 remote backend
	$(TF) init

fmt:         ## Format all Terraform files in place
	$(TF) fmt -recursive

validate:    ## Validate configuration syntax and internal consistency
	$(TF) validate

plan:        ## Show what would change (safe, read-only)
	$(TF) plan -out=tfplan

apply:       ## Apply the saved plan
	$(TF) apply tfplan

destroy:     ## Tear down everything (use with care)
	$(TF) destroy
