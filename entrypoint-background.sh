#!/usr/bin/env bash
#
# entrypoint-token.sh for JFrog Artifactory OSS
#
# The objective of this script is, during the first deployment,
# perform the following tasks:
# - create a permanent token
#   under persistance volume AND under host's ./token directory
# - change Admin's password if env variable ADMIN_PASSWORD is set
#
# For this to happen, you need to setup the followin volumes
# in your docker-compose.yml file:
#
# ---
# volumes:
#   artifactory_data:
#     driver: local
# :
# artifactory:
#    image: ghcr.io/agorastismesaio/docker-img-jfrog-artifactory:main
#    :
#    volumes:
#      - artifactory_data:/var/opt/jfrog/artifactory
#      - ./token:/var/opt/jfrog/artifactory/token
# ---
#

# Global Variables
export CONFIG_ROOT=/config
CONFIG_ROOT_MOUNT_CHECK=$(mount | grep ${CONFIG_ROOT})
LOGFILE="./firstrun.log"
IWASHERE="./iwashere.lock"
export PERMANENT_ADMIN_TOKEN="permanentAdminToken.json"
export PERMANENT_ADMIN_TOKEN_SCRIPT="permanentAdminToken.sh"
export PERMANENT_ADMIN_TOKEN_SCRIPT_BAT="permanentAdminToken.BAT"
temporaryToken=""
# Working with curl
change_password_response="/tmp/change_password_response"
artifactory_health_response="/tmp/artifactory_health_response"
# Calculate time to fully boot Artifactory
artifactory_boot_start_time=$(date +%s)

# Function to log messages with date, time, and level
log_message() {
    local level="$1"
    shift
    local message="$@"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$level] $message" >>${LOGFILE}
}

# Separators for log readability
log_separator() {
    echo "---------------------------------------------------------------" >>${LOGFILE}
}

# PREPARE BOOTSTRAP FILES FOR ARTIFACTORY AUTOMATION
# ------------------------------------------------------------------------------------
#
# Permanent Token howto:
# https://jfrog.com/help/r/jfrog-installation-setup-documentation/create-an-automatic-admin-token
#
# If I create an empty json with this name:
# /var/opt/jfrog/artifactory/bootstrap/etc/access/keys/generate.token.json
#
# After Artifactory boots for the first time it generates a temporary token here
# /var/opt/jfrog/artifactory/etc/access/keys/token.json
#
# With that temporary token I will be able to create a permanent one later
#
# Phase 1: create an empty json...
prepare_files() {
    mkdir -p /var/opt/jfrog/artifactory/bootstrap/etc/access/keys 2>/dev/null
    cat <<EOT >/var/opt/jfrog/artifactory/bootstrap/etc/access/keys/generate.token.json
{}
EOT
}

# Change the admin's password
change_admin_password_start_time=$(date +%s)
admin_password_changed=false
changeAdminPassword() {
    ADMIN_PASSWORD_CHANGE_INTERVAL=$1
    current_time=$(date +%s)
    time_elapsed=$(( current_time - change_admin_password_start_time ))

    if (( time_elapsed >= ADMIN_PASSWORD_CHANGE_INTERVAL )); then
        change_admin_password_start_time=$(date +%s)

        # Don't want curl's stdout response, just the HTTP status code
        log_message "INFO" "Attempting to set Admin Password"
        http_code=$(curl -s -w "%{http_code}" -o ${change_password_response} -X POST -u admin:password \
            -H "Content-type: application/json" \
            -d "{ \"userName\" : \"admin\", \"oldPassword\" : \"password\", \"newPassword1\" : \"${ADMIN_PASSWORD}\", \"newPassword2\" : \"${ADMIN_PASSWORD}\" }" \
            http://127.0.0.1:8082/artifactory/api/security/users/authorization/changePassword)
        if [ "$http_code" -eq 200 ]; then
            log_message "INFO" "Admin password changed successfully. Http code: $http_code"
            return 0  # Return 0 explicitly to indicate success
        else
            log_message "ERROR" "Failed to change admin password. Http code: $http_code"
            return 1  # Return 1 explicitly to indicate failure
        fi
    fi
    return 1  # Return 1 if the time interval has not passed
}

# FUNCTION THAT LOOPs TILL ARTIFACTORY IS READY
check_artifactory_health() {
    timeout=${1:-90}
    start_time=$(date +%s)
    url="http://127.0.0.1:8082/router/api/v1/system/health"

    log_separator
    log_message "INFO" "Waiting for Artifactory to boot..."
    alreadyBooted=false

    while [ $(($(date +%s) - start_time)) -lt $timeout ]; do

        # Check artifactory health status
        result=$(curl -s -w "%{http_code}" -o ${artifactory_health_response} $url)

        if [ "$result" -ne 200 ]; then
            log_message "WARN" "Artifactory not ready yet (HTTP $result). Retrying..."
            sleep 5
            continue
        fi

        health_status=$(cat ${artifactory_health_response})

        # Check if all services have a "message" of "OK"
        all_services_ok=true
        services=$(echo "$health_status" | grep -oP '"message"\s*:\s*"\K[^"]*')
        while IFS= read -r line; do
            if [ "$line" != "OK" ]; then
                all_services_ok=false
                log_message "WARN" "Service not ready: $line"
                break
            fi
        done <<<"$services"

        if $all_services_ok; then
            log_message "INFO" "All services up and running."
            return 0
        fi

        if ! $alreadyBooted; then
            alreadyBooted=true
            log_message "INFO" "Artifactory bootstrap done. Waiting for all microservices to start..."
        fi

        sleep 5
    done

    log_message "ERROR" "Timeout while waiting for Artifactory to start."
    return 1
}

# FUNCTION THAT LOOPs TILL TEMPORARY ADMIN TOKEN IS AVAILABLE
# ------------------------------------------------------------------------------------
#
# Function to wait for the file and read its content
wait_for_file_and_read() {
    local file_path=$1
    while [ ! -f "$file_path" ]; do
        sleep 1
    done
    cat "$file_path"
}

# Phase 2: Get the temporary token when available.
#
# Function to check temporary token availability
check_temporary_token_availability() {
    # After Artifactory boots for the first time it generates a temporary token
    # in its internal file system. We have access to it through the Docker Volume
    # Temporary file
    temporaryTokenAtDockerVolume="/var/opt/jfrog/artifactory/etc/access/keys/token.json"
    # Read the file and grab the token
    token_data=$(wait_for_file_and_read "$temporaryTokenAtDockerVolume")
    log_message "INFO" "Temporary token data retrieved: $token_data"
    #token=$(echo "$token_data" | grep -oP '(?<="token": ")[^"]+')
    # Extract token using jq
    temporaryToken=$(echo "$token_data" | grep -oP '(?<="token":")[^"]*')
    #jq -r '.token')
}

# Phase 3: Create the permanent token
#
# Function to create a permanent token using the temporals token
create_permanent_token() {
    local token="$temporaryToken"
    local base_url="http://localhost:8082/access/api/v1/tokens"

    # JSON data to be sent in the request
    local jsondata='{
        "scope": "applied-permissions/admin",
        "expires_in": "315360000",
        "include_reference_token": "true",
        "token_type": "access_token"
    }'

    log_message "INFO" "Creating permanent Token"

    # Make the POST request using curl
    response=$(curl -s -w "%{http_code}" -o response_body.json -X POST "$base_url" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d "$jsondata")

    log_message "INFO" "Permanent token creation response status: $response"

    # Extract the HTTP status code
    status_code=$(tail -n1 <<<"$response")

    if [[ "$status_code" -eq 200 || "$status_code" -eq 201 ]]; then
        log_message "INFO" "Permanent token created successfully."
        token_data=$(<response_body.json)
        echo "$token_data" >"$PERMANENT_ADMIN_TOKEN"
        return 0
    else
        log_message "ERROR" "Failed to create the permanent token. Status code: $status_code"
        log_message "ERROR" "Response body:"
        cat response_body.json >>${LOGFILE}
        rm -f response_body.json # Clean up the temporary file
        return 1
    fi
}

# MAIN
# --------------------------------------------------------------------
#
# We will execute our code ONLY IF IT'S MY FIRST RUN IN THIS CONTAINER
#
# If you need to check the log:
#   docker exec -u 0 -it ct_artifactory /bin/bash
#   tail -f entrypoint-firstrun.log
#
# Our first time?
if [ ! -f "$IWASHERE" ] || [ -z "${PERMANENT_ADMIN_TOKEN}" ]; then

    # IMPORTANT: Our workdir should be /opt/jfrog/artifactory/var
    #
    cd /opt/jfrog/artifactory/var

    # Copy custome files if any
    if [ -f ${CONFIG_ROOT}/system.yaml ]; then
        cp ${CONFIG_ROOT}/system.yaml /opt/jfrog/artifactory/var/etc
    fi
    if [ -f ${CONFIG_ROOT}/logback.xml]; then
        cp ${CONFIG_ROOT}/logback.xml /opt/jfrog/artifactory/var/etc/artifactory
    fi
    if [ -f ${CONFIG_ROOT}/artifactory.repository.config.json ]; then
        cp ${CONFIG_ROOT}/artifactory.repository.config.json /opt/jfrog/artifactory/var/etc/artifactory/artifactory.repository.config.import.json
    fi
    if [ -f ${CONFIG_ROOT}/access.config.template.yml ]; then
        cp ${CONFIG_ROOT}/access.config.template.yml /opt/jfrog/artifactory/var/etc/access/access.config.import.yml
    fi

    # Set the correct working directory
    mkdir -p token
    chown 1030:1030 token

    # Check if it's my first run
    if [ ! -f "$IWASHERE" ] || [ -z "${PERMANENT_ADMIN_TOKEN}" ]; then

        # Make sure we recreate the Tokens
        rm -f "./token/${PERMANENT_ADMIN_TOKEN}"
        rm -f "./token/${PERMANENT_ADMIN_TOKEN_SCRIPT}"
        rm -f "./token/${PERMANENT_ADMIN_TOKEN_SCRIPT_BAT}"

        # If the file does not exist, create it
        touch "$IWASHERE"
        log_message "INFO" "File $IWASHERE created."

        # Phase 1: Ask Artifactory to create the temporary token
        prepare_files
        log_message "INFO" "File preparation for token creation finished."

        # Wait till Artifactory is up and running (give it 5 minutes)
        check_artifactory_health 300
        log_message "INFO" "Artifactory health check completed."

        # Phase 2: Wait till Temporary Token is available
        log_message "INFO" "Checking temporary token availability."
        check_temporary_token_availability
        if [ -z "$temporaryToken" ]; then
            log_message "ERROR" "Failed to retrieve Temporary Token."
        else
            log_message "INFO" "Temporary Token retrieved: $temporaryToken"
        fi

        # Phase 3: Create permanent token consuming the temporary one
        create_permanent_token
        # Check if the function succeeded
        if [ -z "${PERMANENT_ADMIN_TOKEN}" ]; then
            log_message "ERROR" "Failed to create and save the permanent token."
        else
            # Write the return value to a file
            log_message "INFO" "Permanent token saved to ${PERMANENT_ADMIN_TOKEN}"
            cp ${PERMANENT_ADMIN_TOKEN} ./token

            # Extract the reference_token value using bash parameter expansion
            reference_token=$(cat ${PERMANENT_ADMIN_TOKEN} | sed -n 's/.*"reference_token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

            # Write the export statement to permamentAdminToken.sh
            echo "export ARTIFACTORY_ADMIN_SCOPED_TOKEN=\"$reference_token\"" >./token/${PERMANENT_ADMIN_TOKEN_SCRIPT}
            # Write the export statement to permamentAdminToken.BAT
            cat <<EOF | sed $'s/$/\r/' >./token/${PERMANENT_ADMIN_TOKEN_SCRIPT_BAT}
@echo off
set ARTIFACTORY_ADMIN_SCOPED_TOKEN=$reference_token
EOF

            # Last try to change the admin's password
            if [ ! -z "${ADMIN_PASSWORD}" ] && [ "${admin_password_changed}" = false ]; then
                sleep 5
                changeAdminPassword 0
                result=$?
                if [ $result -eq 0 ]; then
                    admin_password_changed=true
                    log_message "INFO" "Admin password successfully changed. Stopping further attempts."
                fi
            fi

            # Make sure permissions are all set correct
            chown -R 1030:1030 token

        fi

    else
        log_message "INFO" "File $IWASHERE already exists, not executing token creation."
        log_message "INFO" "The permanent token should already be in the container."
    fi

fi

# Final log show time to fully boot Artifactory
artifactory_boot_time_elapsed=$(($(date +%s) - artifactory_boot_start_time))
log_message "INFO" "Artifactory boot time: $artifactory_boot_time_elapsed seconds"

# Run the arguments from CMD in the Dockerfile
# In our case we are starting nginx by default
exec "$@"
