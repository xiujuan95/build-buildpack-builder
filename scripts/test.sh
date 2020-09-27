#!/bin/bash
source ./check.sh
set -ex

cd ..
WORKSPACE="$(cd "$(dirname "${BASH_SOURCE[0]}")/" && pwd)"
# export REGISTRY="icr.io/obs/codeengine/buildpacks"
export IMAGE_REPO="${CODE_ENGINE_REGISTRY}/builder:${IMAGE_TAG}"
export PACK_VERSION="v0.11.2"
export GO_VERSION="1.14.9"
echo "${WORKSPACE}"

echo "Do testing..."
# install necessary command line
wget https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz
tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin
go version
wget https://github.com/buildpacks/pack/releases/download/${PACK_VERSION}/pack-${PACK_VERSION}-linux.tgz
tar xvf pack-${PACK_VERSION}-linux.tgz
rm pack-${PACK_VERSION}-linux.tgz
cp pack ${DIR}/bin

fixtures=$(realpath fixtures)
fs3fixtures="$(realpath fs3-fixtures)"
tinyfixtures="$(realpath tiny-fixtures)"

echo "[INFO] Building test apps..."
pushd "${WORKSPACE}/test-builder" >/dev/null 2>&1
  go test -args "${tinyfixtures}" -v
  go test -args "${fixtures}" -v

  # TODO Skip the fs3fixtures test because dotnet_core_aspnet_app, dotnet_core_runtime_app, dotnet_core_sdk_app and php_composer_app still have some problems for community paketo builder image.
  # Pls refer to:https://paketobuildpacks.slack.com/archives/CULAS8ACD/p1592802512280100
  # go test -args "${fs3fixtures}" -v
popd
echo