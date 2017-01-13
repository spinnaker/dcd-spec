# dcd-spec

A rough POC of how declarative continuous delivery in Spinnaker could
look.

**WIP: Still working on this README**

* Concrete examples can be seen in the [examples](examples/) directory.
* The [scratch-pad](scratch-pad) directory is just rough scribblings if you're
  curious. The main concepts will wind up distilled into this readme.

# YAML syntax note

While this repo is using YAML formatting, the actual protocol will use JSON
for transport. If templates and configurations are written in YAML, they will
need to be converted to JSON prior to being sent to Orca.

YAML was chosen for this spec because it's easier to write / grok.

# key concepts

* DCD is split into Templates and Configurations. Templates can inherit
  and decorate parent templates. Configurations are concrete implementations
  of one or more Templates.
* Composability of Templates are done through modules. Configurations can
  configure a module, or entirely replace modules if they don't fit.
* Templates can use handlebars template syntax (within strings only) for
  better flow control.
* Configurations can inject new stages or groups of stages into the final
  pipeline graph with keywords `before`, `after`, `first` and `last`.

# handlebars templating & render lifecycle

For greater control over templates, handlebars is offered within string values
of templates. handlebars templating is only allowed in string values so that the
JSON transport can always be valid. The results of a handlebars template can and
often will result in non-string values (even object graphs).

Given a Configuration JSON, Orca will resolve all parent templates, then iterate
each one with the Configuration values, rendering all discovered handlebars templates
in string values. Once all templates have been rendered, Orca will merge them
together for the final pipeline configuration validation & execution.

# template and configuration schemas

Templates and Configuration schemas feel pretty similar, but do have
some minor differences. Configurations are expected to be the end-piece to
a series of one or more Templates.

You may notice that both Template and Configuration have a stanza named
`configuration`: This is the Pipeline configuration view when in the UI.
Configurations also have an additional stanza `inherit`. Users must
explicitly define which configurations from parent Templates they want
to import. By default, no configurations from templates are imported.

```yaml
# Template
schema: "1"
id: myTemplate
source: file://myParentTemplate.yml
variables: []
configuration:
  concurrentExecutions: {}
  triggers: []
  parameters: []
  notifications: []
  description: ""
stages: []

---
# Modules are added below the template as new documents.
```

* `schema`: A string value defining the version of the Template schema. This is a
  semver value (although honestly, we'll likely just do major increments).
* `id`: The unique identifier of the template.
* `source`: An optional field for defining the parent template to inherit from.
  If no value is assigned, the template is considered a root template.
* `variables`: An explicit list of variables used by the template. These variables
  are scoped to the template itself, and will not cascade to child templates. If
  a child template requires the same variable, it will need to be defined again in
  that template.
* `configuration`: A map of pipeline configurations. This is a 1-to-1 mapping of the
  pipeline configuration you'd see in the UI.
* `stages`: A list of stages in the pipeline.

```yaml
# Configuration
schema: "1"
id: myAppConfig
pipeline:
  application: myApp
  name: My App Pipeline
  template:
    source: file://myTemplate.yml
  variables: {}
configuration:
  inherit: []
  triggers: []
  parameters: []
  notifications: []
  description: ""

stages: []
```

* `schema`: A string value defining the version of the Configuration schema. This
  will likely be in lock-step with the Template schema version.
* `id`: The unique identifier of the configuration. (I'm not sure if we need this
  yet).
* `pipeline`: Pipeline configuration, as well as template sourcing information. The
  variables field is a flat key/value map of concrete variable values that parent 
  templates have defined. 
* `configuration`: Pipeline configuration with a 1-1 mapping as you'd see in the
  Spinnaker UI. The `inherit` field is an explicit list of keys (e.g. `triggers`,
  `parameters`) that the configuration should inherit from parent templates. By
  default, configurations do not inherit any configurations.
* `stages`: Any additional stages added to the pipeline graph.

# variables

Variables have hinted types and can be used within a template and child
templates. They require a `name`, `description` and optionally a `type`
field.

The `type` field accepts `int`, `float`, `list`, `object` and `string`.
The field is only optional if the type is `string`.

```yaml
variables:
- name: regions
  description: A list of AWS regions to deploy into
  type: list
```

# stages

A stage is directly analogous to a Pipeline stage in the UI. It is defined by
a minimum of `id`.

```yaml
- id: myBakeStage
  inject: SEE_INJECTED_DOCS_BELOW
  type: bake
  config:
    package: foo
  executionOptions:
    onStageFailure: haltEntirePipeline
    # ...
  notifications: []
  comments: ""
```

A `config` map becomes a required if a stage type is defined in `type`
(as opposed to a `module`, documented further in the `inject` section below).
The `config` map is a 1-for-1 mapping of the stage type configuration. The 
`executionOptions`, `notifications` and `comments` are universal for stages.

# modules

Modules can be referenced by template they're defined in, each other or
replaced by child templates and the configuration. At minimum, a module
must have an `id`, `usage` and `definition`.

Modules, combined with handlebars templating can be powerful for looping
over similar template blocks, as well as swapping cloud provider functionality
from a common, standard template.

* `id` is used for referencing across templates. If child templates also 
  define a module for the same `id`, the child template's module will 
  take precedence.
* `usage` is templating-only usage documentation. It is a required field.
* `definition` is the templating value. It can be any data type and its
  value will be injected wherever the module is called.
* `variables` *(optional)* are used to define any variables that the
  module needs injected into it.

```yaml
# Modules MUST be separate documents in YAML.
---
id: deployClusterAws
usage: Defines a deploy stage cluster using the AWS cloud provider
variables:
- name: region
  description: The AWS region to deploy into
definition:
  provider: aws
  account: mgmt
  region: "{{ region }}"
```

```yaml
# Template snippet
id: myExampleTemplate
variables:
- name: regions
  description: A list of AWS regions to deploy into
  type: list
stages:
- id: deploy
  type: deploy
  config:
    clusters: |
      {{#each regions}}
      - {{module deployClusterAws region=value }}
      {{/regions}}
```

# injection

A Configuration can make final mutations to the pipeline graph defined
in parent Templates. Stage injection can be done either at a singular
stage level, or as a collection of stages via a module.

The `inject` stanza can take the following:

```yaml
inject:
  before: "{type.type_id}"
  after: "{type.type_id}"
  first: true|false
  last: true|false

# formatting:
type: stage|module
```

```yaml
# Single stage
id: myApp
pipeline:
  template:
    # This template defines a pipeline "bake" -> "deploy" (these are ids,
    # as well as the stage type).
    source: spinnaker://myPipelineTemplate
stages:
# We want to add a manualJudgement stage to propagate authentication
- id: manualJudgement
  type: manualJudgement
  inject:
    before: stage.deploy
  config:
    propagateAuthentication: true
    notifications:
    - type: slack
      channel: "#det"
      when:
      - awaiting
```

```yaml
# Module
id: myApp
pipeline:
  template:
    source: spinnaker://myPipelineTemplate
stages:
- id: injectedStages
  inject:
    before: module.multipleStages

---
id: multipleStages
usage: Pretend this has multiple stages
definition:
- id: one
  type: wait
- id: two
  type: wait
  dependsOn: one
```
