locals {
  queue_names = keys(var.queue_max_age_seconds)

  widget_queues = {
    type   = "metric"
    width  = 12
    height = 6
    properties = {
      title  = "SQS: visible messages and oldest age"
      region = local.region
      view   = "timeSeries"
      stat   = "Maximum"
      period = 60
      metrics = concat(
        [for q in local.queue_names : ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", q]],
        [for q in local.queue_names : ["AWS/SQS", "ApproximateAgeOfOldestMessage", "QueueName", q, { yAxis = "right" }]],
      )
    }
  }

  widget_dlqs = {
    type   = "metric"
    width  = 12
    height = 6
    properties = {
      title   = "DLQs (must be 0)"
      region  = local.region
      view    = "timeSeries"
      stat    = "Maximum"
      period  = 60
      metrics = [for q in var.dlq_names : ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", q]]
    }
  }

  widget_dynamodb = {
    type   = "metric"
    width  = 12
    height = 6
    properties = {
      title  = "DynamoDB: consumed capacity and throttles"
      region = local.region
      view   = "timeSeries"
      stat   = "Sum"
      period = 60
      metrics = concat(
        [for t in var.dynamodb_table_names : ["AWS/DynamoDB", "ConsumedWriteCapacityUnits", "TableName", t]],
        [for t in var.dynamodb_table_names : ["AWS/DynamoDB", "WriteThrottleEvents", "TableName", t, { yAxis = "right" }]],
      )
    }
  }

  widget_lambda = local.has_lambda ? [{
    type   = "metric"
    width  = 12
    height = 6
    properties = {
      title  = "Reservation expirer"
      region = local.region
      view   = "timeSeries"
      period = 60
      metrics = [
        ["AWS/Lambda", "Invocations", "FunctionName", var.lambda_function_name, { stat = "Sum" }],
        ["AWS/Lambda", "Errors", "FunctionName", var.lambda_function_name, { stat = "Sum" }],
        ["AWS/Lambda", "Throttles", "FunctionName", var.lambda_function_name, { stat = "Sum" }],
        ["AWS/Lambda", "Duration", "FunctionName", var.lambda_function_name, { stat = "p99", yAxis = "right" }],
      ]
    }
  }] : []

  widget_api = local.has_api ? [{
    type   = "metric"
    width  = 12
    height = 6
    properties = {
      title  = "API Gateway: traffic, errors, p99 latency"
      region = local.region
      view   = "timeSeries"
      period = 60
      metrics = [
        ["AWS/ApiGateway", "Count", "ApiName", var.api.name, "Stage", var.api.stage, { stat = "Sum" }],
        ["AWS/ApiGateway", "4XXError", "ApiName", var.api.name, "Stage", var.api.stage, { stat = "Sum" }],
        ["AWS/ApiGateway", "5XXError", "ApiName", var.api.name, "Stage", var.api.stage, { stat = "Sum" }],
        ["AWS/ApiGateway", "Latency", "ApiName", var.api.name, "Stage", var.api.stage, { stat = "p99", yAxis = "right" }],
      ]
    }
  }] : []

  widget_ecs = length(var.ecs_services) > 0 ? [{
    type   = "metric"
    width  = 12
    height = 6
    properties = {
      title  = "ECS: CPU and running tasks"
      region = local.region
      view   = "timeSeries"
      period = 60
      metrics = concat(
        [for s in var.ecs_services : ["AWS/ECS", "CPUUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", s, { stat = "Average" }]],
        [for s in var.ecs_services : ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", var.ecs_cluster_name, "ServiceName", s, { stat = "Average", yAxis = "right" }]],
      )
    }
  }] : []
}

resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = "${var.name}-overview"

  dashboard_body = jsonencode({
    widgets = concat(
      local.widget_api,
      local.widget_ecs,
      [local.widget_queues, local.widget_dlqs, local.widget_dynamodb],
      local.widget_lambda,
    )
  })
}
