provider "aws" {
  region = "us-west-2"
}

variables {
  environment = "test"
}

run "verify_parameter_store_structure" {
  command = plan

  assert {
    condition     = length(aws_ssm_parameter.morpheus_endpoints) == 5
    error_message = "Expected 5 endpoint parameters to be created"
  }

  assert {
    condition     = length(aws_ssm_parameter.morpheus_config) == 4
    error_message = "Expected 4 configuration parameters to be created"
  }
}

run "verify_secrets_structure" {
  command = plan

  assert {
    condition     = length(aws_secretsmanager_secret.morpheus_db) == 1
    error_message = "Database credentials secret not created"
  }

  assert {
    condition     = length(aws_secretsmanager_secret.morpheus_rabbitmq) == 1
    error_message = "RabbitMQ credentials secret not created"
  }
}

run "verify_parameter_paths" {
  command = plan

  assert {
    condition     = contains(keys(aws_ssm_parameter.morpheus_endpoints), "aurora")
    error_message = "Aurora endpoint parameter missing"
  }

  assert {
    condition     = contains(keys(aws_ssm_parameter.morpheus_endpoints), "rabbitmq")
    error_message = "RabbitMQ endpoint parameter missing"
  }

  assert {
    condition     = contains(keys(aws_ssm_parameter.morpheus_endpoints), "opensearch")
    error_message = "OpenSearch endpoint parameter missing"
  }

  assert {
    condition     = contains(keys(aws_ssm_parameter.morpheus_config), "app_url")
    error_message = "Application URL parameter missing"
  }
}
