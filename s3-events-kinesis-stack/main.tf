terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }

  required_version = "~> 1.0"
}

provider "aws" {
  region = var.aws_region
}

# zip lambda files
data "archive_file" "lambda-producer" {
  type        = "zip"
  source_dir  = "${path.module}/producer"
  output_path = "${path.module}/producer.zip"
}

data "archive_file" "lambda-consumer-realtime" {
  type        = "zip"
  source_dir  = "${path.module}/consumer-realtime"
  output_path = "${path.module}/consumer-realtime.zip"
}

data "archive_file" "lambda-consumer-archive" {
  type        = "zip"
  source_dir  = "${path.module}/consumer-archive"
  output_path = "${path.module}/consumer-archive.zip"
}

# Get the policy by name
data "aws_iam_policy" "s3" {
  name = "AmazonS3FullAccess"
}

data "aws_iam_policy" "cloud-watch" {
  name = "CloudWatchFullAccess"
}

data "aws_iam_policy" "kinesis" {
  name = "AmazonKinesisFullAccess"
}


# Create the role
resource "aws_iam_role" "data-stream-system-role" {
  name = "data-stream-system-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  tags = {
    managed_by = "terraform"
  }
}


# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "attach-s3" {
  role       = aws_iam_role.data-stream-system-role.name
  policy_arn = data.aws_iam_policy.s3.arn
}

resource "aws_iam_role_policy_attachment" "attach-cloud-watch" {
  role       = aws_iam_role.data-stream-system-role.name
  policy_arn = data.aws_iam_policy.cloud-watch.arn
}

resource "aws_iam_role_policy_attachment" "attach-kinesis" {
  role       = aws_iam_role.data-stream-system-role.name
  policy_arn = data.aws_iam_policy.kinesis.arn
}

# S3 bucket
resource "aws_s3_bucket" "inbound-bucket" {
  bucket = "zhong-inbound-files"
}


# lambda function
resource "aws_lambda_function" "producer" {
  function_name = "producer"
  filename      = "producer.zip"

  runtime = "nodejs14.x"
  handler = "index.handler"

  source_code_hash = data.archive_file.lambda-producer.output_base64sha256

  role = aws_iam_role.data-stream-system-role.arn
}

resource "aws_lambda_function" "consumer-realtime" {
  function_name = "consumer-realtime"
  filename      = "consumer-realtime.zip"

  runtime = "nodejs14.x"
  handler = "index.handler"

  source_code_hash = data.archive_file.lambda-consumer-realtime.output_base64sha256

  role = aws_iam_role.data-stream-system-role.arn
}

resource "aws_lambda_event_source_mapping" "source-mapping-realtime" {
  event_source_arn  = aws_kinesis_stream.json-data-stream.arn
  function_name     = aws_lambda_function.consumer-realtime.arn
  starting_position = "LATEST"
}

resource "aws_lambda_permission" "allow-kinesis-consumer-realtime" {
  statement_id  = "AllowExecutionFromKinesis"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.consumer-realtime.arn
  principal     = "kinesis.amazonaws.com"
  source_arn    = aws_kinesis_stream.json-data-stream.arn
}

resource "aws_lambda_function" "consumer-archive" {
  function_name = "consumer-archive"
  filename      = "consumer-archive.zip"

  runtime = "nodejs14.x"
  handler = "index.handler"

  source_code_hash = data.archive_file.lambda-consumer-archive.output_base64sha256

  role = aws_iam_role.data-stream-system-role.arn
}

resource "aws_lambda_event_source_mapping" "source-mapping-archive" {
  event_source_arn  = aws_kinesis_stream.json-data-stream.arn
  function_name     = aws_lambda_function.consumer-archive.arn
  starting_position = "LATEST"
}

resource "aws_lambda_permission" "allow-kinesis-consumer-archive" {
  statement_id  = "AllowExecutionFromKinesis"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.consumer-archive.arn
  principal     = "kinesis.amazonaws.com"
  source_arn    = aws_kinesis_stream.json-data-stream.arn
}

# bucket permission to invoke lambda
resource "aws_lambda_permission" "allow-bucket-producer" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.producer.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.inbound-bucket.arn
}

resource "aws_s3_bucket_notification" "bucket-notification-producer" {
  bucket = aws_s3_bucket.inbound-bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.producer.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "events/"
    filter_suffix       = ".json"
  }
  depends_on = [aws_lambda_permission.allow-bucket-producer]
}

# stream
resource "aws_kinesis_stream" "json-data-stream" {
  name             = "json-data-stream"
  shard_count      = 2
  retention_period = 48
}
