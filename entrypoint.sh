#!/usr/bin/env bash
#
# entrypoint.sh for JFrog Artifactory OSS
#
# Run my background script to:
# - Create a PERMANENT_ADMIN_TOKEN
# - Change Admin's password
#
cd /opt/jfrog/artifactory/var
./entrypoint-background.sh &

# Run the arguments from CMD in the Dockerfile
# In our case we are starting nginx by default
exec "$@"
