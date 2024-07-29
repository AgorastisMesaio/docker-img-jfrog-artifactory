#!/usr/bin/env bash
#
# Argument Parsing: The script now checks if timeout is passed in the first argument.
# If the first argument is provided, it uses it as the timeout value. If no argument
# is provided, it defaults to 5 seconds.
#
# ./test_artifactHealth.sh 120   Will loop for 120secs
#
# WORKS WITH OSS VERSION
#

# TIMEOUT parameters
timeout=5
if [ $# -gt 0 ]; then
    timeout=$1
fi
seconds=3


# Loop to check health
token=false
start_time=$(date +%s)
echo "Checking ARTIFACTORY Token "
while [ $(($(date +%s) - start_time)) -lt $timeout ]; do
    # Loop during $timeout till the token is available
    PERMANENT_ADMIN_TOKEN_SCRIPT="../token/permanentAdminToken.sh"
    if [ -f "${PERMANENT_ADMIN_TOKEN_SCRIPT}" ]; then
        echo "OK"
        token=true
        break
    else
        echo "Token is not yet available, will try again in $seconds seconds"
        sleep $seconds
        continue
    fi
done
if ! $token; then
  echo "Token is not yet available, timeout !!"
  exit 1
fi

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

# Loop to check health
start_time=$(date +%s)
url="${ARTIFACTORY_URL}/router/api/v1/system/health"

echo "Checking JFrog ARTIFACTORY Health "
while [ $(($(date +%s) - start_time)) -lt $timeout ]; do
    result=$(curl --max-time $seconds -s -w "%{http_code}" -o /tmp/artifactory_health_response $url)

    # Error running curl
    if [ "$result" -ne 200 ]; then
        if [ "$result" -ne 000 ]; then
            echo "Responding with $result. Will try again in $seconds seconds"
        else
            echo "Not responding, will try again in $seconds seconds"
        fi
        sleep $seconds
        continue
    fi

    health_status=$(cat /tmp/artifactory_health_response)

    # Check if all services have a "message" of "OK"
    all_services_ok=true
    services=$(echo "$health_status" | jq -r '.services[] | .message')

    for service in $services; do
        if [ "$service" != "OK" ]; then
            all_services_ok=false
            break
        fi
    done

    if $all_services_ok; then
        echo "OK"
        exit 0
    fi

    echo "No response, will try again in $seconds seconds"
    echo "."
    sleep $seconds
done

echo "ERROR"
exit 1
