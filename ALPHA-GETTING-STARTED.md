# alpha getting started

This document is intended to help people get started with declarative pipelines.
Things are still in a highly volatile state, but if you're looking to evaluate
or help contribute bringing pipeline templates to a more stable place, this doc
will help you get going.

## enabling pipeline templates

In `orca-local.yml`:

```
pipelineTemplate:
  enabled: true
  jinja:
    enabled: true
```

A handlebars renderer is currently in the codebase as well, but is being
replaced by Jinja, so just enable that now to avoid hassles in the future.

## enabling UI support in Deck

In `settings.js` add the following to the `features` map:
```
pipelineTemplates: true
```

## create a template

Templates are currently only resolvable via HTTP(S). For evaluation and early
development efforts, I found creating gists and linking to their raw content
was the easiest way to iterate.

Here's a [super barebones template](https://gist.githubusercontent.com/robzienert/04f326f3077df176b1788b30e06ed981/raw/b9eed8643e9028d27f21c3dee7ca3b0b1f8c9fee/barebones.yml) 
(single wait stage) to get you running.

## create a pipeline in the UI

We don't have support in Deck yet for creating pipelines from templates yet, so
you'll need to jump through some hoops.

1. Create a new pipeline. Name it whatever.
2. Edit the JSON to include the template configuration.
3. Save.
4. Run the pipeline.

When you initially edit an empty pipeline, you'll see something like this:

```json
{
  "executionEngine": "v2",
  "keepWaitingPipelines": false,
  "lastModifiedBy": "example@example.com",
  "limitConcurrent": true,
  "parallel": true,
  "stages": [],
  "triggers": [],
  "updateTs": "1490300581000"
}
```

You'll want to update the JSON to look like so:

```json
{
  "executionEngine": "v2",
  "keepWaitingPipelines": false,
  "lastModifiedBy": "example@example.com",
  "limitConcurrent": true,
  "parallel": true,
  "stages": [],
  "triggers": [],
  "updateTs": "1490300581000",

  "config": {
    "pipeline": {
      "application": "myapp",
      "name": "My wait pipeline",
      "pipelineConfigId": "[PIPELINE_CONFIG_ID]",
      "template": {
        "source": "https://gist.githubusercontent.com/robzienert/04f326f3077df176b1788b30e06ed981/raw/b9eed8643e9028d27f21c3dee7ca3b0b1f8c9fee/barebones.yml"
      },
      "variables": {}
    },
    "schema": "1"
  },
  "type": "templatedPipeline"
}
```

Replace `[PIPELINE_CONFIG_ID]` with the UUID of the pipeline you're editing:

`https://spinnaker/#/applications/myapp/executions/configure/2260f9d0-64f7-4715-be7c-7f8c8e9905d1`

`PIPELINE_CONFIG_ID` is `2260f9d0-64f7-4715-be7c-7f8c8e9905d1`.

Since the configurations aren't stored in Front50 yet, the templates need to 
manually wire up the association of the pipeline execution to the correct 
pipeline in the executions view. That's what this does; otherwise executions won't
show on the UI.

# questions

If you have any questions on getting started, ask in Slack.
