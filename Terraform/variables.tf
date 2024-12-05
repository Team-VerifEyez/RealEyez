#declare variables 
# variable aws_access_key{
#     type=string
#     sensitive=true #meaning its value will be hidden in Terraform's output, logs, and state files

# } 

variable aws_secret_key{
    sensitive=true
}        # Replace with your AWS secret access key (leave empty if using IAM roles or env vars)

# variable region{
#     default = "us-east-1"
# }

# variable instance_type{
#     default = "t3.micro"
# }
