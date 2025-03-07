resource "aws_kms_key" "morpheus" {
  description = "KMS key for Morpheus cluster encryption"
  policy      = data.aws_iam_policy_document.kms_key_policy.json
  tags        = local.tags
}

data "aws_iam_policy_document" "kms_key_policy" {
  # Root account access
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  # Parameter Store access
  statement {
    sid    = "Allow Parameter Store Encryption"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [module.cluster.instance_role_arn]
    }
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["ssm.${data.aws_region.current.name}.amazonaws.com"]
    }
  }

  # Secrets Manager access
  statement {
    sid    = "Allow Secrets Manager Encryption"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [module.cluster.instance_role_arn]
    }
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["secretsmanager.${data.aws_region.current.name}.amazonaws.com"]
    }
  }

  # EFS encryption
  statement {
    sid    = "Allow EFS Encryption"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [module.cluster.instance_role_arn]
    }
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["elasticfilesystem.${data.aws_region.current.name}.amazonaws.com"]
    }
  }
}

resource "aws_kms_alias" "morpheus" {
  name          = "alias/${local.project}-${var.environment}"
  target_key_id = aws_kms_key.morpheus.key_id
}
