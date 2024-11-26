# Create data nodes, equally distributing them across subnets
resource "aws_instance" "data_node" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = element(var.subnet_ids, count.index % length(var.subnet_ids))
  key_name               = var.key_name
  user_data              = var.user_data == "" ? file("${path.module}/init/data-nodes.sh") : var.user_data
  ebs_optimized          = true
  vpc_security_group_ids = [aws_security_group.influxdb_cluster.id, aws_security_group.data_node.id]
  count                  = var.data_instances

  tags = {
    Name        = "${var.name}-data-node-${count.index + 1}"
    Environment = var.environment
  }
}

resource "aws_ebs_volume" "data" {
  size              = var.data_disk_size
  encrypted         = true
  type              = "io2"
  iops              = var.data_disk_iops
  availability_zone = aws_instance.data_node[count.index].availability_zone
  count             = var.data_instances

  tags = {
    Name        = "${var.name}-data-volume-${count.index + 1}"
    Environment = var.environment
  }
}

resource "aws_volume_attachment" "data_attachment" {
  device_name = var.data_disk_device_name
  volume_id   = aws_ebs_volume.data[count.index].id
  instance_id = aws_instance.data_node[count.index].id
  count       = var.data_instances
  force_detach = true
}

# Create meta nodes in the first subnet to avoid splits across AZs
resource "aws_instance" "meta_node" {
  ami                    = var.ami
  instance_type          = "t2.medium"
  subnet_id              = var.subnet_ids[0]
  key_name               = var.key_name
  user_data              = var.user_data == "" ? file("${path.module}/init/meta-nodes.sh") : var.user_data
  vpc_security_group_ids = [aws_security_group.influxdb_cluster.id]
  count                  = var.meta_instances

  tags = {
    Name        = "${var.name}-meta-node-${count.index + 1}"
    Environment = var.environment
  }
}

resource "aws_ebs_volume" "meta" {
  size              = 100
  encrypted         = true
  type              = "io2"
  iops              = var.data_disk_iops
  availability_zone = aws_instance.meta_node[count.index].availability_zone
  count             = var.meta_instances

  tags = {
    Name        = "${var.name}-meta-volume-${count.index + 1}"
    Environment = var.environment
  }
}

resource "aws_volume_attachment" "meta_attachment" {
  device_name = var.meta_disk_device_name
  volume_id   = aws_ebs_volume.meta[count.index].id
  instance_id = aws_instance.meta_node[count.index].id
  count       = var.meta_instances
  force_detach = true
}

# DNS records for meta and data nodes
resource "aws_route53_record" "meta_node" {
  zone_id = var.zone_id
  name    = "${var.name}-meta${format("%02d", count.index + 1)}"
  type    = "A"
  ttl     = "120"
  records = [aws_instance.meta_node[count.index].private_ip]
  count   = var.meta_instances
}

resource "aws_route53_record" "data_node" {
  zone_id = var.zone_id
  name    = "${var.name}-data${format("%02d", count.index + 1)}"
  type    = "A"
  ttl     = "120"
  records = [aws_instance.data_node[count.index].private_ip]
  count   = var.data_instances
}

# Security groups for cluster communications
resource "aws_security_group" "influxdb_cluster" {
  name        = "${var.name}_cluster"
  description = "Rules required for an Influx Enterprise Cluster"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.name}-cluster-sg"
    Environment = var.environment
  }
}

resource "aws_security_group_rule" "cluster_comms" {
  type              = "ingress"
  from_port         = 8088
  to_port           = 8091
  protocol          = "tcp"
  cidr_blocks       = [for ip in concat(aws_instance.meta_node.*.private_ip, aws_instance.data_node.*.private_ip) : "${ip}/32"]
  security_group_id = aws_security_group.influxdb_cluster.id
}

resource "aws_security_group_rule" "outbound" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.influxdb_cluster.id
}

resource "aws_security_group" "data_node" {
  description = "Security group for InfluxDB data node ingress"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 8086
    to_port     = 8086
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.name}-data-sg"
    Environment = var.environment
  }
}