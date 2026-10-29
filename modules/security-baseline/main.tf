# ---------------------------------------------------------------
# Account-wide security baseline:
#   - CloudTrail: an audit log of every API call in the account
#   - AWS Config: records resource settings and checks them
#     against compliance rules
# Both write to one encrypted, private "security logs" bucket.
# ---------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

locals {
  name       = "${var.project}-security"
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  partition  = data.aws_partition.current.partition

  trail_name = "${var.project}-trail"
  # Built as a string (not a reference) to avoid a dependency loop
  # between the trail, the bucket policy and the key policy
  trail_arn = "arn:${local.partition}:cloudtrail:${local.region}:${local.account_id}:trail/${local.trail_name}"
}
