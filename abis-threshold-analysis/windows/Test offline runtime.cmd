@echo off
setlocal
cd /d "%~dp0"
set "R_LIBS_USER=%~dp0library"
set "R_LIBS_SITE=%~dp0library"
set "ABIS_RSCRIPT=%~dp0runtime\bin\Rscript.exe"
if not exist "%ABIS_RSCRIPT%" set "ABIS_RSCRIPT=%~dp0runtime\bin\x64\Rscript.exe"
"%ABIS_RSCRIPT%" --vanilla "%~dp0verify_runtime.R"
set "ABIS_TEST_RESULT=%ERRORLEVEL%"
pause
exit /b %ABIS_TEST_RESULT%
