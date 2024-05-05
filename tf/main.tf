provider "aws" {
  region     = var.aws_region
  access_key = var.access_key
  secret_key = var.secret_key
}

# Start with a VPC and all the trimmings
#   (subnets, igw, route tables and their associations)

# For simplicity sake we'll use a whole /16
resource "aws_vpc" "cluster_vpc" {
  cidr_block = "10.2.0.0/16"
  tags = {
    Name = "k8s VPC"
  }
}

# we'll use 3 AZs for redundancy
#   (when we actually have >=3 hosts)

resource "random_shuffle" "az" {
  input        = ["${var.aws_region}a", "${var.aws_region}c",  "${var.aws_region}e"]
  result_count = 1
}

resource "aws_subnet" "cluster_subnet_1" {
  vpc_id            = aws_vpc.cluster_vpc.id
  cidr_block        = "10.2.1.0/24"
  availability_zone = random_shuffle.az.result[0]

  tags = {
    Name = "Cluster Subnet 1"
  }
}

resource "aws_internet_gateway" "cluster_igw" {
  vpc_id = aws_vpc.cluster_vpc.id

  tags = {
    Name = "Cluster Internet Gateway"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.cluster_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cluster_igw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.cluster_igw.id
  }

  tags = {
    Name = "Cluster Public Route Table"
  }
}

resource "aws_route_table_association" "public_1_rt_a" {
  subnet_id      = aws_subnet.cluster_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_security_group" "k8s_sg" {
  name   = "K8S Ports"
  vpc_id = aws_vpc.cluster_vpc.id

  # k8s api
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # etcd on 2379+2380
  ingress {
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # for ssh
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # kubelet
  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # where we'll expose services
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # just open up egress.. You could ofc be more selective for higher security needs
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# random string for unique bucket name
resource "random_string" "s3name" {
  length = 9
  special = false
  upper = false
  lower = true
}

# we'll use a bucket to pass info from master to node(s)
#    ie, join command

resource "aws_s3_bucket_acl" "s3_bucket_acl" {
  bucket = aws_s3_bucket.s3_bucket.id
  acl    = "private"
  depends_on = [aws_s3_bucket_ownership_controls.s3_bucket_acl_ownership]
}

resource "aws_s3_bucket_ownership_controls" "s3_bucket_acl_ownership" {
  bucket = aws_s3_bucket.s3_bucket.id
  rule {
    object_ownership = "ObjectWriter"
  }
}

resource "aws_s3_bucket" "s3_bucket" {
  bucket = "k8s-${random_string.s3name.result}"
  force_destroy = true
  depends_on = [
    random_string.s3name
  ]
}


# ECR repo for the test app image..
resource "aws_ecr_repository" "demo-app" {
  name                 = "demo-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_instance" "ec2_instance_master" {
    ami = var.ami_id
    subnet_id = aws_subnet.cluster_subnet_1.id
    instance_type = var.instance_type
    key_name = var.ami_key_pair_name
    associate_public_ip_address = true
    security_groups = [ aws_security_group.k8s_sg.id ]
    root_block_device {
    volume_type = "gp2"
    volume_size = "16"
    delete_on_termination = true
    }
    tags = {
        Name = "k8s-cluster-master-1"
    }
    # Install script can be encoded into user data that will be executed on ec2 startup
    user_data_base64 = base64encode("${templatefile("scripts/install_master.sh", {
    access_key = var.access_key
    private_key = var.secret_key
    region = var.aws_region
    s3_bucket_name = "k8s-${random_string.s3name.result}"
    })}")

    depends_on = [
    aws_s3_bucket.s3_bucket,
    random_string.s3name
  ]

    
} 

resource "aws_instance" "ec2_instance_worker" {
    ami = var.ami_id
    count = var.num_nodes
    subnet_id = aws_subnet.cluster_subnet_1.id
    instance_type = var.instance_type
    key_name = var.ami_key_pair_name
    associate_public_ip_address = true
    security_groups = [ aws_security_group.k8s_sg.id ]
    root_block_device {
    volume_type = "gp2"
    volume_size = "16"
    delete_on_termination = true
    }
    tags = {
        Name = "k8s-cluster-worker-${count.index + 1}"
    }
    # Install script can be encoded into user data that will be executed on ec2 startup
    user_data_base64 = base64encode("${templatefile("scripts/install_worker.sh", {
    access_key = var.access_key
    private_key = var.secret_key
    region = var.aws_region
    s3_bucket_name = "k8s-${random_string.s3name.result}"
    worker_number = "${count.index + 1}"
    ip_of_master = "${aws_instance.ec2_instance_master.private_ip}"
    })}")
  
    depends_on = [
      aws_s3_bucket.s3_bucket,
      random_string.s3name,
      aws_instance.ec2_instance_master
  ]
} 