output "target" {
  value = local.target
}

output "web_instance_id" {
  value = aws_instance.web.id
}

output "web_public_ip" {
  description = "Su Floci può essere 127.0.0.1 o l'IP del container: vedi README"
  value       = aws_instance.web.public_ip
}

output "web_url" {
  value = "http://${aws_instance.web.public_ip}"
}

output "ssh_command" {
  value = "ssh ec2-user@${aws_instance.web.public_ip}"
}

output "ssm_session_command" {
  value = "aws ssm start-session --target ${aws_instance.web.id} --region ${var.region}"
}

output "rds_endpoint" {
  value = aws_db_instance.main.address
}

output "rds_port" {
  value = aws_db_instance.main.port
}

output "bucket_name" {
  value = aws_s3_bucket.assets.bucket
}

output "ssm_db_password_param" {
  description = "Recuperala con: aws ssm get-parameter --name <questo> --with-decryption"
  value       = aws_ssm_parameter.db_password.name
}
