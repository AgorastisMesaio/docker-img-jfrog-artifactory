@echo off
REM
REM Test script that checks Artifactory Health, then deploys (upload)
REM and then downloads (resolves) same image and compares checksums
REM

REM Enable delayed variable expansion, useful to work with
REM Variables inside code blocks
setlocal enabledelayedexpansion

REM ----- VARIABLEs START SECTION (do not modify) -------
REM Load the variables file
set SCRIPT_DIR=%~dp0
set SETUP_VARS=%SCRIPT_DIR%0.SETUP_VARS.BAT
if not exist %SETUP_VARS% (
    echo Error! file %SETUP_VARS% doesn't exist
    exit /b 1
)
call %SETUP_VARS%
REM ----- VARIABLEs END SECTION -------------------------

REM Init
REM Check needed variables in this script, space or new line separated
set variables=ARTIFACTORY_ADMIN_SCOPED_TOKEN ARTIFACTORY_PREFIX ARTIFACTORY_REPO
for %%i in (%variables%) do (
    if "!%%i!"=="" (
        echo ERROR!! The variable %%i is unset or empty. Check %SETUP_VARS%
        exit /b 1
    )
)

REM Test health
call test_artifactHealth.bat
if not "%errorlevel%"=="0" (
    echo ERROR %errorlevel%
    exit /b 1
)

REM Get timestamp
for /f "tokens=2 delims==" %%i in ('wmic os get localdatetime /value') do set dt=%%i
set timestamp=%dt:~0,8%-%dt:~8,6%

REM Test upload
echo Checking JFrog ARTIFACTORY Upload/Download
set TEST_FILE=test-image.bin
curl -H "Authorization: Bearer %ARTIFACTORY_ADMIN_SCOPED_TOKEN%" -T bin_upload/%TEST_FILE% "%ARTIFACTORY_PREFIX%/%ARTIFACTORY_REPO%/%timestamp%-%TEST_FILE%" >nul 2>&1
if not "%errorlevel%"=="0" (
    echo %RESERROR%
    exit /b 1
)

REM Test download
mkdir bin_downloads >nul 2>&1
curl -s -H "Authorization: Bearer %ARTIFACTORY_ADMIN_SCOPED_TOKEN%" -L -o bin_downloads/%timestamp%-%TEST_FILE% -O "%ARTIFACTORY_PREFIX%/%ARTIFACTORY_REPO%/%timestamp%-%TEST_FILE%" >nul 2>&1
if not "%errorlevel%"=="0" (
    echo %RESERROR%
    exit /b 1
)

REM Compare uploaded/downloaded files
fc /b bin_upload\%TEST_FILE% bin_downloads\%timestamp%-%TEST_FILE%
if not "%errorlevel%"=="0" (
    echo Error, files are different
    exit /b 1
)
exit /b 0
