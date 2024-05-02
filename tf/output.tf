output "master_public_ip" {
  description = "Public address IP of master"
  value       = aws_instance.ec2_instance_master.public_ip
}

output "worker_public_ip" {
  description = "Public address IP of worker"
  value       = aws_instance.ec2_instance_worker.*.public_ip
}