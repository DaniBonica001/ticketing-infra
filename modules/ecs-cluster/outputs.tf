output "cluster_name" {
  description = "Cluster name."
  value       = aws_ecs_cluster.this.name
}

output "cluster_arn" {
  description = "Cluster ARN."
  value       = aws_ecs_cluster.this.arn
}
