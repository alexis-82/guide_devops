variable "project" {
  description = "Prefisso usato per nomi e tag delle risorse"
  type        = string
  default     = "aws-lab"
}

variable "region" {
  description = "Region AWS (eu-south-1 = Milano)"
  type        = string
  default     = "eu-south-1"
}

variable "aws_profile" {
  description = "Profilo della AWS CLI da usare sul target aws"
  type        = string
  default     = "lab"
}

variable "floci_endpoint" {
  description = "Endpoint di Floci (usato solo nel workspace floci)"
  type        = string
  default     = "http://localhost:4566"
}

variable "my_ip" {
  description = "Il tuo IP pubblico in CIDR /32, l'unico ammesso in SSH (es. 93.45.12.34/32)"
  type        = string

  validation {
    condition     = can(cidrhost(var.my_ip, 0)) && endswith(var.my_ip, "/32")
    error_message = "my_ip deve essere un singolo IPv4 in formato CIDR /32, es. 93.45.12.34/32."
  }
}

variable "ssh_public_key_path" {
  description = "Chiave pubblica SSH da importare come key pair"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "instance_type" {
  description = "Tipo istanza EC2 (t3.micro rientra nel Free plan)"
  type        = string
  default     = "t3.micro"
}

variable "db_instance_class" {
  description = "Classe istanza RDS (db.t3.micro rientra nel Free plan)"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Nome del database applicativo"
  type        = string
  default     = "app"
}

variable "db_username" {
  description = "Utente master di RDS"
  type        = string
  default     = "labadmin"
}

variable "ami_id" {
  description = "Override dell'AMI. Vuoto = AL2023 da SSM su AWS, ami-0abcdef1234567891 (AL2023) su Floci"
  type        = string
  default     = ""
}

variable "enable_s3_endpoint" {
  description = "Esercizio: aggiunge un S3 gateway endpoint (gratuito) alla subnet pubblica"
  type        = bool
  default     = false
}

variable "budget_email" {
  description = "Email per gli alert di AWS Budgets (solo target aws). Vuoto = nessun budget"
  type        = string
  default     = ""
}

variable "budget_limit_usd" {
  description = "Soglia mensile del budget in USD"
  type        = number
  default     = 5
}
