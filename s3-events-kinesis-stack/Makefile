tf-apply:
	aws-vault exec tf-admin --no-session -- terraform apply -auto-approve

upload:
	aws-vault exec tf-admin --no-session -- aws s3 rm s3://zhong-inbound-files/events/example-event.json
	aws-vault exec tf-admin --no-session -- aws s3 cp example-event.json s3://zhong-inbound-files/events/
