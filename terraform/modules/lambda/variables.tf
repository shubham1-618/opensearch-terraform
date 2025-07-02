variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "lambda_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "lambda_source_path" {
  description = "Path to the Lambda function source code"
  type        = string
}

variable "handler" {
  description = "Lambda function handler"
  type        = string
  default     = "index.lambda_handler"
}

variable "runtime" {
  description = "Lambda function runtime"
  type        = string
  default     = "python3.9"
}

variable "timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 60
}

variable "memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 128
}

variable "policy_json" {
  description = "JSON policy for Lambda execution role"
  type        = string
}

variable "environment_variables" {
  description = "Environment variables for Lambda function"
  type        = map(string)
  default     = {}
}

variable "vpc_config" {
  description = "VPC configuration for Lambda function"
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null
}

variable "schedule_expression" {
  description = "CloudWatch Events schedule expression for Lambda function"
  type        = string
  default     = null
}

variable "max_retries" {
  description = "Maximum number of retries for Lambda operations"
  type        = number
  default     = 3
}

variable "retry_delay" {
  description = "Delay in seconds between retry attempts"
  type        = number
  default     = 5
}

variable "log_retention_days" {
  description = "Number of days to retain Lambda logs"
  type        = number
  default     = 14
}

variable "create_function_url" {
  description = "Whether to create a function URL for the Lambda"
  type        = bool
  default     = false
}

variable "create_error_alarm" {
  description = "Whether to create CloudWatch alarm for Lambda errors"
  type        = bool
  default     = false
}

variable "create_log_group" {
  description = "Whether to create CloudWatch Log Group for the Lambda function (set to false if it already exists)"
  type        = bool
  default     = true
} 