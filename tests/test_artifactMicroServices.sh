#!/usr/bin/env bash
#
# *****************************************
# WORKS WITH OSS LICENSE
# *****************************************
#
NORMAL="\033[0;39m"
ROJO="\033[1;31m"
AMARILLO="\033[1;33m"
VERDE="\033[1;32m"
AZUL="\033[1;34m"

DONE="\033[1000;80H[${VERDE}DONE${NORMAL}]"
RESOK="\033[1000;80H[${VERDE}OK${NORMAL}]"
RESDRYRUN="\033[1000;80H[${VERDE}No ejecutar${NORMAL}]"
RESWARN="\033[1000;75H[${AMARILLO}warning${NORMAL}]"
RESOMITIDO="\033[1000;75H[${AMARILLO}Omitido${NORMAL}]"
RESERROR="\033[1000;77H[${ROJO}ERROR${NORMAL}]"

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

# LOOP TILL ARTIFACTORY IS READY
# ------------------------------------------------------------------------------------
#
check_artifactory_health() {
    clear
    timeout=${1:-90}
    start_time=$(date +%s)
    url="${ARTIFACTORY_URL}/router/api/v1/system/health"

    while [ $(($(date +%s) - start_time)) -lt $timeout ]; do
        result=$(curl -s -w "%{http_code}" -o /tmp/artifactory_health_response $url)

        if [ "$result" -ne 200 ]; then
            # Error running curl
            echo -n "!"
            sleep 5
            continue
        fi

        cat /tmp/artifactory_health_response
        sleep 5
    done
}

# Main
#
check_artifactory_health
