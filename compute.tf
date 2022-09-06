resource "random_id" "random_ec2" {
  byte_length = 3
  count       = var.main_instance_count
}

data "aws_ami" "server_ami" {
  most_recent = true

  owners = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}


resource "aws_instance" "mtc_main" {
  count                  = var.main_instance_count
  instance_type          = var.main_instance_type
  ami                    = data.aws_ami.server_ami.id
  key_name               = aws_key_pair.mtc_auth.id
  vpc_security_group_ids = [aws_security_group.mtc_sg.id]
  subnet_id              = aws_subnet.mtc_public_subnet[count.index].id
  availability_zone      = local.azs[count.index]
  user_data              = templatefile("./main-userdata.tpl", { new_hostname = "mtc-main-${random_id.random_ec2[count.index].dec}" })


  root_block_device {
    volume_size = var.main_vol_size
  }

  tags = {
    Name = "mtc-main -${random_id.random_ec2[count.index].dec}"
  }

  provisioner "local-exec" {
    command = "printf '\n${self.public_ip}' >> aws_hosts"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "sed -i '' '/^[1-9]/d' aws_hosts" #Extra single quotes added because mac osx uses bsd version of sed
  }

}

resource "aws_key_pair" "mtc_auth" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)

}

# resource "null_resource" "grafana_update" {
#   count = var.main_instance_count
#   provisioner "remote-exec" {
#     inline = ["sudo apt upgrade -y grafana && touch upgrade.log && echo 'I updated grafana' >> upgrade.log"]

#     connection {
#       type        = "ssh"
#       user        = "ubuntu"
#       private_key = file("/Users/bdods/Training/transible/mtckey")
#       host        = aws_instance.mtc_main[count.index].public_ip
#     }
#   }
# }

