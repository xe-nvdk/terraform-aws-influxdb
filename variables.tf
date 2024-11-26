variable "availability_zones" {
  description = "List of availability zones where resources will be deployed"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "name" {
  description = "The prefix applied to resources managed by this module"
  default     = "influxdb"
}

variable "ami" {
  description = "The AMI ID to deploy"
  default     = "ami-015f3596bb2ef1aaa" # This is Ubuntu 24.04 in us-east-1
}

variable "data_instances" {
  description = "The number of data nodes to run"
  default     = 2
}

variable "meta_instances" {
  description = "The number of meta nodes to run"
  default     = 3
}

variable "subnet_ids" {
  description = "List of subnet IDs for distributing resources"
  type        = list(string)
  default     = []
}

variable "instance_type" {
  description = "The AWS Instance type for data nodes (e.g., r6i.large)"
  default     = "r6i.2xlarge"
}

variable "vpc_id" {
  description = "VPC ID for instances and security groups"
  type        = string
  default     = ""
}

variable "key_name" {
  description = "Key name for new hosts"
  default     = ""
}

variable "zone_id" {
  description = "The private DNS zone to create records for hosts"
  default     = ""
}

variable "data_disk_size" {
  description = "The size of the data disks to provision, for data nodes only"
  default     = 300
}

variable "data_disk_iops" {
  description = "The number of IOPs for the io2 type volume"
  default     = 4000
}

variable "security_group" {
  description = "Extra security groups to apply to all hosts"
  default     = [""]
}

variable "user_data" {
  description = "User data script for all instances"
  default     = ""
}

variable "data_disk_device_name" {
  description = "The name of the device to attach to the data nodes"
  default     = "/dev/xvdh"
}

variable "meta_disk_device_name" {
  description = "The name of the device to attach to the meta nodes"
  default     = "/dev/xvdh"
}

variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment tag for resources (e.g., dev, prod)"
  type        = string
  default     = "prod"
}

variable "tags" {
  description = "Optional tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "aws_secret_key" {
  description = "AWS secret access key"
  type        = string
  sensitive   = true
}

variable "aws_access_key" {
  description = "AWS access key ID"
  type        = string
  sensitive   = true
}