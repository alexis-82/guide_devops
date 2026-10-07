# Password generata da Terraform: non la scrivi mai a mano né in un .tfvars.
# Attenzione: resta comunque nello state, che quindi va protetto (mai su git).
resource "random_password" "db" {
  length           = 24
  special          = true
  override_special = "!#$%^&*()-_=+[]{}<>:?" # RDS non accetta / @ " e spazio
}

resource "aws_ssm_parameter" "db_password" {
  name  = "/${var.project}/db/password"
  type  = "SecureString"
  value = random_password.db.result
}

resource "aws_ssm_parameter" "db_host" {
  name  = "/${var.project}/db/host"
  type  = "String"
  value = aws_db_instance.main.address
}

# La porta va letta dall'endpoint, non data per scontata: su AWS è 3306,
# su Floci RDS è esposto su una porta diversa (es. 7001).
resource "aws_ssm_parameter" "db_port" {
  name  = "/${var.project}/db/port"
  type  = "String"
  value = tostring(aws_db_instance.main.port)
}

resource "aws_ssm_parameter" "db_user" {
  name  = "/${var.project}/db/user"
  type  = "String"
  value = var.db_username
}

resource "aws_ssm_parameter" "bucket" {
  name  = "/${var.project}/s3/bucket"
  type  = "String"
  value = aws_s3_bucket.assets.bucket
}
