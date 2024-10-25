#!/bin/bash

# Copyright (c) 2024 Argent77

########################################################
# This script is not intended to be executed directly. #
########################################################

# Validates all available arguments.
# Pass $@ to the function.
# Returns exit code 0 if all arguments passed the check, 1 otherwise.
eval_arguments() {
  while [ $# -gt 0 ]; do
    case $1 in
      type= | type=iemod | type=windows | type=linux | type=macos | type=multi)
        ;;
      arch= | arch=amd64 | arch=x86 | arch=x86-legacy | arch=x86_legacy)
        ;;
      suffix=*)
        ;;
      weidu=*)
        v="${1##*=}"
        if [ "$v" != "latest" ]; then
          if echo "$v" | grep -qe '^[0-9]\+$' ; then
            if [ $v -lt $weidu_min ]; then
              printerr "ERROR: Unsupported WeiDU version: $v"
              return 1
            fi
          else
            printerr "ERROR: Invalid WeiDU version: $v"
            return 1
          fi
        fi
        ;;
      extra=*)
        ;;
      naming=*)
        ;;
      prefix_win=*)
        ;;
      prefix_lin=*)
        ;;
      prefix_mac=*)
        ;;
      tp2_name=*)
        ;;
      name_fmt=*)
        ;;
      multi_autoupdate=true | multi_autoupdate=false | multi_autoupdate=[0-1])
        ;;
      case_sensitive=true | case_sensitive=false | case_sensitive=[0-1])
        ;;
      beautify=true | beautify=false | beautify=[0-1])
        ;;
      lower_case=true | lower_case=false | lower_case[0-1])
        ;;
      *)
        printerr "ERROR: Invalid argument: $1"
        return 1
        ;;
    esac
    shift
  done
  return 0
}


# Prints the archive type to stdout, based on the given parameters.
# Default: iemod
# Supported archive types:
#   iemod:    Creates a .iemod archive (does not include setup binary).
#   windows:  Creates a .zip file with a Windows setup binary.
#   linux:    Creates a .zip file with a Linux setup binary.
#   macos:    Creates a .zip file with a macOS setup binary and .command script file.
# Pass $@ to the function.
eval_type() {
  ret_val="iemod"
  while [ $# -gt 0 ]; do
    if echo "$1" | grep -qe '^type=' ; then
      param="${1#*=}"
      case $param in
        iemod | windows | linux | macos | multi)
          ret_val="$param"
          ;;
      esac
    fi
    shift
  done

  echo "$ret_val"
}


# Prints the suffix type for the mod archive filename to stdout, based on the given parameters.
# Default: version
# Supported suffix types:
#   version:  Derives the mod version from the VERSION string in the .tp2 file if available.
#             Falls back to empty suffix if unavailable.
#   none:     A symbolic name to indicate that no version suffix is added.
# Everything else is considered a literal string.
# In all cases, everything after the first occurence of whitespace is ignored.
# Pass $@ to the function.
eval_suffix() {
  ret_val="version"
  while [ $# -gt 0 ]; do
    if echo "$1" | grep -qe '^suffix=' ; then
      param="${1#*=}"
      case $param in
        none)
          ret_val=""
          ;;
        version)
          ret_val="$param"
          ;;
        *)
          if echo "$param" | grep -qe '^".*' ; then
          # Unwrap text in double quotes
            ret_val=$(echo "$param" | sed -re 's/^"([^"]*)".*/\1/')
          elif echo "$param" | grep -qe "^'.*" ; then
            # Unwrap text in single quotes
            ret_val=$(echo "$param" | sed -re "s/^'([^']*)'.*/\1/")
          else
            # No delimiters detected
            ret_val="$param"
          fi
          ;;
      esac
    fi
    shift
  done

  echo "$ret_val"
}


# Prints the architecture of the WeiDU binary to stdout, based on the given parameters.
# Default: amd64
# This parameter is currently only relevant for the Windows archive type.
# Supported architectures:
#   amd64:      Includes a 64-bit setup binary.
#   x86:        Includes a 32-bit setup binary.
#   x86-legacy: Includes a 32-bit setup binary with legacy Window support.
#               This option is needed to prevent mangling non-ASCII characters in resource names
#               (e.g. for Infinity Animations).
# Pass $@ to the function.
eval_arch() {
  ret_val="amd64"
  while [ $# -gt 0 ]; do
    if echo "$1" | grep -qe '^arch=' ; then
      param=$(echo "${1#*=}" | tr '_' '-')
      case $param in
        amd64 | x86 | x86-legacy)
          ret_val="$param"
          ;;
      esac
    fi
    shift
  done

  echo "$ret_val"
}


# Prints the specified WeiDU version (or "latest" keyword) to stdout, based on the given parameters.
# Default: "latest"
# Special version "latest" is placeholder for the latest available WeiDU version.
# Pass $@ to the function.
eval_weidu() {
  ret_val="latest"
  while [ $# -gt 0 ]; do
    if echo "$1" | grep -qe '^weidu=' ; then
      ret_val="${1#*=}"
    fi
    shift
  done

  echo "$ret_val"
}


# Prints the extra string to stdout, based on the given parameters.
# Default: (empty string)
# Special characters are replaced by underscores.
# Pass $@ to the function.
eval_extra() {
  ret_val=""
  while [ $# -gt 0 ]; do
    if echo "$1" | grep -qe '^extra=' ; then
      ret_val=$(normalize_filename "${1#*=}" | trim)
    fi
    shift
  done

  echo "$ret_val"
}


# Prints the naming scheme for mod package base name to stdout, based on given parameters.
# Default: tp2
# Supported schemes:
# - tp2: Use the mod's tp2 filename as package base name.
# - ini: Fetch name from PI metadata ini file if available.
# Everything else is treated as a literal string.
# Pass $@ to the function.
eval_naming() {
  ret_val="tp2"
  while [ $# -gt 0 ]; do
    if echo "$1" | grep -qe '^naming=' ; then
      param="${1#*=}"
      case $param in
        tp2 | ini)
          ret_val="$param"
          ;;
        *)
          if [ -n "$param" ]; then
            ret_val=$(normalize_filename "$param" | trim)
          fi
          ;;
      esac
    fi
    shift
  done

  echo "$ret_val"
}


# Used internally to print a normalized package name prefix to stdout.
# Expects a single parameter: prefix
_eval_prefix() {
  if [ $# -gt 0 ]; then
    v=$(normalize_filename "$1" | trim)
    if [ -n "$v" ]; then
      while [[ "$v" =~ ^.*-$ ]]; do
        v="${v::-1}"
      done
    fi
    echo "$v"
  fi
}


# Prints the os-specific package name prefix to stdout, based on given parameters.
# Default: win
# Pass $@ to the function.
eval_prefix_win() {
  ret_val="win"
  while [ $# -gt 0 ]; do
    if echo "$1" | grep -qe '^prefix_win=' ; then
      ret_val="${1#*=}"
    fi
    shift
  done

  _eval_prefix "$ret_val"
}


# Prints the os-specific package name prefix to stdout, based on given parameters.
# Default: lin
# Pass $@ to the function.
eval_prefix_lin() {
  ret_val="lin"
  while [ $# -gt 0 ]; do
    if echo "$1" | grep -qe '^prefix_lin=' ; then
      ret_val="${1#*=}"
    fi
    shift
  done

  _eval_prefix "$ret_val"
}


# Prints the os-specific package name prefix to stdout, based on given parameters.
# Default: mac
# Pass $@ to the function.
eval_prefix_mac() {
  ret_val="mac"
  while [ $# -gt 0 ]; do
    if echo "$1" | grep -qe '^prefix_mac=' ; then
      ret_val="${1#*=}"
    fi
    shift
  done

  _eval_prefix "$ret_val"
}


# Prints the tp2 filename (without path, "setup-" prefix and ".tp2" extension) to stdout,
# based on the given parameters.
# Default: (empty string)
eval_tp2_name() {
  ret_val=""
  while [ $# -gt 0 ]; do
    if echo "$1" | grep -qe '^tp2_name=' ; then
      param="${1#*=}"
      param="${param##*/}"
      if echo "$param" | grep -qie '\.tp2$' ; then
        param="${param%.*}"
      fi
      if echo "$param" | grep -qie '^setup-' ; then
        param="${param:6}"
      fi
      ret_val="$param"
    fi
    shift
  done

  echo "$ret_val"
}


# Prints the package name template string to stdout, based on the given parameters.
# Default: <%os_prefix%-><%base_name%><-%extra%><-%version%>
eval_name_format() {
  ret_val=""
  while [ $# -gt 0 ]; do
    if echo "$1" | grep -qe '^name_fmt=' ; then
      param="${1#*=}"
      if [ -n "$param" ]; then
        ret_val="$param"
      fi
    fi
    shift
  done

  if [ -z "$ret_val" ]; then
    ret_val="<%os_prefix%-><%base_name%><-%extra%><-%version%>"
  fi

  echo "$ret_val"
}


# Prints the enabled state of autoupdate feature for multi-platform package types to stdout,
# based on the given parameters.
# Default: 1
eval_multi_autoupdate() {
  ret_val=1
  while [ $# -gt 0 ]; do
    if echo "$1" | grep -qe '^multi_autoupdate=' ; then
      param="${1#*=}"
      case "${param,,}" in
        false | 0)
          ret_val=0
          ;;
        true | 1)
          ret_val=1
          ;;
        *)
          ;;
      esac
    fi
    shift
  done

  echo "$ret_val"
}


# Prints whether duplicate files in the same folder should be preserved to stdout,
# based on the given parameters.
# Default: 0
eval_case_sensitive() {
  ret_val=0
  while [ $# -gt 0 ]; do
    if echo "$1" | grep -qe '^case_sensitive=' ; then
      param="${1#*=}"
      case "${param,,}" in
        false | 0)
          ret_val=0
          ;;
        true | 1)
          ret_val=1
          ;;
        *)
          ;;
      esac
    fi
    shift
  done

  echo "$ret_val"
}


# Prints whether version suffixes should be "beautified" to stdout, based on the given parameters.
# Default: 1
eval_beautify() {
  ret_val=1
  while [ $# -gt 0 ]; do
    if echo "$1" | grep -qe '^beautify=' ; then
      param="${1#*=}"
      case "${param,,}" in
        false | 0)
          ret_val=0
          ;;
        true | 1)
          ret_val=1
          ;;
        *)
          ;;
      esac
    fi
    shift
  done

  echo "$ret_val"
}


# Prints whether mod package filenames should be lowercased to stdout, based on the given parameters.
# Default: 0
eval_lower_case() {
  ret_val=0
  while [ $# -gt 0 ]; do
    if echo "$1" | grep -qe '^lower_case=' ; then
      param="${1#*=}"
      case "${param,,}" in
        false | 0)
          ret_val=0
          ;;
        true | 1)
          ret_val=1
          ;;
        *)
          ;;
      esac
    fi
    shift
  done

  echo "$ret_val"
}


#####################################
#     Start of script execution     #
#####################################

# Base URL for the JSON release definition.
weidu_url_base="https://api.github.com/repos/WeiDUorg/weidu/releases"

# Earliest supported WeiDU version
weidu_min="246"

# Parameter check
eval_arguments "$@" || exit 1

# Supported types: iemod, windows, linux, macos, multi
archive_type=$(eval_type "$@")
echo "Archive type: $archive_type"

# Supported architectures: amd64, x86, x86-legacy
arch=$(eval_arch "$@")
if [ "$archive_type" = "iemod" ]; then
  echo "Architecture: <platform-neutral>"
else
  echo "Architecture: $arch"
fi

# Supported suffixes: none, version, <literal string>
suffix=$(eval_suffix "$@")
if [ "$suffix" = "version" ]; then
  echo "Suffix: <tp2 VERSION string>"
elif [ -z "$suffix" ]; then
  echo "Suffix: <none>"
else
  echo "Suffix: $suffix"
fi

# WeiDU versions: latest, <version number>
weidu_version=$(eval_weidu "$@")
echo "WeiDU version: $weidu_version"

# Declaring empty associative array "weidu_info"
# Elements can be initialized by the get_weidu_info() function
declare -A weidu_info
# Key names for the "weidu_info" array
key_tag_name="tag_name" # GitHub tag name of the WeiDU binary release
key_version="version"   # explicit WeiDU version (e.g. 249)
key_stable="stable"     # indicates whether the current WeiDU version is stable (i.e. not beta or wip)
key_arch="arch"         # architecture of the WeiDU binary
key_url="url"           # Download URL of the WeiDU zip archive
key_filename="filename" # Filename (without path) of the WeiDU zip archive
key_size="size"         # File size of the WeiDU zip archive, in bytes
key_bin="binary"        # Path of the local WeiDU binary (set by the WeiDU download function)

# Optional extra string
extra=$(eval_extra "$@")
if [ -n "$extra" ]; then
  echo "Extra suffix: '$extra'"
else
  echo "Extra suffix: <none>"
fi

# Package naming schemes: tp2, ini, <literal string>
naming=$(eval_naming "$@")
case $naming in
  tp2 | ini)
    echo "Naming scheme: $naming"
    ;;
  *)
    echo "Package base name: '$naming'"
    ;;
esac

# Name prefix for platform-dependent mod archives
prefix_win=$(eval_prefix_win "$@")
prefix_lin=$(eval_prefix_lin "$@")
prefix_mac=$(eval_prefix_mac "$@")
echo "OS-specific prefixes: '$prefix_win', '$prefix_lin', '$prefix_mac'"

# Mod to include in archive (as tp2 filebase)
mod_filter=$(eval_tp2_name "$@")
if [ -n "$mod_filter" ]; then
  echo "Mod filter: $mod_filter"
else
  echo "Mod filter: <none>"
fi

# The package name format as a template string
package_name_format=$(eval_name_format "$@")

# Enabled state of autoupdate feature for multi-platform mod packages
multi_autoupdate=$(eval_multi_autoupdate "$@")

# Whether to preserve duplicate files in the mod that only differ by case
case_sensitive=$(eval_case_sensitive "$@")

# Whether version numbers should be beautified
beautify=$(eval_beautify "$@")

# Whether mod package filenames should be lowercased
lower_case=$(eval_lower_case "$@")
