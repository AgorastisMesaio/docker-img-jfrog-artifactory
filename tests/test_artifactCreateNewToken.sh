#!/usr/bin/env bash
#
# *****************************************
# WORKS WITH OSS LICENSE
# *****************************************
#
# Create a system wide ADMIN SCOPED TOKEN
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

# The URL
base_url="${ARTIFACTORY_URL}/access/api/v1/tokens"

# JSON data to be sent in the request
jsondata='{
    "scope": "applied-permissions/admin",
    "expires_in": "315360000",
    "include_reference_token": "true",
    "token_type": "access_token"
}'

# Make the POST request using curl
response=$(curl -s -w "%{http_code}" -o /tmp/response_body.json -X POST "$base_url" \
    -H "Authorization: Bearer $ARTIFACTORY_ADMIN_SCOPED_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$jsondata")
status_code=$(tail -n1 <<< "$response")
if [[ "$status_code" -eq 200 || "$status_code" -eq 201 ]]; then
    echo "Done!!"
    echo $(</tmp/response_body.json)
    rm -f /tmp/response_body.json  # Clean up the temporary file
else
    echo "Failed to create the permanent token. Status code: $status_code"
    cat /tmp/response_body.json
    rm -f /tmp/response_body.json  # Clean up the temporary file
fi
