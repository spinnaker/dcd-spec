# This example shows a bake and deploy pipeline with the option to override to a find image and deploy pipeline

## Option 1: Bake
`template.yml` shows a sample multi region bake and deploy. `bake-deploy-config.yml` shows the config for that pipeline, providing a stage name for the first stage.


## Option 2: Find Image
`template.yml` remains the same. `findImage-deploy-config.yml` shows replacing the bake stage with a findImage stage. 
