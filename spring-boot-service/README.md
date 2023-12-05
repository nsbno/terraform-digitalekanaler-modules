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
  environment  = local.environment

  use_spot = var.environment != "prod"

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

  environment_variables = {
    APP_PORT       = tostring(local.application_port)
    DATASOURCE_URL = local.database_url
  }

  environment_secrets = {
    OAUTH2_CLIENT_SECRET = aws_ssm_parameter.oauth2_client_secret.arn
  }
}
```

## How we determined the CPU and memory limits for the containers

The reason we want to set CPU and memory limits for the application container, log-router and datadog-agent is that fargate will distribute resources evenly if we do not. The trade off that is hard to determine is which of the containers we prioritze. On the one hand, we do not want the log-router and datadog-agent to use resources that our application needs to run. However, in the situations where we run out of resources, we need logs and metrics to determine the cause and prevent it from happening again.

We have decided the following:
- We set the soft limit for memory on the log-router and datadog-agent. If we run short on memory in the task, docker attempts to keep the container to the soft limit. It also allows the container to use more than the limit if there is unused memory in the task.
- We do not set the hard limit for memory. Docker will kill the container if it uses more memory than the hard limit. And we do not want this to happen in the majority of cases.
- We do not set the memory limits for the application container as it will use the remaining memory that is available.
- We set CPU limit for all containers because it acts similar to the memory soft limit and Fargate will distribute the units evenly if we do not.
- To set the actual values, we inspected the `ecs.fargate.cpu.percent` and `ecs.fargate.mem.usage` metrics that are available in Datadog.
- [The AWS ContainerDefinition documentation](https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_ContainerDefinition.html)
