BUCKET = zhong-inbound-files


.PHONY: help
help:
	@cat $(MAKEFILE_LIST) | grep -e "^[a-zA-Z_\-]*: *.*## *" | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: tf-plan
tf-plan: ## plan the terraform without approval
	aws-vault exec tf-admin --no-session -- terraform plan

.PHONY: tf-apply
tf-apply: ## apply the terraform without approval
	aws-vault exec tf-admin --no-session -- terraform apply -auto-approve

.PHONY: upload
upload: ## upload the example file for testing purpose
	aws-vault exec tf-admin --no-session -- aws s3 rm s3://$(BUCKET)/events/example-event.json
	aws-vault exec tf-admin --no-session -- aws s3 cp example-event.json s3://$(BUCKET)/events/

.PHONY: clean
clean: ## remove the zip files
	rm -rf s3-events-kinesis-stack/*.zip
