#!/usr/bin/env bash
#
# entrypoint.sh for JFrog Artifactory OSS
#
# Run my background script to create a PERMANENT_ADMIN_TOKEN
#
cd /opt/jfrog/artifactory/var
./entrypoint-token.sh &

# Run the arguments from CMD in the Dockerfile
# In our case we are starting nginx by default
exec "$@"
