output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.networking.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.networking.public_subnet_ids
}

output "eks_private_subnet_ids" {
  description = "IDs of the EKS private subnets"
  value       = module.networking.eks_private_subnet_ids
}

output "rds_private_subnet_ids" {
  description = "IDs of the RDS private subnets"
  value       = module.networking.rds_private_subnet_ids
}

output "db_subnet_group_name" {
  description = "Name of the DB subnet group"
  value       = module.networking.db_subnet_group_name
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = module.networking.internet_gateway_id
}

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateways"
  value       = module.networking.nat_gateway_ids
}

output "availability_zones" {
  description = "List of availability zones used"
  value       = module.networking.availability_zones
}