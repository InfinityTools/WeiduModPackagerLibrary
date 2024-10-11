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
# Expected parameters: platform
get_bin_ext() {
  if [ $# -gt 0 ]; then
    if [ "$1" = "windows" ]; then
      echo ".exe"
    fi
  fi
}


# Splits an array of string values into individual variables.
# Expected parameters: string_array, delimiter, out_var1, out_var2, ...
#   string_array: The string with multiple elements, separated by "delimiter".
#   remainder: The remaining string content of "string_array" when the operation is completed.
#   delimiter: Delimiter that separates each string element in "string_array".
#   out_var1, out_var2, ...: A variable number of variable names which are initialized with the individual "string_array" elements.
split_to_vars() {
  if [ $# -gt 3 ]; then
    _content="$1"
    _output="$_content"
    _outvar="$2"
    _delim="$3"
    shift 3

    old_ifs=$IFS
    IFS=$_delim
    for item in $_content; do
      if [ $# -eq 0 ]; then
        break
      fi
      eval "$1"='"$item"'
      if echo "$_output" | grep -F -qe "$_delim" ; then
        _output="${_output#$item$_delim}"
      else
        _output=""
      fi
      shift
    done
    IFS=$old_ifs

    # clearing remaining variables
    while [ $# -gt 0 ]; do
      eval "$1"='""'
      shift
    done

    eval "$_outvar"='"$_output"'
  fi
}


# Deletes the specified files.
# Expected parameters: file1, ...
clean_up() {
  while [ $# -gt 0 ]; do
    test -n "$1" && rm -rfv "$1"
    shift
  done
}


#####################################
#     Start of script execution     #
#####################################

# Checking required tools
for tool in "cat" "curl" "find" "grep" "jq" "unzip" "zip"; do
  which $tool >/dev/null || ( printerr "ERROR: Tool not found: $tool"; exit 1 )
done
