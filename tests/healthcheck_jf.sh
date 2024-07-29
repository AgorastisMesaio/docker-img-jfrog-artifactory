#!/usr/bin/env bash
#
# Test script that deploys (upload) an image, then downloads it and compares checksums
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
    ARTIFACTORY_ADMIN_SCOPED_TOKEN
    ARTIFACTORY_PREFIX
    ARTIFACTORY_REPO
)
for i in "${!variables[@]}"; do
    if [ -z ${!variables[$i]+x} ] || [ -z ${!variables[$i]} ]; then echo "ERROR!! The variable ${variables[$i]} is unset or empty. Check ${SETUP_VARS}"; exit; fi
done

# Test health
./test_artifactHealth.sh
if [ "$?" != "0" ]; then
    exit 1
fi

# Get timestamp
timestamp=$(date +"%Y%m%d-%H%M%S")

# Test upload
echo -n "Checking JFrog ARTIFACTORY Upload/Download "
export TEST_FILE="test-image.bin"
curl -H "Authorization: Bearer ${ARTIFACTORY_ADMIN_SCOPED_TOKEN}" \
    -T ./bin_upload/${TEST_FILE} \
    "${ARTIFACTORY_PREFIX}/${ARTIFACTORY_REPO}/${timestamp}-${TEST_FILE}" >/dev/null 2>&1
if [ "$?" != "0" ]; then
    echo -e "${RESRROR}"
    exit 1
fi

# Test download
mkdir ./bin_downloads 2>/dev/null
curl -s -H "Authorization: Bearer ${ARTIFACTORY_ADMIN_SCOPED_TOKEN}" \
    -L -o ./bin_downloads/${timestamp}-${TEST_FILE} \
    -O "${ARTIFACTORY_PREFIX}/${ARTIFACTORY_REPO}/${timestamp}-${TEST_FILE}" >/dev/null 2>&1
if [ "$?" != "0" ]; then
    echo -e "${RESRROR}"
    exit 1
fi

# Compare uploaded/downloades files
#
cmp bin_upload/${TEST_FILE} bin_downloads/${timestamp}-${TEST_FILE}
if [ "$?" != "0" ]; then
    echo -e "${RESRROR}"
    exit 1
fi
echo -e "${RESOK}"
exit 0

