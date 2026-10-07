data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "web" {
  name               = "${var.project}-web-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

# Minimo privilegio: solo questo bucket e solo i parametri SSM del progetto.
data "aws_iam_policy_document" "web" {
  statement {
    sid       = "ListBucket"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.assets.arn]
  }

  statement {
    sid       = "ObjectsRW"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.assets.arn}/*"]
  }

  # La chiave KMS gestita aws/ssm consente già il Decrypt via SSM agli utenti
  # dell'account: non serve un permesso kms:Decrypt esplicito.
  statement {
    sid       = "ReadProjectParams"
    actions   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
    resources = ["arn:aws:ssm:${var.region}:*:parameter/${var.project}/*"]
  }
}

resource "aws_iam_role_policy" "web" {
  name   = "${var.project}-web-policy"
  role   = aws_iam_role.web.id
  policy = data.aws_iam_policy_document.web.json
}

# Permette di entrare con Session Manager (aws ssm start-session) senza SSH.
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.web.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "web" {
  name = "${var.project}-web-profile"
  role = aws_iam_role.web.name
}
