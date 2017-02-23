# example: conditional-stages

## use case

Without pipeline templates, conditions are evaluated at runtime for each stage.
If a stage and its child branch are conditionally not included, the pipeline
will still show all of these stages, but won't run them.

With pipeline templates, you can conditionally include or exclude entire branches
of stages before execution. In the case of an exclusion condition, at execution
time those stages won't even appear in a pipeline.

## template

The [conditionalStage.template.yml](conditionalStage.template.yml) template has
a series of deploy stages, which are either included or not based on the value
of a template variable. If this were a real pipeline, each deploy stage would
be preceeded by a Check Preconditions stage: These are no longer necessary.
