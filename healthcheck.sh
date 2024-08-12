#!/usr/bin/env sh

# Test an HTTP site, return any error or http error
curl_test() {
    MSG=$1
    ERR=$2
    URL=$3
    echo -n ${MSG}
    http_code=`curl -o /dev/null -s -w "%{http_code}\n" ${URL}`
    ret=$?
    if [ "${ret}" != 0 ]; then
        echo " - ${ERR}, return code: ${ret}"
        return ${ret}
    else
        if [ "${http_code}" != 200 ]; then
            echo " - ${ERR}, HTTP code: ${http_code}"
            return 1
        fi
    fi
    return 0
}

# Test Artifactory health
curl_test "Test Artifactory health" "Error testing Artifactory health" "http://127.0.0.1:8082/router/api/v1/system/health" || { ret=${?}; exit ${ret}; }
echo " Ok."

# All passed
exit 0
