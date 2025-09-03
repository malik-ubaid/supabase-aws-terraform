region       = "eu-west-1"
environment  = "development"
project_name = "supabase"

vpc_cidr           = "10.100.0.0/16"
availability_zones = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]

public_subnet_cidrs = [
  "10.100.1.0/24",
  "10.100.2.0/24", 
  "10.100.3.0/24"
]

eks_subnet_cidrs = [
  "10.100.10.0/24",
  "10.100.11.0/24",
  "10.100.12.0/24"
]

rds_subnet_cidrs = [
  "10.100.20.0/24",
  "10.100.21.0/24",
  "10.100.22.0/24"
]