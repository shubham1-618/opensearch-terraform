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
  
  # Error handling for IAM role
  lifecycle {
    create_before_destroy = true
  }
}

# Policy for Lambda execution
resource "aws_iam_policy" "lambda_policy" {
  name        = "${var.environment}-${var.lambda_name}-policy"
  description = "Policy for ${var.lambda_name} Lambda function"

  policy = var.policy_json
  
  # Error handling for IAM policy
  lifecycle {
    create_before_destroy = true
  }
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

# VPC access policy (if needed)
resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  count      = var.vpc_config != null ? 1 : 0
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# CloudWatch Log group with explicit retention - use data source if it exists, create if it doesn't
data "aws_cloudwatch_log_group" "existing_logs" {
  count = var.create_log_group ? 0 : 1
  name  = "/aws/lambda/${var.environment}-${var.lambda_name}"
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  count             = var.create_log_group ? 1 : 0
  name              = "/aws/lambda/${var.environment}-${var.lambda_name}"
  retention_in_days = var.log_retention_days
}

# Lambda function
resource "aws_lambda_function" "lambda_function" {
  function_name    = "${var.environment}-${var.lambda_name}"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = var.handler
  runtime          = var.runtime
  filename         = "${path.module}/files/${var.lambda_name}.zip"
  source_code_hash = filebase64sha256("${path.module}/files/${var.lambda_name}.zip")
  timeout          = var.timeout
  memory_size      = var.memory_size
  
  environment {
    variables = merge(var.environment_variables, {
      MAX_RETRIES = tostring(var.max_retries)
      RETRY_DELAY = tostring(var.retry_delay)
    })
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  tags = {
    Name        = "${var.environment}-${var.lambda_name}"
    Environment = var.environment
  }

  # Use static depends_on list, the log group creation is already conditional via count
  depends_on = [aws_cloudwatch_log_group.lambda_logs]
  
  # Set timeouts to handle slow deployments
  timeouts {
    create = "10m"
  }
}

# Function URL (if enabled)
resource "aws_lambda_function_url" "lambda_url" {
  count              = var.create_function_url ? 1 : 0
  function_name      = aws_lambda_function.lambda_function.function_name
  authorization_type = "NONE"
  
  cors {
    allow_origins = ["*"]
    allow_methods = ["*"]
    allow_headers = ["*"]
  }
}

# CloudWatch alarm for Lambda errors
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  count               = var.create_error_alarm ? 1 : 0
  alarm_name          = "${var.environment}-${var.lambda_name}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "60"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors ${var.lambda_name} Lambda function errors"
  
  dimensions = {
    FunctionName = aws_lambda_function.lambda_function.function_name
  }
}

# CloudWatch Event Rule for scheduling (if enabled)
resource "aws_cloudwatch_event_rule" "lambda_schedule" {
  count               = var.schedule_expression != null ? 1 : 0
  name                = "${var.environment}-${var.lambda_name}-schedule"
  description         = "Schedule for ${var.lambda_name} Lambda function"
  schedule_expression = var.schedule_expression
}

# CloudWatch Event Target for scheduling
resource "aws_cloudwatch_event_target" "lambda_target" {
  count     = var.schedule_expression != null ? 1 : 0
  rule      = aws_cloudwatch_event_rule.lambda_schedule[0].name
  target_id = "${var.environment}-${var.lambda_name}"
  arn       = aws_lambda_function.lambda_function.arn
  
  # Add retry policy for scheduled events
  retry_policy {
    maximum_event_age_in_seconds = 60
    maximum_retry_attempts       = 2
  }
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