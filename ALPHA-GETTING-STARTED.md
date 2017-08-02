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

## Create a template

Templates are currently only resolvable via HTTP(S). For evaluation and early
development efforts, I found creating gists and linking to their raw content
was the easiest way to iterate.

Here's a [super barebones template](https://gist.githubusercontent.com/robzienert/04f326f3077df176b1788b30e06ed981/raw/b9eed8643e9028d27f21c3dee7ca3b0b1f8c9fee/barebones.yml) 
(single wait stage) to get you running.

## Create a template using the CLI ([roer](https://github.com/spinnaker/roer))

```roer pipeline-template publish template.yml```

## Create a pipeline in the UI

The UI supports creating pipelines given it's enabled as described above. Just create a new pipeline and choose Create from: "Template". Choose your template and configure it using the UI.

![Create a pipeline in the UI](https://user-images.githubusercontent.com/1511533/28893520-68d1b110-77da-11e7-935d-b509464026d9.png)

## Create a pipeline using the CLI (roer)

You can use a thin spinnaker CLI to publish both a template or a configuration to create a pipeline using [roer](https://github.com/spinnaker/roer).

```roer pipeline save pipeline-config.yml```




# questions

If you have any questions on getting started, ask in Slack.
