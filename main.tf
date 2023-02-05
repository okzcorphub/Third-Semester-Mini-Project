# Defining provider details and setting up the region
provider "aws" {
  region = "us-east-1"
}

# Creating our VPC
resource "aws_vpc" "terra_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "terra_vpc"
  }
}

# Creating our Internet Gateway

resource "aws_internet_gateway" "terra-ig" {
  vpc_id = aws_vpc.terra_vpc.id
  tags = {
    Name = "terra-ig"
  }
}

# Creating our route tables

resource "aws_route_table" "terra-route-table-public" {
  vpc_id = aws_vpc.terra_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.terra-ig.id
  }
  tags = {
    Name = "terra-route-table-public"
  }
}

# Creating our  public subnets, subnet 1 and 2

resource "aws_subnet" "terra-public-subnet1" {
  vpc_id                  = aws_vpc.terra_vpc.id
  cidr_block              = "10.0.6.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags = {
    Name = "terra-public-subnet1"
  }
}

resource "aws_subnet" "terra-public-subnet2" {
  vpc_id                  = aws_vpc.terra_vpc.id
  cidr_block              = "10.0.7.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"
  tags = {
    Name = "terra-public-subnet2"
  }
}

# linking our public subnets to our route tables

resource "aws_route_table_association" "terra-public-subnet1-association" {
  subnet_id      = aws_subnet.terra-public-subnet1.id
  route_table_id = aws_route_table.terra-route-table-public.id
}

resource "aws_route_table_association" "terra-public-subnet2-association" {
  subnet_id      = aws_subnet.terra-public-subnet2.id
  route_table_id = aws_route_table.terra-route-table-public.id
}

# Creating our network Access Control List to manage traffic

resource "aws_network_acl" "terra-network_acl" {
  vpc_id     = aws_vpc.terra_vpc.id
  subnet_ids = [aws_subnet.terra-public-subnet1.id, aws_subnet.terra-public-subnet2.id]

  ingress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
}

# Creating our security group for our load balancer

resource "aws_security_group" "terra-lb-sg" {
  name        = "terra-lb-sg"
  description = "Security group for our load balancer"
  vpc_id      = aws_vpc.terra_vpc.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Creating a security group for our 3 EC2 instances

resource "aws_security_group" "terra-sg-rule" {
  name        = "allow_ssh_http_https_traffic"
  description = "Allow SSH, HTTP and HTTPS inbound traffic for private instances"
  vpc_id      = aws_vpc.terra_vpc.id
  ingress {
    description     = "HTTP"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
    security_groups = [aws_security_group.terra-lb-sg.id]
  }
  ingress {
    description     = "HTTPS"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
    security_groups = [aws_security_group.terra-lb-sg.id]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }
  tags = {
    Name = "terra_sg_rule"
  }
}

# Creating our first EC2 instance (servers)

resource "aws_instance" "terra1" {
  ami               = "ami-00874d747dde814fa"
  instance_type     = "t2.micro"
  key_name          = "terra"
  security_groups   = [aws_security_group.terra-sg-rule.id]
  subnet_id         = aws_subnet.terra-public-subnet1.id
  availability_zone = "us-east-1a"
  tags = {
    Name   = "terra1"
    source = "terraform"
  }
}
# Creating our Second EC2 instance 

resource "aws_instance" "terra2" {
  ami               = "ami-00874d747dde814fa"
  instance_type     = "t2.micro"
  key_name          = "terra"
  security_groups   = [aws_security_group.terra-sg-rule.id]
  subnet_id         = aws_subnet.terra-public-subnet2.id
  availability_zone = "us-east-1b"
  tags = {
    Name   = "terra2"
    source = "terraform"
  }
}
# Creating our third EC2 instance

resource "aws_instance" "terra3" {
  ami               = "ami-00874d747dde814fa"
  instance_type     = "t2.micro"
  key_name          = "terra"
  security_groups   = [aws_security_group.terra-sg-rule.id]
  subnet_id         = aws_subnet.terra-public-subnet1.id
  availability_zone = "us-east-1a"
  tags = {
    Name   = "terra3"
    source = "terraform"
  }
}

# Creating a host-inventory file to warehouse our EC2 servers' IP addresses

resource "local_file" "IP_addresses" {
  filename = "/home/vagrant/terraform-task/host-inventory"
  content  = <<EOT
${aws_instance.terra1.public_ip}
${aws_instance.terra2.public_ip}
${aws_instance.terra3.public_ip}
  EOT
}

# Creating an application load balancer to enable us switch between servers

resource "aws_lb" "terra_lb" {
  name               = "terra-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.terra-lb-sg.id]
  subnets            = [aws_subnet.terra-public-subnet1.id, aws_subnet.terra-public-subnet2.id]
  enable_deletion_protection = false
  depends_on                 = [aws_instance.terra1, aws_instance.terra2, aws_instance.terra3]
}

# Creating our target group and listener rules and parameters

resource "aws_lb_target_group" "terra-tg" {
  name        = "terra-tg"
  target_type = "instance"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.terra_vpc.id
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "terra_listener" {
  load_balancer_arn = aws_lb.terra_lb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.terra-tg.arn
  }
}

resource "aws_lb_listener_rule" "terra_listener_rule" {
  listener_arn = aws_lb_listener.terra_listener.arn
  priority     = 1
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.terra-tg.arn
  }
  condition {
    path_pattern {
      values = ["/"]
    }
  }
}

# Linking our target group to our application load balancer

resource "aws_lb_target_group_attachment" "terra-tg-attachment1" {
  target_group_arn = aws_lb_target_group.terra-tg.arn
  target_id        = aws_instance.terra1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "terra-tg-attachment2" {
  target_group_arn = aws_lb_target_group.terra-tg.arn
  target_id        = aws_instance.terra2.id
  port             = 80
}
resource "aws_lb_target_group_attachment" "terra-tg-attachment3" {
  target_group_arn = aws_lb_target_group.terra-tg.arn
  target_id        = aws_instance.terra3.id
  port             = 80

}

# Creating provisioner to run our ansible playbook

resource "null_resource" "ansible-script" {
  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i host-inventory playbook.yml"
  }
  depends_on = [local_file.IP_addresses]
}
