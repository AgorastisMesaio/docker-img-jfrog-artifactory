@echo off
REM
REM When Artifactory was provisioned you got the admin token to
REM consume the API.
REM
REM Use "reference_token" found under ./token/permanentAdminTkoen.json
REM
REM Additionally A helper script was created to prepare a variable
REM consumed by all the test scripts: ARTIFACTORY_ADMIN_SCOPED_TOKEN
set PERMANENT_ADMIN_TOKEN_SCRIPT=..\token\permanentAdminToken.bat
if exist "%PERMANENT_ADMIN_TOKEN_SCRIPT%" (
    call %PERMANENT_ADMIN_TOKEN_SCRIPT%
)

REM We do everything from admin
set ARTIFACTORY_USER=admin
REM The password we recommend to set during first time login/setup is this one
set ARTIFACTORY_PASSWORD=password

REM Repos
set ARTIFACTORY_URL=http://localhost:8082
set ARTIFACTORY_PREFIX=http://localhost:8082/artifactory
set ARTIFACTORY_IMG=sample-img-binary

REM Debug
REM echo %ARTIFACTORY_ADMIN_SCOPED_TOKEN%