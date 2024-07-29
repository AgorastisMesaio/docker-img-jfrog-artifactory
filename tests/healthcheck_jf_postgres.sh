#!/usr/bin/env bash
#
# Postgres DB for JFrog Artifactory HEALTH CHECK
#
echo "POSTGRESQL DB for JFrog Artifactory HEALTH CHECK"
docker exec -t ct_postgres psql -U artifactory -d artifactory -c 'SELECT "repository_key" FROM "repository_config" LIMIT 10' > /dev/null
if [ "$?" != "0" ]; then
    echo "ERROR"
    exit 1
fi
echo "OK"
exit 0

