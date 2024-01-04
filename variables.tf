variable "default_tags" {
  type        = map(string)
  description = "Map of default tags to apply to resources"

  default = {
    Project     = "tf-eks-jofo"
    Owner       = "Jovan Zelincevic"
    Compliance  = "Nothing"
    Environment = "dev"
    Provider    = "Terraform"
  }
}
