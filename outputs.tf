output "meta_nodes_ids" {
  description = "A list of all meta node instance IDs."
  value       = aws_instance.meta_node[*].id
}

output "data_node_ids" {
  description = "A list of all data node instance IDs."
  value       = aws_instance.data_node[*].id
}

output "data_node_count" {
  description = "The number of data nodes, which can be used with modules that configure load balancers, etc."
  value       = length(aws_instance.data_node)
}