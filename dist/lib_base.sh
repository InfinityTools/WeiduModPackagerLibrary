#!/bin/bash

# Copyright (c) 2024 Argent77

########################################################
# This script is not intended to be executed directly. #
########################################################

# Prints a specified message to stderr.
printerr() {
  if [ $# -gt 0 ]; then
    printf "%s\n" "$*" >&2
  fi
}


# Prints a lower-cased version of the specified string parameter to stdout.
to_lower() {
  if [ $# -gt 0 ]; then
    echo "$1" | tr '[:upper:]' '[:lower:]'
  fi
}

# Returns the file extension used by executables.
# Expected parameters: architecture
get_bin_ext() {
  if [ $# -gt 0 ]; then
    if [ "$1" = "windows" ]; then
      echo ".exe"
    fi
  fi
}

# Checking required tools
for tool in "cat" "curl" "find" "grep" "jq" "unzip" "zip"; do
  which $tool >/dev/null || ( printerr "ERROR: Tool not found: $tool"; exit 1 )
done
