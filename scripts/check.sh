#!/bin/bash

set -euo pipefail

# : "${SLACK_URL:?}"
# docker login -u "iamapikey" -p ${DOCKER_API_KEY} "icr.io"
apt-get update
apt-get install docker-ce docker-ce-cli containerd.io
service docker start
service docker status
trap 'service docker stop' EXIT

# function post_to_slack() {
#   ce_image_run_time="$1"
#   paketo_image_run_time="$2"
#   curl -X POST --data "payload={\"text\": \"<!here> paketo image has been updated:\n PAKETO_IMAGE_RUN_TIME is ${paketo_image_run_time}\n CE_IMAGE_RUN_TIME is ${ce_image_run_time}\"}" "${SLACK_URL}"
# }

echo "[INFO] Pull the newest paketo buidler iamge" >&2
docker pull "index.docker.io/paketobuildpacks/builder:full" >&2

echo "[INFO] Parse the digest, id and run-time version of paketo builder image" >&2
PAKETO_IMAGE_ID=$(docker inspect "index.docker.io/paketobuildpacks/builder:full" | jq -r '.[]."Id"' | sed 's/sha256\://g')
PAKETO_IMAGE_DIGEST=$(docker inspect "index.docker.io/paketobuildpacks/builder:full" | jq -r '.[].RepoDigests[]' | sed 's/paketobuildpacks\/builder@//g')
PAKETO_IMAGE_RUN_TIME=$(docker inspect "index.docker.io/paketobuildpacks/builder:full" | jq -r '.[].Config.Labels."io.buildpacks.buildpack.order"')
PAKETO_TAG=$(echo ${PAKETO_IMAGE_ID:0:12})
export IMAGE_TAG="v${PAKETO_TAG}-rc1"
echo "${IMAGE_TAG}"
echo "[INFO] index.docker.io/paketobuildpacks/builder:full ID: ${PAKETO_IMAGE_ID}" >&2
echo "[INFO] index.docker.io/paketobuildpacks/builder:full digest ${PAKETO_IMAGE_DIGEST}" >&2
echo "[INFO] supported run-time version: ${PAKETO_IMAGE_RUN_TIME}" >&2

echo "[INFO] Check paketo builder image update"
echo "[INFO] Get the latest code engine buildpacks tag"
set +x
rm -rf source-to-image
# SOURCE_TO_IMAGE_REPOSITORY="coligo/source-to-image"
git clone https://"${GITHUB_TOKEN}"@github.ibm.com/"${SOURCE_TO_IMAGE_REPOSITORY}".git source-to-image
set -x
cd source-to-image
tag=$(sed -n '5p' docs/supported-runtime-version-for-buildpack-builder.md | cut -b 4- | sed 's/\]//')
tags=(${tag/(/ })
CE_LATEST_IMAGE_TAG=${tags[0]}
echo "${CE_LATEST_IMAGE_TAG}"
echo "[INFO] Pull code engine builder image, ${CODE_ENGINE_REGISTRY}/builder:${CE_LATEST_IMAGE_TAG}" >&2
docker pull "${CODE_ENGINE_REGISTRY}/builder:${CE_LATEST_IMAGE_TAG}" >&2
echo "[INFO] Parse the digest, id and run-time version of code engine builder image" >&2
CE_IMAGE_ID=$(docker inspect "${CODE_ENGINE_REGISTRY}/builder:${CE_LATEST_IMAGE_TAG}" | jq -r '.[]."Id"' | sed 's/sha256\://g')
CE_IMAGE_DIGEST=$(docker inspect "${CODE_ENGINE_REGISTRY}/builder:${CE_LATEST_IMAGE_TAG}" | jq -r '.[]."RepoDigests"' | sed 's/paketobuildpacks\/builder@//g')
CE_IMAGE_RUN_TIME=$(docker inspect "${CODE_ENGINE_REGISTRY}/builder:${CE_LATEST_IMAGE_TAG}" | jq -r '.[].Config.Labels."io.buildpacks.buildpack.order"')
echo "[INFO] ${CODE_ENGINE_REGISTRY}/builder:${CE_LATEST_IMAGE_TAG} ID: ${CE_IMAGE_ID}" >&2
echo "[INFO] ${CODE_ENGINE_REGISTRY}/builder:${CE_LATEST_IMAGE_TAG} digest: ${CE_IMAGE_DIGEST}" >&2
echo "[INFO] supported run-time version: ${CE_IMAGE_RUN_TIME}" >&2

echo "[INFO] Compare CE builder image with paketo builder image" >&2
PAKETO_IMAGE_UPDATE="false"
if [[ ${CE_IMAGE_ID} != ${PAKETO_IMAGE_ID} ]]; then
  echo "[INFO] Paketo builder image has been update" >&2
  PAKETO_IMAGE_UPDATE="true"
else
  echo "[INFO] Paketo builder image doesn't any changes" >&2
  PAKETO_IMAGE_UPDATE="false"
fi

if [[ ${PAKETO_IMAGE_UPDATE} == true ]]; then
    echo "[INFO] Notify in slack channel"
    # post_to_slack "${CE_IMAGE_RUN_TIME}" "${PAKETO_IMAGE_RUN_TIME}"
fi
exit 0


