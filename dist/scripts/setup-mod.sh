#!/bin/sh

##################################################################
#  Multi-platform shell script for interactive mod installation  #
##################################################################

# Set "autoupdate" to 0 to skip the process of auto-updating the WeiDU binary
autoupdate=1

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

cd "${0%[/\\]*}"

script_name="${0##*[/\\]}"
script_base="${script_name%.*}"
mod_name="${script_base#setup-}"

# Special: Windows installation is invoked directly by the setup binary
if test "${os}" = "win32" ; then
  setup_binary="./${script_base}${exe}"
  if test -e "${setup_binary}" ; then
    chmod +x "${setup_binary}"
    "${setup_binary}" "$@"
    exit $?
  else
    echo "ERROR: Setup binary not found: ${setup_binary}"
    exit 1
  fi
fi

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


# This function prints the version number of the specified binary to stdout.
# Prints 0 if version cannot be determined.
# Expected parameters: bin_path
get_bin_version() {
  if test $# -gt 0 ; then
    if test -x "$1" ; then
      v=$("$1" --version 2>/dev/null)
      if test $? -eq 0 ; then
        sig=$(echo "$v" | sed -re 's/^.*\[.+\]([^0-9]+).*/\1/')
        if echo "$sig" | grep -F -qe 'WeiDU' ; then
          v=$(echo "$v" | sed -re 's/^.*\[.+\][^0-9]+([0-9]+).*/\1/')
          if $(echo "$v" | grep -qe '^[0-9]\+$') ; then
            echo "$v"
            return
          fi
        fi
      fi
    fi
  fi
  echo "0"
}

setup_prefix=$(echo "$script_base" | cut -c 1-6)
if test "$setup_prefix" != "setup-" ; then
  "${weidu_path}" "$@"
else
  if test $autoupdate -ne 0 ; then
    echo "Performing WeiDU auto-update..."
    # Getting current WeiDU version
    old_version=$(get_bin_version "${weidu_path}")
    cur_version="${old_version}"
    cur_file=

    # Finding setup binary of higher version than reference WeiDU binary
    for file in $(find . -maxdepth 1 -type f -name "setup-*${exe}"); do
      # Consider only executable files
      if test -x "${file}" ; then
        # Consider only binary files
        if $(file -b --mime-type "${file}" | grep -qe '^application/') ; then
          version=$(get_bin_version "${file}")
          if test $version -gt $cur_version ; then
            # Consider only stable releases
            if $(echo "$version" | grep -qe '00$') ; then
              cur_version="${version}"
              cur_file="${file}"
            fi
          fi
        fi
      fi
    done

    # Updating WeiDU binary
    if test -n "${cur_file}" ; then
      echo "Updating WeiDU binary: ${old_version} => ${cur_version}"
      cp -f "${cur_file}" "${weidu_path}"
    fi
  fi

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
