#!/bin/bash

# Copyright (c) 2024 Argent77

########################################################
# This script is not intended to be executed directly. #
########################################################

# Prints the normalized path string of the specified parameter to stdout.
# Normalized path consists of forward-slashes as path separators
# and does not contain any relative path (./) instances.
path_normalize() {
  if [ $# -gt 0 ]; then
    echo "$1" | tr '\\' '/' | sed -e 's|^\./||' | sed -e 's|(/\./|/|'
  fi
}

# Prints the root path element of the specified parameter to stdout.
path_get_root() {
  if [ $# -gt 0 ]; then
    v="${1%/*}"
    echo "$v"
  fi
}


# Prints the parent path of the specified parameter to stdout.
path_get_parent_path() {
  if [ $# -gt 0 ]; then
    v="${1%/*}"
    echo "$v"
  fi
}


# Prints the parent path element of the specified parameter to stdout.
path_get_parent() {
  if [ $# -gt 0 ]; then
    v=$(path_get_parent_path "$1")
    v="${v##*/}"
    echo "$v"
  fi
}


# Prints the filename without path of the specified parameter to stdout.
path_get_filename() {
  if [ $# -gt 0 ]; then
    v="${1##*/}"
    echo "$v"
  fi
}


# Prints the filename without path and extension of the specified parameter to stdout.
path_get_filebase() {
  if [ $# -gt 0 ]; then
    v=$(path_get_filename "$1")
    v="${v%%.*}"
    echo "$v"
  fi
}


# Prints the tp2 filename without path, extension and "setup-" prefix of the specified parameter to stdout.
path_get_tp2_name() {
  if [ $# -gt 0 ]; then
    v=$(path_get_filebase "$1")
    if echo "$v" | grep -qie "^setup-" ; then
      v="${v:6}"
    fi
    echo "$v"
  fi
}


# Scans a path for files of a specified name pattern and prints the first match to stdout if available.
# Expected parameters: search path, "find" name pattern
find_file() {
  if [ $# -gt 1 ]; then
    root="$1"
    if [ -z "$root" ]; then
      root="."
    fi

    for file in $(find "$1" -maxdepth 1 -type f -name "$2"); do
      echo "$file"
      return
    done
  fi
}


# Looks for the first valid .tp2 file in the path.
# Optional parameters: root path (Otherwise the current directory is used.)
# Prints a colon-separated list (:) of path elements to stdout if successful:
# - relative base directory for the mod structure
# - path of the .tp2 file
# - (optional) mod folder path (for old-style mods only)
find_tp2() {
  delimiter=":"
  root_path="."
  if [ $# -gt 0 ]; then
    root_path="$1"
  fi

  for tp2_path in $(find "$root_path" -type f -iname "*\.tp2"); do
    tp2_path_lower=$(to_lower "$tp2_path")

    # Checking modern style tp2 location (mymod/[setup-]mymod.tp2)
    # parent folder name
    tp2_parent=$(path_get_parent "$tp2_path_lower")

    # tp2 filename
    tp2_file=$(path_get_filename "$tp2_path_lower")

    # tp2 filename without extension and "setup-" prefix
    tp2_file_base=$(path_get_tp2_name "$tp2_path_lower")

    # Modern style tp2 file found?
    if [ "$tp2_file_base" = "$tp2_parent" ]; then
      # base directory for mod structure
      parent_path=$(path_get_parent_path "$tp2_path")
      parent_path=$(path_get_parent_path "$parent_path")

      # rebasing tp2 path
      tp2_path="./${tp2_path//$parent_path\//}"

      echo "${parent_path}${delimiter}${tp2_path}${delimiter}"
      return 0
    fi

    # Checking old style tp2 location ([setup-]mymod.tp2 in root folder)
    # Note: parsing BACKUP definitions may not handle unusual path constellations well, e.g. paths containing relative path placeholders
    # String delimited by tilde signs (~)
    backup_path=$(cat "$tp2_path" | grep '^\s*BACKUP' | sed -re 's/^\s*BACKUP\s+~([^~]+)~.*/\1/')
    if [ -z "$backup_path" ]; then
      # String delimited by double quotes (")
      backup_path=$(cat "$tp2_path" | grep '^\s*BACKUP' | sed -re 's/^\s*BACKUP\s+"([^"]+)".*/\1/')
      if [ -z "$backup_path" ]; then
        # String delimited by percent signs (%)
        backup_path=$(cat "$tp2_path" | grep '^\s*BACKUP' | sed -re 's/^\s*BACKUP\s+%([^%]+)%.*/\1/')
        if [ -z "$backup_path" ]; then
          continue
        fi
      fi
    fi

    # Checking for malformed BACKUP definition
    if echo "$backup_path" | grep -qe '^\s*BACKUP' ; then
      continue
    fi

    backup_path=$(path_normalize "$backup_path")
    mod_folder=$(path_get_root "$backup_path")
    if [ -d "$tp2_parent/$mod_folder" ]; then
      # base directory for mod structure
      parent_path=$(path_get_parent_path "$tp2_path")

      # rebasing tp2 path
      tp2_path="./${tp2_path//$parent_path\//}"

      mod_folder_path=$(path_get_parent_path "$tp2_path")
      mod_folder_path="$mod_folder_path/$mod_folder"

      echo "${parent_path}${delimiter}${tp2_path}${delimiter}${mod_folder_path}"
      return 0
    fi
  done
}
