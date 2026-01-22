terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# กำหนด Region เป็นสิงคโปร์
provider "aws" {
  region = "ap-southeast-1"
}

# 1. ค้นหา Ubuntu 22.04 เวอร์ชันล่าสุด (AMI)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (เจ้าของ Ubuntu)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# 2. สร้าง Key Pair (เพื่อให้เรา SSH เข้าไปได้)
resource "aws_key_pair" "deployer" {
  key_name   = "terraform-shoe-shop-key"
  public_key = file("~/.ssh/id_rsa.pub") # ⚠️ ต้องมีไฟล์นี้ในเครื่องคุณ (เหมือนบทที่แล้ว)
}

# 3. สร้าง Security Group (Firewall) **สำคัญมากใน AWS**
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow Web 8080 and SSH inbound traffic"

  # เปิด Port 8080 (App ร้านรองเท้า)
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # เปิดให้คนทั้งโลกเข้า
  }

  # เปิด Port 22 (SSH)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ขาออก (Egress) ปล่อยหมด เพื่อให้ Server โหลดของได้
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 4. สร้าง Server (EC2 Instance)
resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro" # หรือ t2.micro (Free Tier Eligible)
  key_name      = aws_key_pair.deployer.key_name
  
  # ผูก Security Group
  vpc_security_group_ids = [aws_security_group.allow_web.id]

  # 🔥 สคริปต์ติดตั้ง (User Data) - AWS Ubuntu ไม่มี Docker มาให้ ต้องลงเอง
  user_data = <<-EOF
              #!/bin/bash
              # อัปเดตและติดตั้ง Docker
              apt-get update
              apt-get install -y docker.io docker-compose-v2 git

              # เริ่ม Docker
              systemctl start docker
              systemctl enable docker
              
              # สร้างโฟลเดอร์ทำงาน
              mkdir -p /app
              cd /app
              
              # ดึงโค้ด (⚠️ แก้ YOUR_NAME เป็นชื่อ GitHub คุณ)
              git clone https://github.com/YOUR_NAME/rust-shoe-shop.git .
              
              # รัน App (ใช้ docker compose แบบใหม่)
              docker compose up -d --build

              # รอแป๊บ แล้วยัดข้อมูล (Seed Data)
              sleep 40
              docker exec -i shoe-shop-db psql -U postgres -c "CREATE TABLE IF NOT EXISTS users (id SERIAL PRIMARY KEY, username VARCHAR(50) UNIQUE NOT NULL, password VARCHAR(50) NOT NULL); CREATE TABLE IF NOT EXISTS orders (id SERIAL PRIMARY KEY, item_name VARCHAR(100) NOT NULL, price INT NOT NULL, sold_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP); INSERT INTO users (username, password) VALUES ('admin', '1234') ON CONFLICT (username) DO NOTHING;"
              EOF

  tags = {
    Name = "ShoeShopServer"
  }
}

# ปริ้น IP ออกมา
output "server_public_ip" {
  value = aws_instance.web.public_ip
}