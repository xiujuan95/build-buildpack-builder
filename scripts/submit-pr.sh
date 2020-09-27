#!/bin/bash
source ./check.sh
set -ex

echo "[INFO] Submit PR to source-to-image repo to modify all related buildstrategies and generate docs"
echo "${CODE_ENGINE_REGISTRY}/builder:${IMAGE_TAG}"
eval `ssh-agent -s`
mkdir -p ~/.ssh
if [[ $GIT_PRIVATE_KEY != "" ]]; then
cat > ~/.ssh/gitkey <<EOF
$GIT_PRIVATE_KEY
EOF
chmod 600 ~/.ssh/gitkey
ssh-add  ~/.ssh/gitkey
fi
git config --global user.email "mrs@concourse.ci"
git config --global user.name "Mrs. Concourse"

set +x
rm -rf source-to-image
SOURCE_TO_IMAGE_REPOSITORY="coligo/source-to-image"
git clone https://"${GITHUB_TOKEN}"@github.ibm.com/"${SOURCE_TO_IMAGE_REPOSITORY}".git source-to-image
set -x
cd source-to-image
git checkout develop

set +e
git branch -D auto-modify-bp-builder
git push origin :auto-modify-bp-builder
set -e

git checkout -b auto-modify-bp-builder
sed -i "s/builder:.*/builder:"${IMAGE_TAG}"/g" deployment/buildstrategies/buildstrategy_buildpacks-v3_large_cr.yaml deployment/buildstrategies/buildstrategy_buildpacks-v3_medium_cr.yaml deployment/buildstrategies/buildstrategy_buildpacks-v3_small_cr.yaml deployment/buildstrategies/buildstrategy_buildpacks-v3_xlarge_cr.yaml
HOMEPAGES=$(docker inspect "${REGISTRY}/builder:${IMAGE_TAG}" | jq -r '.[]."Config"."Labels"."io.buildpacks.builder.metadata"' | jq -r '.buildpacks[].homepage')
HOMEPAGES_ARRAY=(${HOMEPAGES/// })
VERSIONS=$(docker inspect "${REGISTRY}/builder:${IMAGE_TAG}" | jq -r '.[]."Config"."Labels"."io.buildpacks.builder.metadata"' | jq -r '.buildpacks[].version')
VERSIONS_ARRAY=(${VERSIONS/// })
IDS=$(docker inspect "${REGISTRY}/builder:${IMAGE_TAG}" | jq -r '.[]."Config"."Labels"."io.buildpacks.builder.metadata"' | jq -r '.buildpacks[].id')
IDS_ARRAY=(${IDS/// })
echo "[INFO] Modify related docs"
TAG_STRING=$(echo ${IMAGE_TAG} | sed 's/\.//g')
sed -i "4a - \[${IMAGE_TAG}\](\#${TAG_STRING})" docs/supported-runtime-version-for-buildpack-builder.md
echo "

## ${IMAGE_TAG}
[buildpack builder image release](https://github.ibm.com/coligo/buildpacks/releases/tag/${IMAGE_TAG})

|run-time|buildpack-version|
|---|---|">>docs/supported-runtime-version-for-buildpack-builder.md

for(( i=0;i<${#HOMEPAGES_ARRAY[@]};i++)); do
homepage=${HOMEPAGES_ARRAY[i]}
version=${VERSIONS_ARRAY[i]}
name=${IDS_ARRAY[i]}
url=${homepage}"/releases/tag/v"${version}
echo "|${name}|[${version}](${url})|">>docs/supported-runtime-version-for-buildpack-builder.md
done
git add -A
git commit -m "modify buildpack builder image version to ${IMAGE_TAG}"
git push origin auto-modify-bp-builder
API_JSON="{\"title\":\"From Mrs concourse: modify buildpack builder image version to ${IMAGE_TAG}\",\"base\":\"develop\",\"head\":\"auto-modify-bp-builder\",\"body\":\"From Mrs concourse: modify buildpack builder image version to ${IMAGE_TAG}\"}"
set +x
API_RELEASE_URL="https://github.ibm.com/api/v3/repos/${SOURCE_TO_IMAGE_REPOSITORY}/pulls?access_token=${GITHUB_TOKEN}"
set -x
curl -d "${API_JSON}" "${API_RELEASE_URL}"
