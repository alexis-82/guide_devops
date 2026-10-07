# Su AWS: ultima Amazon Linux 2023 risolta dal parametro pubblico SSM.
# Su Floci: ami-0abcdef1234567891, ID del catalogo mappato su amazonlinux:2023.
# (L'alias ami-amazonlinux2023 va bene per RunInstances ma non per DescribeImages,
# che il provider chiama per trovare il root device: errore "couldn't find resource".)
data "aws_ssm_parameter" "al2023" {
  count = (!local.is_floci && var.ami_id == "") ? 1 : 0
  name  = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  ami_id = (
    var.ami_id != "" ? var.ami_id :
    local.is_floci ? "ami-0abcdef1234567891" :
    data.aws_ssm_parameter.al2023[0].value
  )
}

resource "aws_key_pair" "lab" {
  key_name   = "${var.project}-key"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

resource "aws_instance" "web" {
  ami                    = local.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public_a.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = aws_key_pair.lab.key_name
  iam_instance_profile   = aws_iam_instance_profile.web.name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # solo IMDSv2: protegge le credenziali del ruolo da SSRF
  }

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true # nessun volume EBS orfano dopo il destroy
  }

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    project = var.project
    region  = var.region
  })
  user_data_replace_on_change = true

  # Il bootstrap legge i parametri SSM: devono esistere prima dell'avvio.
  depends_on = [
    aws_ssm_parameter.db_host,
    aws_ssm_parameter.db_port,
    aws_ssm_parameter.db_user,
    aws_ssm_parameter.db_password,
    aws_ssm_parameter.bucket,
  ]

  tags = { Name = "${var.project}-web" }
}
