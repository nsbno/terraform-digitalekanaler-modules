# spring-boot-service

The spring-boot-service terraform module has the basic infrastructure that you need to run a backend service at Vy Digital.

What you get from the module:

- Your docker image with a spring application running in our ECS cluster
- Load balancer and API gateway integrations such that your service is available at `/services/application_name` (for our end-users) and at `application_name.internal.alb.digitalekanaler.vydev.io` (for internal traffic from other services)
- Autoscaling
- Monitoring of your service in Datadog
- A KMS key that you can use for application specific encryption (mostly used for SSM parameters)

## Example

```hcl
locals {
  application_name = "" # TODO
  application_port = 8080
  commit_sha       = "" # TODO
  database_url     = "" # TODO
  docker_image     = "" # TODO
  environment      = "prod"
}

module "spring_boot_service" {
  source = "github.com/nsbno/terraform-digitalekanaler-modules//spring-boot-service?ref=x.y.z"

  name         = local.application_name
  port         = local.application_port
  docker_image = local.docker_image

  # These settings should not be the same in test, stage and prod. Set lower
  # values for test and stage to save money.
  autoscaling = {
    min_number_of_instances = 3
    max_number_of_instances = 6
  }

  datadog_tags = {
    environment = local.environment
    version     = local.commit_sha
  }

  environment = {
    APP_PORT       = tostring(local.application_port)
    DATASOURCE_URL = local.database_url
  }

  secrets = {
    OAUTH2_CLIENT_SECRET = aws_ssm_parameter.oauth2_client_secret.arn
  }
}
```
