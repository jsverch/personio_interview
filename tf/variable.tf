# In a real world scenerio you'd want to use vault or some
#   other way to dybamically pull secrets

variable "ami_key_pair_name" {
        default = "k8s-cluster-key" 
}

variable "num_nodes" {
        description = "number of worker nodes for cluster."
        default = 1
}

variable "ami_id" {
        description = "AMI for ubuntu 20.04 LTS"
        default = "ami-0a6b2839d44d781b2"
}

# smallest+cheapest instance that is really  usable for k8s,
#  not necessarily the one you want for prod
variable "instance_type" {
        default = "t2.medium"
}

variable "aws_region" {
        description = "AWS region to use"
        default = "us-east-1"
}