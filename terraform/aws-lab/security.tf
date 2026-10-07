# ------------------------------------------------------------------ SG-web

resource "aws_security_group" "web" {
  name        = "${var.project}-sg-web"
  description = "Web pubblico, SSH solo dal mio IP"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${var.project}-sg-web" }
}

resource "aws_vpc_security_group_ingress_rule" "web_http" {
  security_group_id = aws_security_group.web.id
  description       = "HTTP da internet"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "web_https" {
  security_group_id = aws_security_group.web.id
  description       = "HTTPS da internet"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "web_ssh" {
  security_group_id = aws_security_group.web.id
  description       = "SSH solo dal mio IP"
  cidr_ipv4         = var.my_ip
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

# La console AWS aggiunge da sola l'egress "tutto aperto", Terraform NO.
# Senza questa regola: niente dnf install, niente S3, niente connessione a RDS.
resource "aws_vpc_security_group_egress_rule" "web_all_out" {
  security_group_id = aws_security_group.web.id
  description       = "Tutto il traffico in uscita"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ------------------------------------------------------------------- SG-db

resource "aws_security_group" "db" {
  name        = "${var.project}-sg-db"
  description = "MySQL raggiungibile solo da SG-web"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${var.project}-sg-db" }
}

# La sorgente è un altro security group, non un CIDR: entra solo chi ha SG-web.
resource "aws_vpc_security_group_ingress_rule" "db_from_web" {
  security_group_id            = aws_security_group.db.id
  description                  = "MySQL da SG-web"
  referenced_security_group_id = aws_security_group.web.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
}

# Nessuna regola di egress su SG-db: i SG sono stateful, le risposte escono comunque.
