data "aws_region" "current" {}

# get list of available availability zones
data "aws_availability_zones" "available" {
  state = "available"
}
