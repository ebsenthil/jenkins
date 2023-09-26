provider "aws" {
  region = "ap-south-1"
  }

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key  = file("~/.ssh/id_rsa.pub")
}
variable "cidr" {
  default = "10.1.0.0/16"
}

resource "aws_vpc" "sen-tf-vpc" {
  cidr_block = var.cidr
  tags =  {
  comment = "tf-test"
  name =    "sen-tf-vpc"
  }
}

resource "aws_subnet" "sen-tf-subnet" {
    vpc_id = aws_vpc.sen-tf-vpc.id
    cidr_block = "10.1.1.0/24"
    availability_zone = "ap-south-1a"

    tags = {
    comment = "tf-test"
}  
}

resource "aws_internet_gateway" "igw" {
vpc_id = aws_vpc.sen-tf-vpc.id

tags = {
comment = "tf-test"
}
}

resource "aws_route_table" "routetble" {
  vpc_id = aws_vpc.sen-tf-vpc.id

  route  {
  cidr_block    =   "0.0.0.0/0"
  gateway_id    =   aws_internet_gateway.igw.id
  }

}

resource "aws_route_table_association" "rta" {
subnet_id = aws_subnet.sen-tf-subnet.id
route_table_id = aws_route_table.routetble.id
  
}

resource "aws_security_group" "allowall-sg" {

vpc_id = aws_vpc.sen-tf-vpc.id


ingress {
    description      = "allow ssh"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]

  }

  ingress {
    description      = "allow http"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]

  }

  egress {
    description      = "allow all"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
}
}

resource "aws_instance" "sen-test-vm" {
  instance_type = "t2.micro"
  ami = "ami-05552d2dcf89c9b24"
  subnet_id = aws_subnet.sen-tf-subnet.id
  key_name = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.allowall-sg.id]
  associate_public_ip_address = "true"

  connection {
    type  = "ssh"
    user = "ec2-user"
    private_key = file("~/.ssh/id_rsa")
    host = self.public_ip
  }
  

provisioner "remote-exec" {
inline = [
"sudo dnf update", #To Install Latest Update
"sudo dnf install -y nginx", # Install Nginx
"sudo systemctl start nginx.service", # Start Nginx Server
"sudo chmod 777 /usr/share/nginx/html/index.html"
    ]
  }


provisioner "file" {
    source      = "index.html"
    destination = "/usr/share/nginx/html/index.html"
  }

  }
