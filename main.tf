terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }

  required_version = ">= 1.2.0"
}

provider "cloudflare" {}

provider "aws" {
  region = "us-east-1"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu.id
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.wordpress_server.id]
  instance_type          = "t3.micro"

  connection {
    type     = "ssh"
    user     = "ubuntu"
    private_key = file("ssh_key")
    host     = self.public_ip
  }

  tags = {
    Name = "WordPressServer"
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPUoXFooLltPd7iMNknIXTWmPIxHOEOaVdqktT1J+snq wordpress@PhilomathesInc"
}

resource "aws_security_group" "wordpress_server" {
  name        = "wp_server"
  description = "Allow traffic on wordpress_server"
  vpc_id      = "vpc-09c69d1867d06a4d5"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

   egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_db_instance" "wordpress" {
  allocated_storage    = 10
  db_name              = "wordpress"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t3.micro"
  username             = "wordpress"
  password             = "wordpress"
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true
  vpc_security_group_ids = [aws_security_group.rds.id]
}

resource "aws_security_group" "rds" {
  name        = "rds_server"
  description = "Allow traffic on database server"
  vpc_id      = "vpc-09c69d1867d06a4d5"
  ingress {
    description = "HTTP"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.wordpress_server.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    security_groups = [aws_security_group.wordpress_server.id]
  }
}

data "cloudflare_zone" "mriyam" {
  name = "mriyam.com"
}

# Create a record
resource "cloudflare_record" "wordpress" {
  zone_id = data.cloudflare_zone.mriyam.id
  name    = "wordpress"
  value   = aws_instance.web.public_ip
  type    = "A"
  ttl     = 120
}

resource "cloudflare_record" "www_wordpress" {
  zone_id = data.cloudflare_zone.mriyam.id
  name    = "www.wordpress"
  value   = aws_instance.web.public_ip
  type    = "A"
  ttl     = 120
}

resource "terraform_data" "tls_certificate" {
  triggers_replace = cloudflare_record.wordpress.id

  connection {
    type     = "ssh"
    user     = "ubuntu"
    private_key = file("ssh_key")
    host     = aws_instance.web.public_ip
  }

  provisioner "file" {
    source      = "wordpress.conf"
    destination = "/tmp/${cloudflare_record.wordpress.hostname}.conf"
  }

  provisioner "file" {
    source      = "setup.sh"
    destination = "/tmp/setup.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/setup.sh",
      "/tmp/setup.sh ${cloudflare_record.wordpress.hostname} ${aws_db_instance.wordpress.endpoint}",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "sudo certbot --nginx --agree-tos --register-unsafely-without-email -d ${cloudflare_record.wordpress.hostname} -d www.${cloudflare_record.wordpress.hostname}",
    ]
  }
}

output "ec2_public_ip" {
  value = aws_instance.web.public_ip
}

output "ec2_public_dns" {
  value = aws_instance.web.public_dns
}

output "rds_endpoint" {
  value = aws_db_instance.wordpress.endpoint
}