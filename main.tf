provider "aws" {
  
  region = "us-east-1"
}

resource "aws_vpc" "VPC-Dev" {
    cidr_block = "10.0.0.0/16"
     enable_dns_support   = true
     enable_dns_hostnames = true
    tags ={
        Name = "VPD-Dev"
    }
  
}
resource "aws_internet_gateway" "Internet" {
    vpc_id = aws_vpc.VPC-Dev.id
    tags = {
      Name="IGW-Dev"
    }
  
}
resource "aws_subnet" "Subnet-Dev-Public" {
    count=2
    vpc_id = aws_vpc.VPC-Dev.id
    cidr_block = element(["10.0.1.0/24","10.0.2.0/24"],count.index) 
    availability_zone = element(["us-east-1a","us-east-1b"],count.index)
    map_public_ip_on_launch=true
    tags = {
      Name="Subnet-Dev-Public-${count.index+1}"
    }
    
  
}

resource "aws_subnet" "Subnet-Dev-Private" {
    count = 2
    vpc_id = aws_vpc.VPC-Dev.id
    cidr_block = element(["10.0.3.0/24","10.0.4.0/24"],count.index)
    availability_zone=element(["us-east-1a","us-east-1b"],count.index)
    map_public_ip_on_launch = true
    tags = {
      Name="Subnet-Dev-Private-${count.index+1}"
    }
}

resource "aws_eip" "DEV-IP" {
    count = 2
    domain = "vpc"
    
  
}

resource "aws_nat_gateway" "Dev-Nat" {
    count = 2
    allocation_id = aws_eip.DEV-IP[count.index].id
    subnet_id = aws_subnet.Subnet-Dev-Public[count.index].id
    tags = {
      Name="Nat-GW-Dev-${count.index+1}"
    }
}

resource "aws_route_table" "Public-Dev-Route" {
    vpc_id = aws_vpc.VPC-Dev.id

    route {
      cidr_block="0.0.0.0/0"
      gateway_id = aws_internet_gateway.Internet.id
    }
  
}

resource "aws_route_table_association" "Public-Dev-ASS" {
    count=2
    subnet_id = aws_subnet.Subnet-Dev-Public[count.index].id
    route_table_id = aws_route_table.Public-Dev-Route.id

  
}

resource "aws_route_table" "Private-Dev-Route" {
    count =2
    vpc_id = aws_vpc.VPC-Dev.id

    route {
      cidr_block = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.Dev-Nat[count.index].id
    }

}

resource "aws_route_table_association" "Private-Dev-ASS" {
    count=2
    subnet_id = aws_subnet.Subnet-Dev-Private[count.index].id
    route_table_id = aws_route_table.Private-Dev-Route[count.index].id
  
}

resource "aws_security_group" "Dev-alg-SG" {
    name="Dev-Security-Group"
    vpc_id = aws_vpc.VPC-Dev.id
    ingress{
      from_port = 80
      to_port = 80
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }  

    egress  {
      from_port=0
      to_port=0
      protocol="-1"
      cidr_blocks=["0.0.0.0/0"]
    }
}

resource "aws_security_group" "EC2-Security-Group" {
  name = "EC2-Security-Group"
  vpc_id = aws_vpc.VPC-Dev.id
  
  ingress  {
    from_port=80
    to_port=80
    protocol="tcp"
    security_groups=[aws_security_group.Dev-alg-SG.id]
  }
  egress  {
    from_port=0
    to_port=0
    protocol="-1"
    cidr_blocks=["0.0.0.0/0"]
}
}

resource "aws_lb" "ALB" {
  name = "Dev-ALB"
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.Dev-alg-SG.id]
  subnets = aws_subnet.Subnet-Dev-Public[*].id
}

resource "aws_lb_target_group" "Dev-TG" {
  name = "Dev-Target-Group"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.VPC-Dev.id
}



resource "aws_lb_listener" "Dev-LB-Listener" {
  load_balancer_arn = aws_lb.ALB.arn
  port = 80
  protocol = "HTTP"
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.Dev-TG.arn
  }
}

resource "aws_launch_template" "Dev-EC2" {
  image_id = "ami-0a4408457f9a03be3"
  instance_type = "t2.micro"
  network_interfaces {
    security_groups = [aws_security_group.EC2-Security-Group.id]
    
  }
  user_data = base64encode(<<EOF
#!/bin/bash
yum install -y httpd
systemctl start httpd
echo "Hello from ASG" > /var/www/html/index.html
EOF
  )
 
}


resource "aws_autoscaling_group" "Dev-ASG" {
  name ="Dev-Auto-Scaling-Group"
  max_size = 2
  min_size = 3
  desired_capacity = 2
  vpc_zone_identifier = aws_subnet.Subnet-Dev-Private[*].id
  target_group_arns = [aws_lb_target_group.Dev-TG.arn]
  launch_template {
    id = aws_launch_template.Dev-EC2.id
    version = "$Latest"
  
}
}

resource  "aws_vpc_endpoint" "S3-Dev" {
  vpc_id = aws_vpc.VPC-Dev.id
  service_name = "com.amazonaws.us-east-1.s3"
  route_table_ids = aws_route_table.Private-Dev-Route[*].id
  
}

