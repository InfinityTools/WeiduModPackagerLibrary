@echo off
setlocal EnableDelayedExpansion

REM ###########################################################
REM #  Windows batch script for interactive mod installation  #
REM ###########################################################

REM Set "use_legacy" to 1 if the mod should prefer the legacy WeiDU binary on Windows
set use_legacy=0

REM Set "autoupdate" to 0 to skip the process of auto-updating the WeiDU binary
set autoupdate=1

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
if not x%script_base:setup-=%==x%script_base% goto :auto_update

%weidu_path% %*
exit /b

:auto_update
if %autoupdate% equ 0 goto :run_setup

echo Performing WeiDU auto-update...

REM Getting current WeiDU version
for /f "tokens=4" %%v in ('%weidu_path% --version') do (
  set old_version=%%v
  set cur_version=%%v
  set cur_file=
)

REM Finding setup binary of higher version than reference WeiDU binary
for /r %%f in (setup-*.exe) do (
  for /f "tokens=4 usebackq" %%v in (`%%~nxf --version`) do (
    REM Verify that "version" is a valid number
    set "var="&for /f "delims=0123456789" %%i in ("%%v") do set var=%%i
    if not defined var (
      if %%v gtr !cur_version! (
        REM Consider only stable releases
        set ver=%%v:00=
        if not !ver! == %%v (
          set cur_version=%%v
          set cur_file=%%~nxf
        )
      )
    )
  )
)

REM Updating WeiDU binary
if not [%cur_file%] == [] (
  echo Updating WeiDU binary: %old_version% =^> %cur_version%
  copy /b /y "%cur_file%" "%weidu_path%" >nul
)

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
