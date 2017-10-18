# Inheriting Configuration from a Template

This example shows how to include configuration from your Template in your Pipeline

This enables you to define parameters, and other `configuration` items in your template and allow configs to use these blocks without redefining them

- `template.yml` shows a configuration block defined with a trigger, some parameters and `concurrentExecutions` flags defined
- `configuration-inheritance-config.yml` shows how you can include your Templates `configuration` using the `inherit` option
