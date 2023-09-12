# Common module for the microservices at Vy Digital

This terraform module contains the basic infrastructure needed for a microservice to run at `www.vy.no/services/microservice-name`. It requires a Java-based application (we have only tested it with spring boot applications). This is mostly because of Datadog-related configuration.

The infrastructure you get from this module is:
- Your docker image running with Fargate in our ECS cluster
- An integration in our internal load balancer. This is where the API gateway will be pointing and it makes your application avaliable at `application_name.internal.alb.[stage|test].digitalekanaler.vydev.io` for the other microservices.
- An integration in our API gateway
- Basic logging and tracing in Datadog
- SSM Parameters for the secrets that you set with the `environment_secrets` parameters

## Example

The terraform file structure in a microservice typically looks like this:

```
/terraform
  /test
    ...
  /stage
    main.tf
  /prod
    ...
  /template
    main.tf
```

Each environment has a `main.tf` where you set up your terraform state, provider versions and such. Then you refer to your `template/main.tf` where you have all the infrastructure code that you want to be replicated across the environments. This is where you would put the `microservice` module:

```hcl
module "microservice" {
  source = "/terraform-digitalekanaler-modules/microservice"

  application_name                 = var.application_name
  environment                      = var.environment
  port_number                      = local.application_port
  min_number_of_instances          = var.min_capacity
  max_number_of_instances          = var.max_capacity
  datadog_version_tag              = local.docker_image_tag
  docker_image                     = local.docker_image
  public_load_balancer_domain_name = aws_route53_record.vy_no_record.name

  # Environment variables that are not sensitive
  environment_variables = {
    APP_PORT                = tostring(local.application_port)
    SPRING_PROFILES_ACTIVE  = var.environment
  }

  # Secrets available in terraform can be set directly
  environment_secrets = {
    DATASOURCE_USERNAME = random_string.rds_username.result
    DATASOURCE_PASSWORD = random_string.rds_password.result
  }

  # Secrets that you want to set manually must be set through SSM Parameter Store
  manual_environment_secrets = {
    ENTUR_KAFKA_PASSWORD = "/config/${var.application_name}/entur/kafka/password"
    NOD_PASSWORD         = "/config/${var.application_name}/nod/password"
    NOD_SOAP_PASSWORD    = "/config/${var.application_name}/nod/soap_password"
  }

  # References to external secrets from SSM Parameter Store
  external_environment_secrets = {
    ADYEN_API_KEY    = "/external/adyen/apikey"
    ADYEN_CLIENT_KEY = "/external/adyen/client-key"
    ADYEN_PUBLIC_KEY = "/external/adyen/public-key"
  }
}
```

## How to change or delete parameters defined in `manual_environment_secrets`

To avoid deleting the SSM Parameters created by `manual_environment_secrets` by accident, the `prevent_destroy` flag is set on these resource. This means that we must take some extra steps when changing or deleting them.

To change the name of a parameter, add something similar to this to your terraform code:

```hcl
moved {
  from = module.microservice.aws_ssm_parameter.manual_environment_secrets["OLD_NAME"]
  to   = module.microservice.aws_ssm_parameter.manual_environment_secrets["NEW_NAME"]
}
```

To remove a parameter, you must first move the SSM Parameter to a terraform resource that does not have delete protection, then remove it in a later deploy:

```hcl
resource "aws_ssm_parameter" "delete_me" {
  name  = "/config/${var.application_name}/delete_me"
  type  = "String"
  value = "null"
}

moved {
  from = module.microservice.aws_ssm_parameter.manual_environment_secrets["SOME_PARAMETER"]
  to   = aws_ssm_parameter.delete_me
}
```

