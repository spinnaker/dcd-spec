# This example shows a complex wait pipeline.   
The UI view for this pipeline is shown in [complex-wait-ui.png](complex-wait-ui.png). Same UI for all three options.

## Option 1: Inheritance
`root-template.yml`, `child-template.yml`, and `child-2-template.yml` show an inheritence structure and the use variable. `mypipeline-config.yml` adds another stage at the configuration level.    


## Option 2: One template
`combined-template.yml` shows the same stages represented in one template. `mypipelineCombined-config.yml` shows the config for that template that produces the same pipeline.

## Option 3: All Config
`only-config.yml` shows how you can create the same pipeline with one config file. You might want to do this if you are only using this logic for one pipeline, or you are working to transition to managed pipeline templates and want to first convert each pipeline to code.