# see envs.app.makefile for default starting values

# env type we are deploying to, gets appended to most names and stack
par-dev-%: export STACK_ENV = dev

# deployment region
par-dev-%: export AWS_ACCOUNT = 111111111111
par-dev-%: export AWS_DEFAULT_REGION = us-east-1
par-dev-%: export AWS_REGION = $(AWS_DEFAULT_REGION)

# iac state
par-dev-%: export IAC_BUCKET = paul-robello-aws-sb-iac-state-$(AWS_REGION)
par-dev-%: export BUCKET_NAME = par-pdf-ingestion-$(STACK_ENV)-$(AWS_REGION)


# used for private lambda deployment
par-dev-%: export VPC_ID = vpc-1111111111111111
par-dev-%: export VPC_SUBNET_IDS = ["subnet-11111111111111111","subnet-22222222222222222","subnet-33333333333333333"]
par-dev-%: export VPC_SG_IDS = ["sg-11111111111111111"]


par-dev-%: export LOGGING_RETENTION_DAYS = 3

# prefix needed targets from top level Makefile so proper env vars are set before invocation
par-dev-make-tf-vars: make-tf-vars
par-dev-all: all
par-dev-clean: clean
par-dev-stack-init: stack-init
par-dev-refresh: refresh
par-dev-dump-outputs: dump-outputs
par-dev-deploy: deploy
par-dev-plan: plan
par-dev-destroy: destroy
par-dev-build: build
par-dev-it-again: it-again

par-dev-list-log-groups: list-log-groups

par-dev-gen-plan-json: gen-plan-json

par-dev-list-bucket: list-bucket
par-dev-list-inbox: list-inbox
par-dev-list-outbox: list-outbox

par-dev-upload-pdf: upload-pdf
par-dev-delete-pdf: delete-pdf
