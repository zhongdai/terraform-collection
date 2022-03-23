.PHONY: help
help:
	@cat $(MAKEFILE_LIST) | grep -e "^[a-zA-Z_\-]*: *.*## *" | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: tf-plan
tf-plan: ## plan the terraform without approval
	aws-vault exec tf-admin --no-session -- terraform plan

.PHONY: tf-apply
tf-apply: ## apply the terraform without approval
	aws-vault exec tf-admin --no-session -- terraform apply -auto-approve

.PHONY: login
login: ## connect to the postgres just created
	psql -h $(terraform output -raw rds_hostname) -p $(terraform output -raw rds_port) -U $(terraform output -raw rds_username) postgres
