# terraform-digitalekanaler-modules

A collection of terraform modules used to set up some our internal infrastructure at Vy Digital.

## Modules

- apigw-proxy
- cognito-app-client
- cognito-resource-server
- microservice-apigw-proxy
- [spring-boot-service](./spring-boot-service/README.md) - Common infrastructure that you need to run a backend service.

## Release

This library is configured to release automatically by with GitHub Actions. PR title, and the final commit message after squash and merge, _must_ include one of the following tags:

- [skip ci] -> the commit will not be picked up by CircleCi and no release will be made
- [patch] -> the commit does not add functionality, and does not break existing functionality
- [minor] -> the commit adds new functionality without breaking existing functionality
- [major] -> the commit breaks existing functionality

The tag will decide which version this library will be released at. Read more about semantic
versioning [here](https://semver.org/).

