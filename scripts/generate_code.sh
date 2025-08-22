#!/usr/bin/env bash
set -euo pipefail

# This script is meant to be sourced from the supply script like this, before the actual supply step runs:
source "$BUILDPACK_DIR/scripts/generate_code.sh"
# It can also be run from anywhere to generate python app code that gets copied over into the $BUILD_DIR, like this:
"$BUILDPACK_DIR/scripts/generate_code.sh" "$BUILD_DIR" "$CACHE_DIR" "$DEPS_DIR" "$DEPS_IDX"

BUILD_DIR=${1:-$BUILD_DIR}
CACHE_DIR=${2:-$CACHE_DIR}
DEPS_DIR=${3:-$DEPS_DIR}
DEPS_IDX=${4:-$DEPS_IDX}

# Exit early if app is clearly not an AI project that has the required environment variables set.
if [ ! -f "${BUILD_DIR}/ai.env" ] && [ ! -f "${BUILD_DIR}/Promptfile" ]; then
  echo '!!!--> Either a Promptfile or the ai.env with CF_APP_SPEC must be present during staging <--!!!'
  exit 1
fi
if [ -f "${BUILD_DIR}/ai.env" ]; then
  source "${BUILD_DIR}/ai.env"
fi
if [ -f "${BUILD_DIR}/Promptfile" ]; then
  CF_APP_SPEC=$(<${BUILD_DIR}/Promptfile)
fi
if [ -z "${STACKIT_MODEL_SERVING_AUTH_TOKEN:-}" ] || [ -z "${CF_APP_SPEC:-}" ]; then
  echo '!!!--> Missing required environment variables during staging (CF_APP_SPEC or STACKIT_MODEL_SERVING_AUTH_TOKEN) <--!!!'
  exit 1
fi

# DO "'*+-.,_MAGIC_,.-+*'" HERE
pushd $CACHE_DIR
  echo '-----> Generating App Code from Spec (from Promptfile or CF_APP_SPEC environment variable)...'
  # Ask LLM to generate code from the provided prompt:
  curl --request POST \
    --url "${STACKIT_MODEL_SERVING_BASE_URL:-https://api.openai-compat.model-serving.eu01.onstackit.cloud/v1}/chat/completions" \
    --header 'Accept: application/json' \
    --header "Authorization: Bearer ${STACKIT_MODEL_SERVING_AUTH_TOKEN:-STACKIT_MODEL_SERVING_AUTH_TOKEN is a required environment Variable.}" \
    --header 'Content-Type: application/json' \
    --data '{
      "model": "'"${STACKIT_MODEL_SERVING_MODEL:-google/gemma-3-27b-it}"'",
      "messages": [
            {
          "role": "system",
          "content": [{"type": "text", "text": "You are a highly experienced DevOps engineer. Your sole task is to take user project requirements and generate a single, complete, and executable bash script. This script will create a deployable Python application for Cloud Foundry.\n\nYou **must** follow these strict rules:\n\n1.  **Project Structure:** The script must create a project folder named `app` and all necessary subdirectories using `mkdir -p`.\n\n2.  **File Generation:** All files (`.py`, `.txt`, `.html`, etc.) must be created using `echo '\''file content'\'' >> file_path`.\n\n3.  **Quoting:** The entire string passed to `echo` must be encapsulated with **single quotes (`'\''`)**. All Python and HTML code lines within these single-quoted strings **must use double quotes (`\"`)** for any internal strings. You **must not use single quotes (`'\''`)** inside the file content to prevent escaping problems.\n\n4.  **No Explanations:** The final output **must be a single bash script only**, with no preceding or trailing text, explanations, or comments.\n\n5.  **Technical Constraints:**\n    * The `main.py` file must use the `os` module to listen on the port provided by the `PORT` environment variable.\n    * The `requirements.txt` file must contain only the necessary package names (e.g., `flask`) with no version numbers.\n    * The `Procfile` must contain a single line: `web: python main.py`.\n    * The Python code must include all required import statements, including standard libraries like the os module.    * The end user facing text and all messages from the Python code and optionally needed html files and templates must be translated to the language in which the initial requirements of the apps are written."}]
      },
          {
              "role": "user",
              "content": "Answer with the code to generate all needed and referenced files for the following requirements in the matching language:\n```\n'"${CF_APP_SPEC:-A web page that explains to be a demo app and that the user need to provide requirements with the -c parameter or as CF_APP_SPEC environment variable in order to see a more complex app.}"'\n```\nBefore answering, check the script for missing sub directories and add a mkdir -p statement to the beginning of the script for each additional file that gets created with any echo statement."
          }
      ],
      "temperature": 0.1
  }'|tee response.json|jq -r '.choices[0].message.content'|grep -v '```'|tee create_app_from_scratch.sh # Sanitize the script from the LLM, which creates all files and directories.
  # Show the resulting script to STDERR for debugging purposes:
  cat create_app_from_scratch.sh >&2
  # Finally, run the script:
  bash create_app_from_scratch.sh

  # Move the generated files to the build directory:
  mv app/* ${BUILD_DIR}/
popd