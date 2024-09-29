#!/usr/bin/env bash

export ADMIN_PASSWORD="JustATest1234%"
export CHANGE_PASSWORD_TMP_FILE="/tmp/change_password_response"

# Function to log messages with date, time, and level
log_message() {
    local level="$1"
    shift
    local message="$@"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$level] $message"
}

http_code=$(curl -s -w "%{http_code}" -o ${CHANGE_PASSWORD_TMP_FILE} -X POST -u admin:password \
    -H "Content-type: application/json" \
    -d "{ \"userName\" : \"admin\", \"oldPassword\" : \"password\", \"newPassword1\" : \"${ADMIN_PASSWORD}\", \"newPassword2\" : \"${ADMIN_PASSWORD}\" }" \
    http://127.0.0.1:8082/artifactory/api/security/users/authorization/changePassword)

if [ "$http_code" -eq 200 ]; then
    log_message "INFO" "Admin password changed successfully. Http code: $http_code"
else
    log_message "ERROR" "Failed to change admin password. Http code: $http_code"
fi
