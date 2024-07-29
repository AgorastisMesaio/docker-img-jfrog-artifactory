#!/usr/bin/env bash
#
# When Artifactory was provisioned you got the admin token to
# consume the API.
#
# Use "reference_token" found under ./token/permanentAdminTkoen.json
#
# Additionally A helper script was created to prepare a variable
# consumed by all the test scripts: ARTIFACTORY_ADMIN_SCOPED_TOKEN
PERMANENT_ADMIN_TOKEN_SCRIPT="../token/permanentAdminToken.sh"
if [ -f "${PERMANENT_ADMIN_TOKEN_SCRIPT}" ]; then
    . ${PERMANENT_ADMIN_TOKEN_SCRIPT}
fi

# We do everything from admin
export ARTIFACTORY_USER="admin"
export ARTIFACTORY_PASSWORD="password"

# Repos
export ARTIFACTORY_URL="http://localhost:8082"
export ARTIFACTORY_PREFIX="${ARTIFACTORY_URL}/artifactory"
export ARTIFACTORY_REPO="CUSTOM-my-binary-repository"
