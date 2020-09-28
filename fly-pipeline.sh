#!/bin/bash

set -e

GREEN='\033[0;32m'
NC='\033[0m'

if [ "$#" -ne 2 ]; then
  echo "Usage: ./$(basename "$0") <CONCOURSE_TARGET> <PIPELINE>"
  echo ""

  # Usage help, part 1, show available concourse targets
  if hash jq 2> /dev/null && hash spruce 2> /dev/null; then
    echo -e "Available targets:"
    spruce json "$HOME/.flyrc" | jq --raw-output '.targets | keys[]' | while read target; do
      echo -e "- $GREEN${target}$NC"
    done
    echo ""
  fi

  # Usage help, part 2, show available pipelines (directories under pipelines)
  echo -e "Available pipelines:"
  ( cd $(dirname "$0")/pipelines 2> /dev/null && ls -1 ) | while read item; do
    echo -e "- $GREEN${item}$NC"
  done
  echo ""

  exit 1
fi

echo -e "\\n"

PipelineInfo(){
  local PIPELINE_NAME=$1
  local TARGET=$2

  if hash spruce 2> /dev/null; then
    if hash jq 2> /dev/null; then
      CONCOURSE_URL=$(spruce json "$HOME/.flyrc" | jq -r ".targets[\"$TARGET\"].api")
      TEAM_NAME=$(spruce json "$HOME/.flyrc" | jq -r ".targets[\"$TARGET\"].team")
      API_PIPELINE_PATH="${CONCOURSE_URL}/api/v1/teams/${TEAM_NAME}/pipelines"

      TOKEN=$(spruce json "$HOME/.flyrc" | jq -r ".targets[\"$TARGET\"].token.value")
      if [[ "${TOKEN}" == "null" ]]; then
        echo "Not able to retrieve the token, skipping info section"
        return
      fi

      # To mimic Aviator start behaviour
      PIPELINE=$PIPELINE_NAME
      PIPELINE_NAME_IN_AVIATOR_CFG=$(spruce json aviator.yml | jq -r .fly.name)
      REAL_PIPELINE_NAME=$(eval echo $(spruce json aviator.yml | jq -r .fly.name))

      PIPELINE_EXISTS=$(curl --silent --header "Authorization: Bearer $TOKEN" -X GET "${API_PIPELINE_PATH}/${REAL_PIPELINE_NAME}")
      if [[ -z ${PIPELINE_EXISTS} ]]; then
        echo "Pipeline is not deployed."
        return
      fi

      ALL_GROUPS=$(curl -s --header "Authorization: Bearer $TOKEN" -X GET "${API_PIPELINE_PATH}/${REAL_PIPELINE_NAME}" | jq -r '.groups[]?.name')
      PIPELINE_STATUS=$(curl -s --header "Authorization: Bearer $TOKEN" -X GET "${API_PIPELINE_PATH}/${REAL_PIPELINE_NAME}" | jq -r .paused)
      PIPELINE_RESOURCES=$(curl -s --header "Authorization: Bearer $TOKEN" -X GET "${API_PIPELINE_PATH}/${REAL_PIPELINE_NAME}/resources" | jq '. | length')

      echo -e "Displaying some insights of the $GREEN${PIPELINE}$NC pipeline:"
      echo -e ""
      echo -e "Paused: $GREEN${PIPELINE_STATUS}$NC"
      echo -e "Resources: $GREEN${PIPELINE_RESOURCES}$NC"

      if [ "$ALL_GROUPS" != "" ]; then
        echo -e "Groups: "
        for GROUP in $ALL_GROUPS; do
          echo -e "  ---->" "$GREEN${GROUP}$NC"
        done
      fi
    fi
  fi
}

FlyPipeline(){
  local target=$1
  local pipeline=$2
  if [[ -f $(pwd)/credentials.yml ]]
  then
    credentials=$(pwd)/credentials.yml
  elif [[ -f $(pwd)/../cftribe-credentials/credentials-new.yml ]]
  then
    credentials=$(pwd)/../cftribe-credentials/credentials-new.yml
  fi
  ( CREDENTIALS=$credentials TARGET=$target PIPELINE=$pipeline aviator && rm -rf tmp)
  PipelineInfo "$pipeline" "$target"
}

echo "Info: Flying pipeline $2 in concourse target $1..."
FlyPipeline "$1" "$2"

# Print a link to the pipeline
if hash spruce 2> /dev/null; then
  if hash jq 2> /dev/null; then
    CONCOURSE_URL=$(spruce json $HOME/.flyrc | jq -r ".targets[\"$1\"].api")
    TEAM_NAME=$(spruce json $HOME/.flyrc | jq -r ".targets[\"$1\"].team")
    PIPELINE_NAME=$2
    echo
    echo "On a Mac with iTerm2, just press 'Cmd' and click on the link to open a browser tab with the pipeline:"
    echo -e '\033[4;94m'"${CONCOURSE_URL}/teams/${TEAM_NAME}/pipelines/${PIPELINE_NAME}"'\033[0m'
    echo
  fi
fi