#!/bin/bash -vx

DEPLOY_BRANCH="master"
TARGET_S3_BUCKET="s3://developer.okta.com-staging"
REGISTRY="https://artifacts.aue1d.saasure.com/artifactory/api/npm/npm-okta"

source "${0%/*}/common.sh"

require_env_var "OKTA_HOME"
require_env_var "BRANCH"
require_env_var "REPO"

export TEST_SUITE_TYPE="build"


# `cd` to the path where Okta's build system has this repository
cd ${OKTA_HOME}/${REPO}


interject "Building HTML in $(pwd)"
if ! generate_html;
then
    echo "Error building site"
    exit ${BUILD_FAILURE};
fi

# ----- Start (Temporary) Deploy to S3 -----
if [[ "${BRANCH}" == "${DEPLOY_BRANCH}" ]];
then
    interject "Uploading HTML from '${GENERATED_SITE_LOCATION}' to '${TARGET_S3_BUCKET}'"
    if ! aws s3 cp ${GENERATED_SITE_LOCATION} ${TARGET_S3_BUCKET} --recursive;
    then
        echo "Error uploading HTML to S3"
        exit ${BUILD_FAILURE}
    fi
fi

# ----- End (Temorary) Deploy to S3 -----


# Create NPM package
# ------------------
if [ -n "$action_branch" ];
then
  echo "Publishing from bacon task using branch $action_branch"
  TARGET_BRANCH=$action_branch
else
  echo "Publishing from bacon testSuite using branch $BRANCH"
  TARGET_BRANCH=$BRANCH
fi

if ! npm run ci-update-package -- --branch ${TARGET_BRANCH}; then
  echo "ci-update-package failed! Exiting..."
  exit $FAILED_SETUP
fi

# if ! npm run build -- --branch ${TARGET_BRANCH}; then
#   echo "run run build failed! Exiting..."
#   exit $FAILED_SETUP
# fi

if ! npm publish --registry ${REGISTRY}; then
  echo "npm publish failed! Exiting..."
  exit $PUBLISH_ARTIFACTORY_FAILURE
fi

DATALOAD=$(npm run ci-pkginfo:dataload --silent)
if ! artifactory_curl -X PUT -u ${ARTIFACTORY_CREDS} ${DATALOAD} -v -f; then
  echo "artifactory_curl failed! Exiting..."
  exit $PUBLISH_ARTIFACTORY_FAILURE
fi

exit $SUCCESS
