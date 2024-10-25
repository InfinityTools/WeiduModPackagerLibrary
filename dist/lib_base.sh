#!/bin/bash

# Copyright (c) 2024 Argent77

########################################################
# This script is not intended to be executed directly. #
########################################################

# A set of characters in filenames that require special care
special_characters_regex='[<>|*?$&"/\\]'
remove_characters_regex='[:]'

# Trims leading and trailing whitespace and an optional set of characters from the
# piped string and prints it to stdout.
# Expected parameters: [chars_to_trim]
trim() {
  v=$(sed -re 's/^\s+//;s/\s+$//')
  if [ $# -gt 0 -a -n "$1" ]; then
    v=$(echo "$v" | sed -re "s/^[$1]+//;s/[$1]+$//")
  fi
  echo "$v"
}


# Prints a lower-cased version of the specified string parameter to stdout.
to_lower() {
  if [ $# -gt 0 ]; then
    echo "${1,,}"
  fi
}


# Prints the given string parameter with all special characters replaced by a second parameter.
# Expected parameters: string, [replacement]
# Default replacement if second parameter is omitted: underscore (_)
normalize_filename() {
  if [ $# -gt 0 ]; then
    replace="${2:-_}"
    v="$1"
    v="${v// - /-}" # purely cosmetic replacement
    v="${v//${remove_characters_regex}/}"
    v="${v//${special_characters_regex}/${replace}}"
    v=$(echo "$v" | tr -d '[\000-\037]')  # remove non-printable characters
    echo "$v"
  fi
}


# Decodes specially encoded characters in the URL strings and prints it to stdout.
# Expected parameter: [string]
# Decodes the piped string content if no parameter is specified.
decode_url_string() {
  if [ $# -gt 0 ]; then
    echo "$1" | sed -e 's/%\([0-9A-F][0-9A-F]\)/\\\\\x\1/g' | xargs echo -e
  else
    sed -e 's/%\([0-9A-F][0-9A-F]\)/\\\\\x\1/g' | xargs echo -e
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


# Cleans up and normalizes a given version string and prints it to stdout.
# Expected parameters: version_string, beautify (1), [replacement_for_space]
normalize_version() {
  if [ $# -gt 0 ]; then
    v="$1"
    _beautify=$([ "${2:-1}" = "1" ] && echo "1" || echo "0")
    _repl="$3"

    v=$(echo "$v" | trim)

    if [ $_beautify -eq 1 ]; then
      # Any whitespace between 'v' prefix and version number will be removed
      if echo "$v" | grep -qie '^v\?\s\+[0-9]\+' ; then
        v=$(echo "$v" | sed -re 's/^[vV]\s+/v/')
      fi
    fi

    # (Optional) Replacing whitespace characters
    if [ -n "$_repl" ]; then
      v=$(echo "$v" | tr -s '[:blank:]' "$_repl")
    fi

    # Removing everything after the first whitespace character
    v=$(echo "$v" | sed -re 's/\s.*//')

    # Removing illegal characters for filenames
    v=$(normalize_filename "$v")

    if [ $_beautify -eq 1 ]; then
      # Use lowercased 'v' prefix for version string
      if echo "$v" | grep -qe '^V[0-9]\+' ; then
        v="v${v:1}"
      fi

      # Version string uses 'v' prefix
      if echo "$v" | grep -qe '^[0-9]\+' ; then
        v="v$v"
      fi
    fi

    echo "$v"
  fi
}


#####################################
#     Start of script execution     #
#####################################

# Checking required tools
for tool in "cat" "curl" "find" "grep" "head" "jq" "sed" "tr" "unzip" "zip" "zipinfo"; do
  if ! which $tool >/dev/null 2>&1; then
    printerr "ERROR: Tool not found: $tool"
    exit 1
  fi
done
