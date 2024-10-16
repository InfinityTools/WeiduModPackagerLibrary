@echo off

REM ###########################################################
REM #  Windows batch script for interactive mod installation  #
REM ###########################################################

REM Set "use_legacy" to 1 if the mod should prefer the legacy WeiDU binary on Windows
set use_legacy=0

cd /d %~dp0
set script_base=%~n0
set mod_name=%script_base:setup-=%

if %use_legacy% equ 0 goto :arch_check
set arch=x86-legacy
goto :arch_set

:arch_check
if /i "%PROCESSOR_ARCHITECTURE%" == "amd64" goto :arch_amd64
set arch=x86
goto :arch_set

:arch_amd64
set arch=amd64

:arch_set
set weidu_path=weidu_external\tools\weidu\win32\%arch%\weidu.exe
if exist %weidu_path% goto :weidu_found

set weidu_path=weidu_external\tools\weidu\win32\weidu.exe
if exist %weidu_path% goto :weidu_found

set weidu_path=weidu_external\tools\weidu\win32\x86\weidu.exe
if exist %weidu_path% goto :weidu_found

echo ERROR: WeiDU binary not found: %weidu_path%
exit /b 1

:weidu_found
if not x%script_base:setup-=%==x%script_base% goto :run_setup

%weidu_path% %*
exit /b

:run_setup
set tp2_path=%mod_name%\%mod_name%.tp2
if exist %tp2_path% goto :tp2_found

set tp2_path=%mod_name%\setup-%mod_name%.tp2
if exist %tp2_path% goto :tp2_found

set tp2_path=%mod_name%.tp2
if exist %tp2_path% goto :tp2_found

set tp2_path=setup-%mod_name%.tp2
if exist %tp2_path% goto :tp2_found

echo ERROR: Could not find "%mod_name%.tp2" or "setup-%mod_name%.tp2" in any of the supported locations.
exit /b 1

:tp2_found
%weidu_path% "%tp2_path%" --log "%script_base%.debug" %*
