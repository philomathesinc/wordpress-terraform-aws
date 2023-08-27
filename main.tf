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
  vpc_security_group_ids = [aws_security_group.allow_tls.id]
  instance_type          = "t3.micro"
  user_data              = <<EOF
#!/bin/bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
EOF
  tags = {
    Name = "HelloWorld"
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDBtg6UUh0Xckv29J7IqK4PMSnonL1U0hoYAlbs+MYZm87ObctylwHlKnpfu1yfJG/D/7p+KvPo5+Wl7m+7ZkErQwbaWYyZLOqaidnGWcOd/4Ok3nHv8ulalsmQCnFCIuJ6CMlmPaCIIIfiPbYGzmXGYPVH4uoUb0UnRdvCCgbdOu/budeEy+f2u0BYY8YhLsYBYGsbCp6Qb8kxp3cq285j5MZKYkLYQJTT2FTexokGUkFxjqszphlR6htPXmYaXixX061nW/5wzgax4Nyn+UJe5nZJd9JGh8bsaIMMk7YW1bpk89exdhS5JDSv2Gsg4RATnr7qxhFtFLTcR2+e0wzTRTxIXg/IbAxTN0R5cWJSR1t+NPgBK+iBD401/kTnaKoELz5zMGxOVwNwj4isxLygVjS0UKO27vU+iBDdbR4EpBzwVMpgJem5hJMG7njf2wWCeU30xya85SOL6ha9eBuPwACyf1UbnPtEL9WIK2BU7QXLv97cJ+zYw4gVka+t9k/yHOKWjSz2pzygo2TcdJMjzrmDaSOzn1LnrpGgQdPRqOK0wVx+ncWGTklRvaSzVgHC2fVG+oEFxwD2v+Npc3tTJWZmNznPgkuwUgIxRThMDOX10ujSbpXylkU5hOEZ1POn2PlSldUvQ5mUf8og6wv9L1eaB47hL+PN2wUWcu6Bbw== aj_das"
}

resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = "vpc-09c69d1867d06a4d5"

  ingress {
    description = "TLS from VPC"
    from_port   = 22
    to_port     = 22
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

  tags = {
    Name = "allow_tls"
  }
}

output "public" {
  value = aws_instance.web.public_ip
}