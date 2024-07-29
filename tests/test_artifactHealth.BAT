@echo off
REM
REM *****************************************
REM WORKS WITH JFrog Artifact OSS VERSION
REM *****************************************
REM
REM DEPENDENCIES:
REM ===========================================================
REM JQ for Windows: Ensure it's installed and in your PATH
REM Download from: https://stedolan.github.io/jq/download/
REM
REM Curl for Windows: Make sure curl is available on your system.
REM By default curl is installed on Win 10 & 11
REM

REM Enable delayed variable expansion, useful to work with
REM Variables inside code blocks
setlocal enabledelayedexpansion

REM ----- VARIABLEs START SECTION (do not modify) -------
REM Load the variables file
set SCRIPT_DIR=%~dp0
set SETUP_VARS=%SCRIPT_DIR%0.SETUP_VARS.bat
if not exist %SETUP_VARS% (
    echo Error! file %SETUP_VARS% doesn't exist
    goto :end_1
)
call %SETUP_VARS%
REM ----- VARIABLEs END SECTION -------------------------

REM Init
REM Check needed variables in this script, space or new line separated
set variables=ARTIFACTORY_USER ARTIFACTORY_PASSWORD ARTIFACTORY_ADMIN_SCOPED_TOKEN
for %%i in (%variables%) do (
    if "!%%i!"=="" (
        echo Error, the variable %%i is unset or empty. Check %SETUP_VARS%
        goto :end_1
    )
)

REM Check Health, save output into a file
set url=%ARTIFACTORY_URL%/router/api/v1/system/health
set "json_file=%TEMP%\artifactory_health_response"
REM echo Checking JFrog ARTIFACTORY Health:
curl -s --max-time 3 -w "%%{http_code}" -o "%json_file%" %url% >nul 2>&1
if not "%errorlevel%"=="0" (
    echo Artifactory is not working, Curl is returning an error
    goto :end_1
)
REM Get output from jq
for /f "tokens=*" %%i in ('cmd /c type %json_file% ^| jq -e "(.router.message == \"OK\") and (all(.services[].message; . == \"OK\"))" 2^>nul') do (
    set result=%%i
)
REM Double check result
if /i "!result!" == "true" (
    echo Artifactory is working
    goto :end_0
) else if /i "!result!" == "false" (
    echo Artifactory is not working
    goto :end_1
) else (
    echo Artifactory check error at jq command
    goto :end_1
)

:end_0
exit /b 0

:end_1
exit /b 1
