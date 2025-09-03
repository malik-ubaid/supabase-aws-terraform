terraform {
  backend "s3" {
    bucket  = "terraform-backend-state-supabase-bucket"
    key     = "supabase/aws/ireland/development/core/core.tfstate"
    region  = "eu-west-1"
    encrypt = true
  }
}