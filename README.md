# Cloud Foundry AI Buildpack based on the Python Buildpack

A Cloud Foundry [buildpack](http://docs.cloudfoundry.org/buildpacks/) for pushing prompt text that result in Python based apps.

This buildpack builds upon the official [Python buildpack](http://docs.cloudfoundry.org/buildpacks/python/index.html).

### Buildpack User Documentation

To push an app you simply need a prompt and an access token to the STACKIT Model Serving Service or another OpenAI-compatible API of you choice.

You have the following option to push an app to Cloud Foundry this way:


1. Via the following `ai.env` file:
   ```bash
   CF_APP_SPEC='A web page that allows to do basic math with two numbers.'
   STACKIT_MODEL_SERVING_AUTH_TOKEN='ey...'
   ```
   Pushed with: `cf push mybasicmath -b 'https://github.com/funcf/ai-buildpack.git'`
 
 

2. Via the following  `Promptfile`:
   ```txt
   A web page that allows to do basic math with two numbers.
   ```
   and the following `manifest.yml`:
   ```yml
    ---
    applications:
    - name: mybasicmath
      buildpacks:
      - https://github.com/funcf/ai-buildpack.git
      env:
        STACKIT_MODEL_SERVING_AUTH_TOKEN: ey...
   ```
   Pushed with: `cf push` 
 
 

3. Or via the `Promptfile`:
   ```txt
   A web page that allows to do basic math with two numbers.
   ```
   and some more commands:
   ```bash
   cf create-app mybasicmath -b 'https://github.com/funcf/ai-buildpack.git'
   cf set-env mybasicmath STACKIT_MODEL_SERVING_AUTH_TOKEN 'ey...'
   cf push
   ``` 
 
 
  
### FAQ

#### A) Why not pushing just a `manifest.yml` with all needed environment variables or just a `cf push` with `-b 'https://github.com/funcf/ai-buildpack.git'` and the prompt injected as start command with `-c 'I need an app to play tic tac toe in the browser.'` (_the_ initial idea btw.)?

   The current Cloud Foundry implementation will fail if you push no files other than a `manifest.yml` (because magic AI buildpacks were not there yet ;-)!
 
  
#### B) What model is used and how can I change the model or the model serving service?

   Via app environment variable or a separate `ai.env` file you can change the following  default values:
   ```bash
   STACKIT_MODEL_SERVING_BASE_URL='https://api.openai-compat.model-serving.eu01.onstackit.cloud/v1'
   STACKIT_MODEL_SERVING_MODEL='google/gemma-3-27b-it'
   ```
   The API Call will be a POST request to: `${STACKIT_MODEL_SERVING_BASE_URL}/chat/completions`.


### Reporting Issues

Open a GitHub issue on this project [here](https://github.com/funcf/ai-buildpack/issues/new).
Or directly reach out to the [maintainer](https://github.com/mauricebrinkmann) via [CF Slack](https://cloudfoundry.slack.com/team/U02FU7BPQ7P).
