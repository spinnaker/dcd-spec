# example: template-inheritance

This example showcases a two different features:

1. Template inheritance; allowing a chain of pipeline templates that build on
   each other.
2. Template configuration adding another stage, injecting it inbetween stages
   defined in the templates.

Here's an outline of the generated stage graph, including which template each
stage comes from:

* Find Image (root.template.yml)
* Deploy (root.template.yml)
* Run Integration Tests (inheritance.config.yml)
* Wait (child.template.yml)
* Scale Down Previous Clusters (child.template.yml)

## use case

This is an over-simplified hypothetical use case, but it should paint a decent
picture of inheritance & stage injection.

Your company has a central team charged with defining and enforcing best 
practices across all deployments for your engineering organization. As a result,
they create a root pipeline template that defines a basic structure for
promoting an application from the test environment into production.

You are part of a team in the engineering organization with a few different 
services that need a couple additional stages run post-deployment to handle 
shrinking your clusters gradually, so you extend the root template and target
a couple extra stages after the root template's deploy stage.

Finally, one special application - spindemo - requires some integration tests
run immediately after deploy, but before you scale down your old server groups.
This gets defined in that application's template configuration, which sources
your team's child template.
