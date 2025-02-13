// Creating VPC
resource "aws_vpc" "mainvpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "vpc_1"
  }
}

//Creating Subnet1
resource "aws_subnet" "sub1" {
  vpc_id     = aws_vpc.mainvpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-2a"
  map_public_ip_on_launch = true
  
  tags = {
    Name = "Subnet1"
  }
}

//Creating Subnet 2
resource "aws_subnet" "sub2" {
  vpc_id     = aws_vpc.mainvpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-2b"
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet2"
  }
}

//Creating Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.mainvpc.id

  tags = {
    Name = "IGW"
  }
}

//Creating Route table
resource "aws_route_table" "RTable1" {
  vpc_id = aws_vpc.mainvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "Route_Table_Tf"
  }
}

//Creating route table association for subnet1
resource "aws_route_table_association" "rtasub1" {
  subnet_id      = aws_subnet.sub1.id
  route_table_id = aws_route_table.RTable1.id
}

//Creating route table association for subnet2
resource "aws_route_table_association" "rtasub2" {
  subnet_id      = aws_subnet.sub2.id
  route_table_id = aws_route_table.RTable1.id
}

//Creating S3 bucket
resource "aws_s3_bucket" "s3bucket" {
  bucket = "reesasabu-terraform-2025"
}

//Creating Security Group
resource "aws_security_group" "secgroup" {
  name        = "SecurityGroup1"
  description = "For creating EC2 instances"
  vpc_id      = aws_vpc.mainvpc.id

  ingress {
    description  = "This is for HTTP"
    //self      = true
    from_port = 80
    to_port   = 80
    protocol="tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 ingress {
    description  = "This is for SSH"
    //self      = true
    from_port = 22
    to_port   = 22
    protocol="tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

//Creating EC2 Instance - Instance1
resource "aws_instance" "Instance1" {
  ami                     = "ami-088b41ffb0933423f"
  instance_type           = "t2.micro"
  vpc_security_group_ids = [aws_security_group.secgroup.id]
  subnet_id = aws_subnet.sub1.id
  user_data = base64encode(file("userdata1.sh"))
  iam_instance_profile    = aws_iam_instance_profile.ec2_profile.name
}

//Creating EC2 Instance - Instance2
resource "aws_instance" "Instance2"{
  ami = "ami-088b41ffb0933423f"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.secgroup.id]
  subnet_id = aws_subnet.sub2.id
  user_data = base64encode(file("userdata2.sh"))
  iam_instance_profile    = aws_iam_instance_profile.ec2_profile.name
}

//Creating an IAM Role for EC2 

resource "aws_iam_role" "Iam_Ec2_Role" {
  name = "EC2_S3_Access_Role"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

}

//Attach an IAM Policy for S3 Access

  resource "aws_iam_policy" "s3_full_access" {
  name        = "S3FullAccess"
  description = "Allows EC2 instances full access to S3"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
       Sid     = "AllowFullS3Access"
      Effect   = "Allow"
      Action   = "s3:*" 
      Resource = "arn:aws:s3:::*"
    }]
  })
}

// Attaching IAM Policy to the Role
 
resource "aws_iam_role_policy_attachment" "attach_s3_full_access"{
  role       = aws_iam_role.Iam_Ec2_Role.name
  policy_arn = aws_iam_policy.s3_full_access.arn
}

// Creating IAM Instance Profile to Attach Role to EC2
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_instance_profile"
  role = aws_iam_role.Iam_Ec2_Role.name
}

//Creating Load balancer
resource "aws_lb" "myLoadBalancer" {
  name               = "myLoadBalancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.secgroup.id]
  subnets            = [aws_subnet.sub1.id, aws_subnet.sub2.id]

  }

//Creating Target group

resource "aws_lb_target_group" "alb-target-group" {
  name        = "alb-target-group"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.mainvpc.id

  health_check {
    path = "/"
    port = 80
    protocol = "HTTP"
    
  }
}

//Attaching Target groups to Instance1

resource "aws_lb_target_group_attachment" "tga1" {
  target_group_arn = aws_lb_target_group.alb-target-group.arn
  target_id        = aws_instance.Instance1.id
  port             = 80
}

//Attaching Target groups to Instance2

resource "aws_lb_target_group_attachment" "tga2" {
  target_group_arn = aws_lb_target_group.alb-target-group.arn
  target_id        = aws_instance.Instance2.id
  port             = 80
}


resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.myLoadBalancer.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb-target-group.arn
  }
}

terraform {
  backend "s3" {
    bucket         = "reesasabu-terraform-state"      
    key            = "terraform.tfstate"              
    region         = "us-east-2"                                   
    encrypt        = true                             
  }
}


