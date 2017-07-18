# Pipeline Templates Spec

Pipeline Templates are a means for standardizing and distributing reusable 
Pipelines within a single application, different applications or even different
Spinnaker deployments. They are the base abstraction of Pipelines and map
very closely to the Pipeline JSON configuration format that the UI generates.

*NOTE: This spec is still a WIP and may change at any time.*

For usage information, please see [ALPHA-GETTING-STARTED.md](ALPHA-GETTING-STARTED.md).

* [pipeline templates examples](https://github.com/spinnaker/pipeline-templates)
* [orca-pipelinetemplate implementation](https://github.com/spinnaker/orca/tree/master/orca-pipelinetemplate)
* [dcd-converter]()

# TOC

   * [Taxonomy](#taxonomy)
   * [Key Concepts](#key-concepts)
   * [Jinja Templating](#jinja-templating)
      * [Custom Tags &amp; Filters](#custom-tags--filters)
   * [Template &amp; Configuration Schemas](#template--configuration-schemas)
      * [Templates](#templates)
      * [Configurations](#configurations)
   * [Template Loaders](#template-loaders)
   * [Variables](#variables)
   * [Stages](#stages)
      * [Dependencies](#dependencies)
      * [Conditional Stages](#conditional-stages)
   * [Modules](#modules)
   * [Partials](#partials)
   * [Injection](#injection)
   * [Inheritance Control](#inheritance-control)
   * [FAQ](#faq)

# Taxonomy

* *Pipeline Template*: An abstract, composable definition of a Spinnaker Pipeline
* *Pipeline Configuration*: A variable-binding and user-facing configuration
  format that inherits a Pipeline Template.

# Key Concepts

* Pipeline Templates have two main components: Templates and Configurations.
  Templates can inherit and decorate parent templates. Configurations are
  concrete implementations of a Template.
* Composability of Templates are done via Modules. Configurations can configure
  a module or entirely replace modules if they don't fit.
* Templates can use Jinja expression syntax for better flow control.
* Configurations can inject new stages into the final pipeline graph and modify
  individual objects with JSONPath.

# Jinja Templating

Templates can use jinjava (Java implementation of Jinja) to offer greater
productivity while creating and using templates. Jinja templating is only
allowed in string values so that the JSON transport can always be valid. The
results of Jinja templates can and often will result in non-string values (even
object graphs).

For more information about what's possible with Jinja, and specifically jinjava:

* https://github.com/HubSpot/jinjava
* http://jinja.pocoo.org/docs/2.9/ (Python implementation; good reference)

Jinja is supported in the following areas:

* Stage & module `when` stanzas
* Module `definition` stanza (or any nested value inside)
* Stage `config` stanza (or any nested value inside)
* Stage `name` stanza
* Template `metadata` values

## Custom Tags & Filters

We're continually extending the Jinja implementation with new Tags and Filters.

* `frigga` filter: Used to parse string values and return Frigga naming
  convention substrings. `{{ "orca-main"|frigga('stack') }} == "main" }}`
* `json` filter: Output a value as a JSON object. `{{ myVar|json }}`

**IMPORTANT**: If your Jinja template is intended to return a list, map or
object graph, you must ensure the output is *valid YAML or JSON*.

# Template & Configuration Schemas

Templates and Configuration schemas feel pretty similar, but do have some
important differences. Templates, on their own, cannot be executed as pipelines.
Configurations bring the additional variable bindings and customization that
make Templates executable.

You may notice that both Template and Configuration have a stanza named 
`configuration`: This represents the Pipeline Configuration view as seen in the
UI. **NOTE:** This stanza, while defined in the spec, is not currently consumed 
by Spinnaker itself.

This section primarily gives explanations of Templates & Configurations. For
actual reference schemas, please take a look at [schemas/pipeline-templates-v1](schemas/pipeline-templates-v1).

## Templates

```yaml
schema: "1"
id: myTemplate
source: https://example.com/myParentTemplate.yml
protect: true
metadata:
  name: Default Bake & Tag
  description: A generic application bake & tag pipeline.
  owner: example@example.com
  scopes: [global]
variables: []
configuration:
  concurrentExecutions: {}
  triggers: []
  parameters: []
  notifications: []
  description: ""
stages: []
modules: []
partials: []
```

* `schema`: A string value defining the version of the Template schema, which
  will increment in major versions only.
* `id`: A globally unique identifier of the Template. This is used both by
  Templates and Configurations to reference a Template.
* `source`: An optional field for defining the parent template to inherit from.
  If no value is assigned, the template is considered a root Template.
* `protect`: A flag (defaults false) to control whether or not configurations
  can change or mutate the template's defined stage graph at plan/exec time. 
  Side effects of template variables are not included in this protection.
* `metadata`: A map of additional metadata used for rendering Templates in the
  UI. `name`, `description` and `scopes` are required.
  * `scopes`: A list of free-form strings used to group templates. For templates
     stored within Spinnaker, scopes have special meaning:
    * Users can query Spinnaker's API for templates that have a given scope or
      have a scope matching a given regex.
    * When configuring a pipeline template, Spinnaker's UI offers 
      templates that have either `global` scope or `{applicationName}` scope.
* `variables`: An explicit list of variables used by the template. Variables are
  flattened together when multiple templates are inherited.
* `configuration`: A map of pipeline configurations. This is a 1-to-1 mapping of 
  the pipeline configuration you'd see in the UI.
* `stages`: A list of stages in the pipeline.
* `modules`: A list of modules available to the pipeline.
* `partials`: A list of reusable groups of stages that can be inserted into the
  pipeline.

## Configurations

```yaml
schema: "1"
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
partials: []
```

* `schema`: A string value defining the version of the Configuration schema. 
  This will likely be in lock-step with the Template schema version.
* `pipeline`: Pipeline configuration, as well as template sourcing information. 
  The variables field is a flat key/value map of concrete variable values that 
  parent templates have defined.
  * `template`: A reference to the Template that the Configuration is applied
    against. See the Template Loaders section below for more information.
* `configuration`: Pipeline configuration with a 1-1 mapping as you'd see in the
  Spinnaker UI. The `inherit` field is an explicit list of keys (e.g. `triggers`,
  `parameters`) that the configuration should inherit from parent templates. By
  default, configurations do not inherit any configurations.
* `stages`: Any additional stages added to the pipeline graph.
* `modules`: A list of modules available to the pipeline.
* `partials`: A list of reusable groups of stages that can be inserted into the
  pipeline.

# Template Loaders

Templates can be loaded from different sources, or URI schemes:

* `file:///path/to/my/template.yml`
* `https://example.com/template.yml`
* `spinnaker://template`

The *file scheme* is offered mostly for running internal test harnesses, but it
can be used in production as well. The path will resolve to whatever filesystem
is associated to the server running `orca`.

The *http and https schemes* is useful if you want to store your templates in
a separate service, or potentially link to a Gist. It's handy for getting started,
development and easy sharing.

The *spinnaker scheme* references templates that have been saved into Spinnaker
itself (depending on how you configure Front50: Redis, S3, GCS, etc). Generally
speaking, this is the most resilient option. Templates are published into
Spinnaker using the API.

When using the *spinnaker scheme*, it's recommended to namespace your template
IDs, as they are globally unique, regardless of the scope you provide them while
publishing.

# Variables

Variables are used during the Jinja template rendering phase to build up stages.
They have optional hinted types and can be used within the Template they are
defined in, or in child Templates and Configurations. They required a `name`,
`description` and optionally `type`, `defaultValue`, `group` and `example`
fields.

The `type` field accepts:

* `string` (default)
* `int`
* `float`
* `boolean`
* `list`
* `object`

```yaml
variables:
- name: regions
  description: A list of AWS regions to deploy into. Markdown supported.
  type: list
  defaultValue:
  - us-east-1
  - us-west-2
  group: Deployment
  example: |
    Free-form text. Typical usage would be for object variable types where the
    format could be in-obvious.
```

# Stages

A Stage is directly analogous to a Pipeline Stage in the UI. It is defined by a
minimum of `id`, `type` and `config`.

Optional fields include `dependsOn`, `inject` and `when`, which are used 
for graph mutation (which we'll address later)

```yaml
stages:
- id: myBakeStage
  dependsOn: 
  - myParentStage
  inject: SEE_INJECTED_DOCS_BELOW
  name: My fancy bake stage name
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

The `config` map is a 1-for-1 mapping of the stage type configuration that you
would see looking at a stage in a Pipeline's JSON configuration.

## Dependencies

To create a Pipeline consisting of a series of Stages, the stage definition has
the concept of `dependsOn`, which takes a list of stage IDs: These are direct
parents of the stage. For more advanced control, the `inject` stanza is offered,
which will be covered later. In most cases, `dependsOn` is all you'll need to
perform standard branch fork and join operations.

## Conditional Stages

Configuring a Pipeline via the UI, you can conditionally execute stages based on
runtime information. With Pipeline Templates, you can conditionally include or
exclude entire branches of stages before the Pipeline is executed.

The `when` stanza takes a list of Jinja expressions that are evaluated together
as `AND` statements. These expressions must evaluate to a boolean value.

If a Stage is conditionally excluded, the stage graph will automatically be 
recalculated.

```yaml
stages:
- id: one
  type: wait
  config: {}
  when:
  - "{{ true }}"
- id: two
  dependsOn:
  - one
  type: wait
  config: {}
  when:
  - "{{ false }}"
- id: three
  dependsOn:
  - two
  type: wait
  config: {}

## rendered to...

stages:
- id: one
  type: wait
  config: {}
  when:
  - "{{ true }}"
- id: three
  dependsOn:
  - one
  type: wait
  config: {}
```

Conditional stages are supported within Partials as well.

# Modules

Modules can be referenced by each other, the Template they are defined in, 
child Templates and Configurations. Furthermore, they can be replaced by child
Templates and Configurations as well.

Modules, combined with Jinja templating, can be powerful for looping over
common template blocks, as well as swapping out cloud provider functionality or
conditionally including certain configuration options defined from a common
parent Template.

At minimum, a module must have an `id`, `usage` and `definition`. Optionally,
`variables` can be defined. Note, while modules can directly reference variables
defined by the Template, any variables defined by the module will be strictly
scoped to the Module only.

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
      {% for region in regions %}
      - {% module deployClusterAws region=region %}
      {% endfor %}

modules:
- id: deployClusterAws
  usage: Defines a deploy stage cluster using the AWS cloud provider
  variables:
  - name: region
    description: The AWS region to deploy into
  when: 
  - "{{ region != 'ap-northeast-1' }}"
  definition:
    provider: aws
    account: myAccount
    region: "{{ region }}"
```

Modules may be used anywhere Jinja expressions are supported, and can output as
little or as much data as necessary. Combined with configration-level module
overriding, this offers a considerable amount of options for extensibility.

# Partials

**DRAFT: This feature is either not yet implemented, or currently under test.**

For cases where you need to reuse entire parts of a Template's stage graph, such 
as a group of stages, Partials exist. This behaves similarly to Modules, but 
rather than templating a the configuration of a single stage, you can template
groups of stages together.

The goal of Partials is primarily to replace using Child Pipelines, which teams
often use to reuse common logic. The issue in using Child Pipelines is restart
functionality can be at the incorrect granularity and is often slow. More
importantly, however, is correlation of a Child Pipeline's execution is difficult
to visualize within the Pipelines UI.

Partials are a root-level element in the Template, and like modules, can be
accessed or replaced by children Templates.

A Partial has the required fields `id`, `usage` and `stages`, with an optional
field of `variables`. Just like Modules, a Partial will inherit all variables
of the Template, but variables defined within a Partial will be locally-scoped.

Once defined, a Partial is referenced within a Template's Stage list similar
to how a normal Stage would be, except with a special type `partial`. The type
value takes a format of `partial.PARTIAL_ID`, so for example, if a partial exists
with the ID `myPartial`, the `type` value would be `partial.myPartial`.

The `config` value would be setting the variable bindings of the Partial, and 
like any Stage config stanza, supports full Jinja expressions.

An example, where a Template needs to support building and publishing an artifact
targeted at different web browsers using Jenkins jobs.

```yaml
schema: '1'
id: partialsExampleTemplate
stages:
- id: firstWait
  type: wait
  config:
    waitTime: 5
- id: buildChrome
  type: partial.buildBrowser
  dependsOn:
  - firstWait
  config:
    target: chrome
- id: finalWait
  type: wait
  dependsOn:
  - buildChrome
  config:
    waitTime: 5

partials:
- id: buildBrowser
  usage: Builds the pipeline artifact targeting the a specified browser.
  variables:
  - name: target
    description: The target browser to build for
  stages:
  - id: buildTarget
    type: jenkins
    name: Build {{ target }}
    config:
      # etc...
  - id: publishTarget
    type: jenkins
    name: Publish {{ target }}
    dependsOn:
    - buildTarget
    config:
      # etc ...
```

The resultant Pipeline would look sort of like so:

```yaml
schema: '1'
id: partialsExampleTemplate
stages:
- id: firstWait
  type: wait
  config:
    waitTime: 5
- id: buildChrome.buildTarget
  type: jenkins
  dependsOn:
  - wait
  config:
    # blah
- id: buildChrome.publishTarget
  type: jenkins
  dependsOn:
  - buildChrome.buildTarget
  config:
    # blah
- id: finalWait
  type: wait
  dependsOn:
  - buildChrome.publishTarget
  config:
    waitTime: 5
```

A couple key things to note here:

1. The resultant stage graph namespaces stage IDs generated by the Partial 
   by `{{ partialId }}.{{ internalPartialStageId }}`. This ensures that the
   stage names can be uniquely referenced by injections and so-on.
2. The resultant stage graph will correctly resolve child stage `dependsOn`
   dependencies. Note that the stage `finalWait` stage only depends on 
   `buildChrome.publishTarget`, rather than every stage defined by the Partial.

# Injection

A child Template or Configuration can make mutations to the Pipeline stage
graph defined by parent Templates. Injecting a Stage will cause the stage graph
to be automatically recalcuclated.

You should consider injection an advanced option where standard `dependsOn` is
not sufficient.

```
# "inject after target" behavior
Target --> 1..* Children
Target --> Injected --> 1..* Children
```

```yaml
# Config: Single-stage injection
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
    before: 
    - deploy
  config:
    propagateAuthentication: true
    notifications:
    - type: slack
      channel: "#spinnaker"
      when:
      - awaiting
```

In the above example, `manualJudgement` will be injected into the graph before
the `deploy` stage.

The available hooks for injection are:

* `before`: List of stage IDs. 
* `after`: List of stage IDs.
* `first`: Boolean.
* `last`: Boolean.

# Inheritance Control

In some rare cases, you want to inherit a Stage, but need to make limited,
un-templated changes to it. Stages support the inclusion of an
`inheritanceControl` stanza which allows for more powerful expressions in
modifying nested list elements or maps. Inheritance control has three different
control methods, all of which require a `path` selector. The path selector
uses JSONPath.

* `merge`: Merge maps together or append to lists.
* `replace`: Replace an object with a new object at a path.
* `remove`: Removes an object from the path.

In the following example, the Template defines a deploy stage that assumes a 
collection of "paved road" ports on a load balancer. The application you're 
building pipelines for fits this template perfectly, but you just need to modify
the listeners.

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
stages:
- id: deploy
  type: deploy
  inheritanceControl:
    merge:
    - path: $.clusters[?(@.provider==aws)].loadBalancers
      value:
        instancePort: 9000
        instanceProtocol: http
        lbPort: 9000
        lbProtocol: http
    replace:
    - path: $.clusters[?(@.provider==aws)].loadBalancers[?(@.instancePort==80)]
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

# FAQ

## Q. Why YAML?

We feel that YAML is much easier to write and grok for humans, while being easy
to convert to JSON, Spinnaker's internal pipeline storage format. Since these
files are intended to be version-controlled alongside your code, we felt it
necessary to choose a format that was more human-first leaning.

## Q. What are the differences between Template Variables and Pipline Parameters?

One potential confusing part about Pipeline Templates are the differences
between Variables and Parameters. Variables are a concept for Pipeline Templates
only and are not available at pipline execution runtime, as they're only used
during Jinja templating.

Variables are can be used to help build stages and modify the stage graph prior
to execution.

Parameters are variables that are made available for execution runtime. These
are the values that are available via the Configuration UI, and are presented
when manually executing a Pipeline.

## Q. I defined Pipeline Parameters or Triggers in the Template, but they don't work?

While the schema supports Pipeline Configuration (triggers, parameters, etc.),
Spinnaker currently does not yet support consuming this part of the schema. Any
configuration under the Pipeline "Configuration" tab must be setup for the
pipeline manually.

Support for consuming these is forthcoming.
