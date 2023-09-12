# Common module for the microservices at Vy Digital

## How to change or delete parameters defined in `manual_environment_secrets`

To avoid deleting the SSM Parameters created by `manual_environment_secrets` by accident, the `prevent_destroy` flag is set on these resource. This means that we must take some extra steps when changing or deleting them.

To change the name of a parameter, add something similar to this:

```hcl
moved {
  from = module.microservice.aws_ssm_parameter.manual_environment_secrets["OLD_NAME"]
  to   = module.microservice.aws_ssm_parameter.manual_environment_secrets["NEW_NAME"]
}
```

To remove a parameter, you must first move the SSM Parameter to a terraform resource that does not have delete protection, then remove it in a later deploy.

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
