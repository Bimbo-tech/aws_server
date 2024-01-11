terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}



resource "aws_instance" "monitor_instance" {
  ami           = "ami-0905a3c97561e0b69"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id
  #ubnet_id = aws_subnet.main_a.id
  vpc_security_group_ids      = [aws_security_group.security.id]
  associate_public_ip_address = true
  key_name                    = "monitor"

  connection {
    user        = "ubuntu"
    host        = self.public_ip
    private_key = file("/Users/abimbolaogungbe/Downloads/monitor.pem")


  }

  #provisioner "file" {
  #source      = "/Users/abimbolaogungbe/Downloads/monitor.pem"
  # destination = "/home/.ssh/ubuntu/monitor.pem"



  # Install ansible in the ubuntu
  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt-get install -y software-properties-common",
      "sudo apt-add-repository --yes --update ppa:ansible/ansible",
      "sudo apt-get install -y ansible",
    ]
  }
  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=false ansible-playbook -u ubuntu -i '${self.public_ip},' --private-key /Users/abimbolaogungbe/Downloads/monitor.pem /Users/abimbolaogungbe/Documents/ansible/playbook.yaml"



  }


  tags = {
    Name = "MonitorInstance"
  }
}


#creating a VPC

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "vpc"
  }
}


#creating subnet

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-west-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public subnet"
  }
}
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-west-1b"

  tags = {
    Name = "private subnet"
  }
}

#resource "aws_subnet" "main_a" {
#vpc_id     = aws_vpc.main.id
#cidr_block = cidrsubnet(aws_vpc.main.cidr_block, 8, 0)
#}

#creating internet getaway
resource "aws_internet_gateway" "monitoring" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "vpc_igw"
  }
}

#creating route_table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.monitoring.id
  }
}

#creating route_table_association

resource "aws_route_table_association" "monitoring-a" {
  #subnet_id      = aws_subnet.main_a.id
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public.id
}



#securitygroup using Terraform
resource "aws_security_group" "security" {
  name   = "security-group"
  vpc_id = aws_vpc.main.id

  ingress {
    description      = "Allow SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "Allow traffic to Prometheus server (port 9090 by default)"
    from_port        = 9090
    to_port          = 9090
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "Allow traffic to Grafana (port 3000 by default)"
    from_port        = 3000
    to_port          = 3000
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    description      = "Allow all outbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description = "prometheus Node Exporter"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    # ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    # ipv6_cidr_blocks = ["::/0"]

  }



}




