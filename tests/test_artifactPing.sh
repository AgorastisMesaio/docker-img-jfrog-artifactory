#!/usr/bin/env bash
#
# *****************************************
# WORKS WITH OSS VERSION
# *****************************************
#
# Ping Actifactory service
#

# ----- VARIABLEs START SECTION (do not modify) -------
# Load the variables file
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SETUP_VARS="${SCRIPT_DIR}/0.SETUP_VARS.sh"
if [ ! -f ${SETUP_VARS} ]; then echo "Error! file ${SETUP_VARS} doesn't exist"; exit; fi
. ${SETUP_VARS}
# ----- VARIABLEs END SECTION -------------------------

# Init
# Check needed variables in this script, space or new line separated
variables=(
    ARTIFACTORY_USER
    ARTIFACTORY_PASSWORD
    ARTIFACTORY_ADMIN_SCOPED_TOKEN
)
for i in "${!variables[@]}"; do
    if [ -z ${!variables[$i]+x} ] || [ -z ${!variables[$i]} ]; then echo "ERROR!! The variable ${variables[$i]} is unset or empty. Check ${SETUP_VARS}"; exit; fi
done

# Go...
#
echo
echo "Ping Artifactory:"
echo "--------------------------------------------------------"
echo
curl -i ${ARTIFACTORY_PREFIX}/api/system/ping
echo
echo
echo "List of repositories:"
echo "--------------------------------------------------------"
echo
curl -H "Authorization: Bearer ${ARTIFACTORY_ADMIN_SCOPED_TOKEN}" \
    ${ARTIFACTORY_PREFIX}/api/repositories
echo
echo "--------------------------------------------------------"
