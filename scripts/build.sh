#!/bin/bash
source $(pwd)/build-buildpack-builder/scripts/check.sh
echo "$(pwd)/build-buildpack-builder/scripts/check.sh"
set -euo pipefail

apt-get update
apt-get install docker-ce docker-ce-cli containerd.io
service docker start
service docker status
trap 'service docker stop' EXIT

echo "[INFO] Just for check ${PAKETO_IMAGE_UPDATE}, ${IMAGE_TAG}"
if [[ ${PAKETO_IMAGE_UPDATE} == true ]]; then
    echo "[INFO] Build Code Engine buildpack builder image"
    docker pull "index.docker.io/paketobuildpacks/builder:full"
    docker pull "index.docker.io/paketobuildpacks/run:full-cnb"
    docker pull "index.docker.io/paketobuildpacks/build:full-cnb"

    docker tag "index.docker.io/paketobuildpacks/builder:full" "${CODE_ENGINE_REGISTRY}/builder:${IMAGE_TAG}"
    docker tag "index.docker.io/paketobuildpacks/run:full-cnb" "${REGISTRY}/run:${IMAGE_TAG}-full-cnb"
    docker tag "index.docker.io/paketobuildpacks/build:full-cnb" "${REGISTRY}/build:${IMAGE_TAG}-full-cnb"

    docker push "${CODE_ENGINE_REGISTRY}/builder:${IMAGE_TAG}"
    docker push "${CODE_ENGINE_REGISTRY}/run:${IMAGE_TAG}-full-cnb"
    docker push "${CODE_ENGINE_REGISTRY}/build:${IMAGE_TAG}-full-cnb"
else
    echo "[INFO] Don't need to build CodeEngine buildpack builder image again"
fi
exit 0
