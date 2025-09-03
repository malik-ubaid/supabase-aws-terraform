locals {
  environment  = var.environment
  project_name = var.project_name
}

module "networking" {
  source = "../../../../modules/networking"

  region         = var.region
  environment    = local.environment
  project_name   = local.project_name
  
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  
  public_subnet_cidrs = var.public_subnet_cidrs
  eks_subnet_cidrs    = var.eks_subnet_cidrs
  rds_subnet_cidrs    = var.rds_subnet_cidrs
  
  enable_dns_hostnames = true
  enable_dns_support   = true
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_flow_logs     = true
  
  tags = {
    Owner = "Platform Team"
    Cost  = "Shared"
  }
}