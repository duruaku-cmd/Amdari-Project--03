# SentinelPay OPA policy pack — developer experience.
.PHONY: test verify demo

test:        ## Run policies against a generated plan.json
	conftest test --policy policy plan.json

verify:      ## Run the Rego unit tests
	conftest verify --policy policy

demo:        ## Show a failing and a passing example
	-conftest test --policy policy fixtures/bad_plan.json
	conftest test --policy policy fixtures/good_plan.json
