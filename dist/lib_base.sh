#!/bin/bash

# Copyright (c) 2024 Argent77

########################################################
# This script is not intended to be executed directly. #
########################################################

# A set of characters in filenames that require special care
special_characters_regex='[<>:|*?$"/\\]'


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


# Prints the given string parameter with all special characters replaced by a second parameter.
# Expected parameters: string, [replacement]
# Default replacement if second parameter is omitted: underscore (_)
normalize_filename() {
  if [ $# -gt 0 ]; then
    if [ $# -gt 1 ]; then
      replace="$2"
    else
      replace="_"
    fi
    echo "$1" | sed -re "s/$special_characters_regex/$replace/g" | tr -dc '[:print:]'
  fi
}

# Decodes specially encoded characters in the URL strings and prints it to stdout.
# Expected parameter: string
decode_url_string() {
  if [ $# -gt 0 ]; then
    echo "$1" | sed -e 's/%\([0-9A-F][0-9A-F]\)/\\\\\x\1/g' | xargs echo -e
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
