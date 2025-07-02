# Since we've deleted variables.tf but still need a few parameters for each Lambda function,
# declare the necessary variables inline
variable "environment" {
  default = "dev"
}

variable "lambda_name" {
  description = "Name of the Lambda function"
}

variable "handler" {
  description = "Lambda function handler"
  default = "index.lambda_handler"
}

variable "timeout" {
  description = "Lambda function timeout in seconds"
  default = 120
}

variable "memory_size" {
  description = "Lambda function memory size in MB"
  default = 128
}

variable "policy_json" {
  description = "IAM policy JSON for the Lambda function"
}

variable "environment_variables" {
  description = "Environment variables for the Lambda function"
  type = map(string)
}

variable "schedule_expression" {
  description = "CloudWatch Events schedule expression"
  default = null
}

# Note: This is a template file that would need specific values for each Lambda function
# Since we have 3 different Lambda functions using this module, we'll keep some module functionality
# but hardcode the general configuration values

# IAM role for Lambda execution
resource "aws_iam_role" "lambda_exec_role" {
  name = "${var.environment}-${var.lambda_name}-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Policy for Lambda execution
resource "aws_iam_policy" "lambda_policy" {
  name        = "${var.environment}-${var.lambda_name}-policy"
  description = "Policy for ${var.lambda_name} Lambda function"

  policy = var.policy_json  # This will vary for each Lambda function, so we keep as a parameter
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# Basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# VPC access policy
resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Lambda function
resource "aws_lambda_function" "lambda_function" {
  function_name    = "${var.environment}-${var.lambda_name}"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = var.handler
  runtime          = "python3.9"
  filename         = "${path.module}/files/${var.lambda_name}.zip"
  source_code_hash = filebase64sha256("${path.module}/files/${var.lambda_name}.zip")
  timeout          = var.timeout
  memory_size      = var.memory_size
  
  environment {
    variables = var.environment_variables  # Each Lambda has different env vars, so we keep as parameter
  }

  vpc_config {
    subnet_ids         = ["subnet-0123456789abcdef4", "subnet-0123456789abcdef5", "subnet-0123456789abcdef6"]
    security_group_ids = ["sg-0123456789abcdef0"]
  }

  tags = {
    Name        = "dev-${var.lambda_name}"
    Environment = "dev"
  }
}

# CloudWatch Event Rule for scheduling (if enabled)
resource "aws_cloudwatch_event_rule" "lambda_schedule" {
  count               = var.schedule_expression != null ? 1 : 0
  name                = "dev-${var.lambda_name}-schedule"
  description         = "Schedule for ${var.lambda_name} Lambda function"
  schedule_expression = var.schedule_expression
}

# CloudWatch Event Target for scheduling
resource "aws_cloudwatch_event_target" "lambda_target" {
  count     = var.schedule_expression != null ? 1 : 0
  rule      = aws_cloudwatch_event_rule.lambda_schedule[0].name
  target_id = "dev-${var.lambda_name}"
  arn       = aws_lambda_function.lambda_function.arn
}

# Permission for CloudWatch to invoke Lambda
resource "aws_lambda_permission" "allow_cloudwatch" {
  count         = var.schedule_expression != null ? 1 : 0
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda_schedule[0].arn
} 