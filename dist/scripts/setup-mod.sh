#!/bin/sh

##################################################################
#  Multi-platform shell script for interactive mod installation  #
##################################################################

# Set "use_legacy" to 1 if the mod should prefer the legacy WeiDU binary on Windows
use_legacy=0

# Determining platform and binary file extension
uname_os="$(uname -s)"
case "${uname_os}" in
  Linux*)
    os="unix"
    exe=""
    ;;
  Darwin*)
    os="osx"
    exe=""
    ;;
  CYGWIN* | MINGW* | MSYS_NT*)
    os="win32"
    exe=".exe"
    ;;
  *)
    echo "ERROR: Could not determine platform: ${uname_os}"
    exit 1
    ;;
esac

# Determining architecture
uname_arch="$(uname -m)"
case "${uname_arch}" in
  amd64 | x86_64 | arm64)
    arch="amd64"
    ;;
  i[3456]86)
    arch="x86"
    ;;
  *)
    echo "ERROR: Could not determine architecture: ${uname_arch}"
    exit 1
    ;;
esac

if test "${os}" == "win32" ; then
  if test $use_legacy -ne 0 ; then
    arch="x86-legacy"
  fi
fi

cd "${0%[/\\]*}"

script_name="${0##*[/\\]}"
script_base="${script_name%.*}"
mod_name="${script_base#setup-}"

weidu_path="weidu_external/tools/weidu/${os}/${arch}/weidu${exe}"
if ! test -e "${weidu_path}" ; then
  weidu_path="weidu_external/tools/weidu/${os}/weidu${exe}"
  if ! test -e "${weidu_path}" ; then
    weidu_path="weidu_external/tools/weidu/${os}/x86/weidu${exe}"
    if ! test -e "${weidu_path}" ; then
      echo "ERROR: WeiDU binary not found: ${weidu_path}"
      exit 1
    fi
  fi
fi
chmod +x "${weidu_path}"

setup_prefix="${script_base:0:6}"
if test "$setup_prefix" != "setup-" ; then
  "${weidu_path}" "$@"
else
  if test -f "${mod_name}/${script_base}.tp2" ; then
    tp2_path="${mod_name}/${script_base}.tp2"
  elif test -f "${mod_name}/${mod_name}.tp2" ; then
    tp2_path="${mod_name}/${mod_name}.tp2"
  elif test -f "${mod_name}.tp2" ; then
    tp2_path="${mod_name}.tp2"
  elif test -f "${script_base}.tp2" ; then
    tp2_path="${script_base}.tp2"
  else
    echo "ERROR: Could not find \"${mod_name}.tp2\" or \"${script_base}.tp2\" in any of the supported locations."
    exit 1
  fi

  "${weidu_path}" "${tp2_path}" --log "${script_base}.debug" "$@"
fi
