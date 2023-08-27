terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

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
  user_data              = <<EOF
#!/bin/bash
# Installing dependencies
sudo apt-get update && sudo apt-get install -y \
curl \
mysql-client \
nginx \
php-curl \
php-gd \
php-intl \
php-mbstring \
php-mysql \
php-soap \
php-xml \
php-xmlrpc \
php-zip \
php8.1-fpm

# Installing wp-cli
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
chmod +x wp-cli.phar && \
sudo mv wp-cli.phar /usr/local/bin/wp

EOF

  user_data_replace_on_change = true
  tags = {
    Name = "HelloWorld"
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDBtg6UUh0Xckv29J7IqK4PMSnonL1U0hoYAlbs+MYZm87ObctylwHlKnpfu1yfJG/D/7p+KvPo5+Wl7m+7ZkErQwbaWYyZLOqaidnGWcOd/4Ok3nHv8ulalsmQCnFCIuJ6CMlmPaCIIIfiPbYGzmXGYPVH4uoUb0UnRdvCCgbdOu/budeEy+f2u0BYY8YhLsYBYGsbCp6Qb8kxp3cq285j5MZKYkLYQJTT2FTexokGUkFxjqszphlR6htPXmYaXixX061nW/5wzgax4Nyn+UJe5nZJd9JGh8bsaIMMk7YW1bpk89exdhS5JDSv2Gsg4RATnr7qxhFtFLTcR2+e0wzTRTxIXg/IbAxTN0R5cWJSR1t+NPgBK+iBD401/kTnaKoELz5zMGxOVwNwj4isxLygVjS0UKO27vU+iBDdbR4EpBzwVMpgJem5hJMG7njf2wWCeU30xya85SOL6ha9eBuPwACyf1UbnPtEL9WIK2BU7QXLv97cJ+zYw4gVka+t9k/yHOKWjSz2pzygo2TcdJMjzrmDaSOzn1LnrpGgQdPRqOK0wVx+ncWGTklRvaSzVgHC2fVG+oEFxwD2v+Npc3tTJWZmNznPgkuwUgIxRThMDOX10ujSbpXylkU5hOEZ1POn2PlSldUvQ5mUf8og6wv9L1eaB47hL+PN2wUWcu6Bbw== aj_das"
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

output "public" {
  value = aws_instance.web.public_ip
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