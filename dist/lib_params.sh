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
      type= | type=iemod | type=windows | type=linux | type=macos)
        ;;
      suffix= | suffix=version | suffix=none | suffix=*)
        ;;
      arch= | arch=amd64 | arch=x86 | arch=x86-legacy | arch=x86_legacy)
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
#   linux:    Creates a .zip file with the Linux setup binary.
#   macos:    Creates a .zip file with the macOS setup binary and .command script file.
# Pass $@ to the function.
eval_type() {
  ret_val="iemod"
  while [ $# -gt 0 ]; do
    if echo "$1" | grep -F -qe 'type=' ; then
      param=$(echo "$1" | sed -e 's/type=//')
      case $param in
        iemod | windows | linux | macos)
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
    if echo "$1" | grep -F -qe 'suffix=' ; then
      param=$(echo "$1" | sed -e 's/suffix=//')
      case $param in
        none)
          ret_val=""
          ;;
        version)
          ret_val="$param"
          ;;
        *)
          # Unwrap text in double quotes
          ret_val=$(echo "$param" | sed -re 's/^"([^"]*)"/\1/')
          # Unwrap text in single quotes
          ret_val=$(echo "$ret_val" | sed -re "s/^'([^']*)'/\1/")
          # Remove text after the first whitespace character
          ret_val=$(echo "$ret_val" | sed -e 's/\s.*//')
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
    if echo "$1" | grep -F -qe 'arch=' ; then
      param=$(echo "$1" | sed -e 's/arch=//' | tr '_' '-')
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
