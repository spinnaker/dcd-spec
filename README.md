# dcd-spec

A living document of my proposed Spinnaker DCD config language. It's still early 
design / POC. The initial implementation of this document can be found in the
[orca-pipelinetemplate](https://github.com/spinnaker/orca/tree/master/orca-pipelinetemplate)
module.

You can find concrete examples in the [examples](examples) directory.
  
## toc

   * [dcd-spec](#dcd-spec)
      * [toc](#toc)
   * [YAML syntax note](#yaml-syntax-note)
   * [key concepts](#key-concepts)
   * [jinja templating](#jinja-templating)
   * [lifecycle](#lifecycle)
   * [template and configuration schemas](#template-and-configuration-schemas)
   * [variables](#variables)
   * [stages](#stages)
   * [modules](#modules)
   * [injection](#injection)
   * [inheritance control](#inheritance-control)
   * [extensions](#extensions)
   * [todo](#todo)

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
* Templates can use Jinja template syntax (within strings only) for
  better flow control.
* Configurations can inject new stages or groups of stages into the final
  pipeline graph with keywords `before`, `after`, `first` and `last`.

# jinja templating

For greater control over templates, jinjava (Java implementation of Jinja) is
offered within (most) string values of templates. Jinja templating is only
allowed in string values, so that the JSON transport can always be valid. The
results of Jinja templates can and often will result in non-string values (even
object graphs).

For more information about what's possible with Jinja, and specifically jinjava:

* https://github.com/HubSpot/jinjava
* http://jinja.pocoo.org/docs/2.9/ (Python implementation; good reference)

Jinja is supported at the following levels:

* Stage & module `when` stanzas
* Module `definition` stanza (or any nested value inside)
* Stage `config` stanza (or any nested value inside)

**IMPORTANT**: If your Jinja template is intended to return a list, map or
object graph, you must ensure the output is *valid JSON*. We do plan to support
outputting YAML in the future.

# lifecycle

Setting up and using a pipeline template is two part:

1. Create the template and save it to your template source (e.g. local file,
   S3, Spinnaker, git, etc.)
2. Create a configuration and POST it into Orca. The configuration has all of
   the concrete parameters required for a fully-formed pipeline configuration.

Internally, when applying a configuration to a pipeline template, the following
lifecycle occurs:

1. All template sources are recursively resolved based on the source provided 
   in the configuration.
2. All templates are flattened together; all conflict resolutions are performed
   using last-entry wins; so the top-most (closest to configuration) template
   will overwrite elements in a template lower in the stack.
3. The template stage graph is iterated over recursively and any discovered
   Jinja templates are rendered and expanded, using the configuration for
   parameterization of template values.
4. Final mutations occur to satisfy spec semantics (e.g. injection, validation, 
   etc.)
5. Pipeline template is transformed to standard Orca pipeline configuration.

# template and configuration schemas

Templates and Configuration schemas feel pretty similar, but do have some 
important differences. Configurations are expected to be the end-piece to a 
series of one or more Templates.

You may notice that both Template and Configuration have a stanza named
`configuration`: This is the Pipeline configuration view when in the UI.
Configurations also have an additional stanza `inherit`: Users must explicitly 
define which configurations from parent Templates they want to import. 
By default, no configurations from templates are imported.

```yaml
# Template
schema: "1"
id: myTemplate
source: https://example.com/myParentTemplate.yml
protect: true|false
metadata:
  name: Default Bake & Tag
  description: A generic application bake & tag pipeline.
  owner: example@example.com
variables: []
configuration:
  concurrentExecutions: {}
  triggers: []
  parameters: []
  notifications: []
  description: ""
stages: []
modules: []
```

* `schema`: A string value defining the version of the Template schema. This is 
  a semver value (although honestly, we'll likely just do major increments).
* `id`: The unique identifier of the template.
* `source`: An optional field for defining the parent template to inherit from.
  If no value is assigned, the template is considered a root template.
* `protect`: A flag (defaults false) to control whether or not configurations
  can change or mutate the template's defined stage graph at plan/exec time. 
  Side effects of template variables are not included in this protection.
* `metadata`: A map of additional metadata used for rendering templates in the
  UI. While not strictly necessary, it can be helpful for discovery.
* `variables`: An explicit list of variables used by the template. Variables are
  flatted together when multiple templates are inherited.
* `configuration`: A map of pipeline configurations. This is a 1-to-1 mapping of 
  the pipeline configuration you'd see in the UI.
* `stages`: A list of stages in the pipeline.
* `modules`: A list of modules available to the pipeline.

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
modules: []
```

* `schema`: A string value defining the version of the Configuration schema. 
  This will likely be in lock-step with the Template schema version.
* `id`: The unique identifier of the configuration. (I'm not sure if we need 
  this yet).
* `pipeline`: Pipeline configuration, as well as template sourcing information. 
  The variables field is a flat key/value map of concrete variable values that 
  parent templates have defined. 
* `configuration`: Pipeline configuration with a 1-1 mapping as you'd see in the
  Spinnaker UI. The `inherit` field is an explicit list of keys (e.g. `triggers`,
  `parameters`) that the configuration should inherit from parent templates. By
  default, configurations do not inherit any configurations.
* `stages`: Any additional stages added to the pipeline graph.
* `modules`: A list of modules available to the pipeline.

# variables

Variables have hinted types and can be used within a template and child
templates. They require a `name`, `description` and optionally `type` and
`defaultValue` fields.

The `type` field accepts `int`, `float`, `list`, `object` and `string`.
The field is only optional if the type is `string`.

```yaml
variables:
- name: regions
  description: A list of AWS regions to deploy into
  type: list
  defaultValue: ['us-east-1', 'us-west-2']
```

# stages

A stage is directly analogous to a Pipeline stage in the UI. It is defined by a 
minimum of `id`, `type` and `config`.

```yaml
- id: myBakeStage
  dependsOn: 
  - myParentStage
  inject: SEE_INJECTED_DOCS_BELOW
  type: bake
  config:
    package: foo
  executionOptions:
    onStageFailure: haltEntirePipeline
    # ...
  notifications: []
  comments: ""
  when:
  - "{{ appSupportsBake == 'myAppName' }}
```

The `config` map is a 1-for-1 mapping of the stage type configuration. The 
`executionOptions`, `notifications`, `comments` and `when` are applicable to 
any stage type.

## dependencies

To create a Pipeline consisting of a series of stages, the stage definition 
has the concept of `dependsOn`, which takes a list of stage IDs, as well as the
`inject` stanza (covered later). In most cases, `dependsOn` is all you'll need
to perform standard branch forking and joining operations.

## conditional stages

You will note the final stanza above is `when`, which takes a list of Jinja
expressions that are evaluated together as `AND`. This allows you to include
or exclude stages based on variables.

# modules

Modules can be referenced by each other, the template they're defined in, in 
child templates and replaced by child templates and the configuration. At 
minimum, a module must have an `id`, `usage` and `definition`.

Modules, combined with Jinja templating can be powerful for looping over 
similar template blocks, as well as swapping cloud provider functionality from 
a common, standard template.

* `id` is used for referencing across templates. If child templates also define 
  a module for the same `id`, the child template's module will take precedence.
* `usage` is templating-only usage documentation. It is a required field.
* `definition` is the templating value. It can be any data type and its value 
  will be injected wherever the module is called.
* `variables` *(optional)* are used to define any variables that the module 
  needs injected into it.

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
    clusters: |-
      [
      {% for region in regions %}
        {% module deployClusterAws region=region %}{% if not loop.last %},{% endif %}
      {% endfor %}
      ]

modules:
- id: deployClusterAws
  usage: Defines a deploy stage cluster using the AWS cloud provider
  variables:
  - name: region
    description: The AWS region to deploy into
  when: 
  - "{{ region != 'ap-northeast-1' }}"
  definition: |-
    {
      "provider": "aws",
      "account": "myAccount",
      "region": "{{ region }}"
    }
```

Modules may be used anywhere Jinja expressions are supported, and can 
output as little or as much data as necessary. Combined with configuration-level
module overriding, this offers a considerable amount of options for 
extensibility.

# injection

A child Template or Configuration can make mutations to the pipeline graph 
defined in parent Templates.

Injecting a stage after one that has multiple children stages will have all
children reassigned to the parent stage. This is not for adding a stage as a
child & sibling to other stages: Use `dependsOn` for that use case. You can
consider injection a nuclear option for stage graph manipulation.

```
# "inject after target" behavior
Target --> 1..* Children
Target --> Injected --> 1..* Children
```

The `inject` stanza can take the following:

```yaml
inject:
  before: "{stage_id}"
  after: "{stage_id}"
  first: true|false
  last: true|false
```

```yaml
# Config: Single-stage injection
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
    before: deploy
  config:
    propagateAuthentication: true
    notifications:
    - type: slack
      channel: "#spinnaker"
      when:
      - awaiting
```

# inheritance control

In some cases, you want to inherit a stage, but need to make limited,
un-templated changes to it. Stages support the inclusion of an
`inheritanceControl` stanza which allows for more powerful expressions in
modifying nested list elements or maps. Inheritance control has three different
control methods, all of which require a `path` selector. The path selector
uses JSONPath.

* `merge`: Merge maps together or append to lists.
* `replace`: Replace an object with a new object at a path.
* `remove`: Removes an object from the path.

In this example, the template defines a deploy stage that assumes a collection
of "paved road" ports on a load balancer. The application you're building
pipelines for fits this template perfectly, but you just need to modify the 
listeners.

This is a very advanced feature. If you find yourself having to use this
pattern often, you should strongly consider if you can approach the templating
problems you have differently.

```yaml
# Template
id: myTemplate
stages:
- id: deploy
  type: deploy
  config:
    clusters:
    - provider: aws
      loadBalancers:
      - instancePort: 80
        instanceProtocol: "http"
        lbPort: 80
        lbProtocol: "http"
      - instancePort: 8443
        instanceProtocol: "https"
        lbPort: 8443
        lbProtocol: "https"
```

```yaml
# Configuration
id: myApp
stages:
- id: deploy
  type: deploy
  inheritanceControl:
    merge:
    - path: $.clusters[?(@.provider=aws)].loadBalancers
      value:
        instancePort: 9000
        instanceProtocol: http
        lbPort: 9000
        lbProtocol: http
    replace:
    - path: $.clusters[?(@.provider=aws)].loadBalancers[?(@.instancePort==80)]
      value:
        instancePort: 8080
        instanceProtocol: http
        lbPort: 80
        lbProtocol: http
    remove:
    - path: $.clusters[?(@.provider==aws)].loadBalancers[?(@.instancePort==8443)]
```

The result would become:

```yaml
# Template
id: myTemplate
stages:
- id: deploy
  type: deploy
  config:
    clusters:
    - provider: aws
      loadBalancers:
      - instancePort: 8080
        instanceProtocol: http
        lbPort: 80
        lbProtocol: http
      - instancePort: 9000
        instanceProtocol: http
        lbPort: 9000
        lbProtocol: http
```

# extensions

The concept of deployment models, where you can provide more advanced
topology inheritance as variables is being provided as an extension to
the dcd-spec. You can think of the spec outlined above as the primitives
that fancier DSLs can be built upon.

# todo

Additional features that haven't been tackled yet:

* Stage looping. Need a way to loop over individual stages given a variable.
  I hesitate to add a `with_items` concept like what Ansible has, but can't
  yet think of a better solution. It's easy enough to put a stage's definition
  into a module, then define the repeated stages manually.
* YAML Jinja output
* Fully formed, public templates in spinnaker-templates repo
