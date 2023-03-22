module "proxy" {
  source = "../../"

  service_name = "simple"
  domain_name  = "simple.example.com"
  listener_arn = ""

  context_path = "/d"
}
