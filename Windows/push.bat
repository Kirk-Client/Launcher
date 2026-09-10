@echo off
setlocal EnableDelayedExpansion
pushd "%~dp0"

:: The system git on this machine fails to load libcurl-4.dll, so prefer the
:: git bundled with GitHub Desktop (whichever version folder is newest) and
:: only fall back to PATH git if that isn't found.
set "GIT="
for /f "delims=" %%d in ('dir /b /ad /o-n "%LOCALAPPDATA%\GitHubDesktop\app-*" 2^>nul') do (
    if not defined GIT (
        if exist "%LOCALAPPDATA%\GitHubDesktop\%%d\resources\app\git\cmd\git.exe" (
            set "GIT=%LOCALAPPDATA%\GitHubDesktop\%%d\resources\app\git\cmd\git.exe"
        )
    )
)
if not defined GIT set "GIT=git"

echo Using git: %GIT%
echo.

"%GIT%" add -A
if errorlevel 1 (
    echo FATAL: git add failed.
    popd
    pause
    exit /b 1
)

set "MSG=%~1"
if "%MSG%"=="" set "MSG=Update release"

"%GIT%" commit -m "%MSG%"
if errorlevel 1 (
    echo Nothing to commit, or commit failed - continuing to push anyway.
)

"%GIT%" push origin main
if errorlevel 1 (
    echo FATAL: git push failed.
    popd
    pause
    exit /b 1
)

echo.
echo Pushed to GitHub.
popd
