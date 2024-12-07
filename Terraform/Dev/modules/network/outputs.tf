output "vpc_id" {
  value = "aws_vpc.customvpc.id"
}

output "public_subnet_id_1" {
  value = aws_subnet.pub_sub_az1.id
}

output "public_subnet_id_2" {
  value = aws_subnet.pub_sub_az2.id
}

output "private_subnet_id_1_az1" {
  value = aws_subnet.priv_sub1_az1.id
}

output "private_subnet_id_1_az2" {
  value = aws_subnet.priv_sub1_az2.id
}

output "private_subnet_id_2_az1" {
  value = aws_subnet.priv_sub2_az1.id
}

output "private_subnet_id_2_az2" {
  value = aws_subnet.priv_sub2_az2.id
}

output "app_security_group_id" {
  value = aws_security_group.app_security_group.id
}

