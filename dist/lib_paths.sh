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
    if echo "$1" | grep -F -qe '/' ; then
      v="${1%/*}"
    else
      v=""
    fi
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

# Prints the directory level of the specified path to stdout.
# Example 1: "./mymod.tp2" returns 1
# Example 2: "./mymod/mymod.tp2" return 2
# Example 3: "./subfolder/mymod/mymod.tp2" return 3
path_get_directory_level() {
  level=0
  if [ $# -gt 0 ]; then
    path=$(echo "$1" | xargs)
    path="${path#./*}"
    while [ -n "$path" ]; do
      path=$(path_get_parent_path "$path")
      level=$((level+1))
    done
  fi
  echo $level
}


# Prints the tp2 filename setup prefix to stdout.
# Default: "setup-" 
path_get_tp2_prefix() {
  prefix="setup-"
  if [ $# -gt 0 ]; then
    v=$(path_get_filebase "$1")
    if echo "$v" | grep -qie "^setup-" ; then
      prefix="${v:0:6}"
    fi
  fi
  echo "$prefix"
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

  shopt -s globstar
  tp2_array=""
  for tp2_path in $root_path/**/*.tp2; do
    tp2_path="./${tp2_path#$root_path/}"
    dlevel=$(path_get_directory_level "$tp2_path")
    if [ $dlevel -gt 2 ]; then
      printerr "Skipping: $tp2_path"
      continue
    fi
    tp2_path_lower=$(to_lower "$tp2_path")

    # Checking modern style tp2 location (mymod/[setup-]mymod.tp2)
    # parent folder name
    tp2_parent=$(path_get_parent "$tp2_path_lower")

    # tp2 filename
    tp2_file=$(path_get_filename "$tp2_path_lower")

    # tp2 filename without extension and "setup-" prefix
    tp2_file_base=$(path_get_tp2_name "$tp2_path_lower")

    # Applying mod filter
    if [ -n "$mod_filter" ]; then
      if [ "${mod_filter,,}" != "$tp2_file_base" ]; then
        printerr "Filter does not match. Skipping: $tp2_path"
        continue
      fi
    fi

    # Modern style tp2 file found?
    if [ "$tp2_file_base" = "$tp2_parent" ]; then
      # base directory for mod structure
      parent_path=$(path_get_parent_path "$tp2_path")
      parent_path=$(path_get_parent_path "$parent_path")

      # rebasing tp2 path
      tp2_path="./${tp2_path//$parent_path\//}"

      if [ -n "$tp2_array" ]; then
        tp2_array="$tp2_array$delimiter"
      fi
      tp2_array="$tp2_array$parent_path$delimiter$tp2_path$delimiter"
      continue
    fi

    # Checking old style tp2 location ([setup-]mymod.tp2 in root folder)
    # Note: parsing BACKUP definitions may not handle unusual path constellations well, e.g. paths containing relative path placeholders
    # String delimited by tilde signs (~)
    backup_path=$(cat "$tp2_path" | grep '^\s*BACKUP\s\+~' | sed -re 's/^\s*BACKUP\s+~([^~]+)~.*/\1/')
    if [ -z "$backup_path" ]; then
      # String delimited by double quotes (")
      backup_path=$(cat "$tp2_path" | grep '^\s*BACKUP\s\+"' | sed -re 's/^\s*BACKUP\s+"([^"]+)".*/\1/')
      if [ -z "$backup_path" ]; then
        # String delimited by percent signs (%)
        backup_path=$(cat "$tp2_path" | grep '^\s*BACKUP\s\+%' | sed -re 's/^\s*BACKUP\s+%([^%]+)%.*/\1/')
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

      tp2_array="$tp2_array$parent_path$delimiter$tp2_path$delimiter$mod_folder_path"
    fi
  done
  shopt -u globstar

  echo "$tp2_array"
}


# Generates the mod archive filename from the given parameters and global variables
# and prints it to stdout.
# Expected parameters: tp2_mod_path, version_suffix, ini_file
create_package_name() {
  if [ $# -gt 0 ]; then
    tp2_mod_path="$1"
  fi

  if [ $# -gt 1 ]; then
    version_suffix="$2"
  fi

  if [ $# -gt 2 ]; then
    ini_file="$3"
  fi

  if [ "$archive_type" = "iemod" ]; then
    archive_ext=".iemod"
  else
    archive_ext=".zip"
  fi

  # Platform-specific prefix needed to prevent overwriting package files
  case "$archive_type" in
    windows)
      os_prefix="$prefix_win"
      ;;
    linux)
      os_prefix="$prefix_lin"
      ;;
    macos)
      os_prefix="$prefix_mac"
      ;;
    *)
      os_prefix=""
  esac

  # Determine archive base name
  archive_filebase=""

  if [ "$naming" = "ini" ]; then
    # Determine ini file
    ini_path="$ini_file"
    if [ -z "$ini_path" ]; then
      namebase=$(path_get_filename "$tp2_mod_path")
      if [ -f "$tp2_mod_path/${namebase}.ini" ]; then
        ini_path="$tp2_mod_path/${namebase}.ini"
      elif [ -f "$tp2_mod_path/setup-${namebase}.ini" ]; then
        ini_path="$tp2_mod_path/setup-${namebase}.ini"
      fi
    fi

    # Fetch "name" value from ini file
    if [ -n "$ini_path" -a -f "$ini_path" ]; then
      name=$(cat "$ini_path" | grep -e '^\s*Name\s*=.*' | sed -re 's/^\s*Name\s*=\s*(.*)/\1/' | xargs)
      if [ -n "$name" ]; then
        archive_filebase=$(normalize_filename "$name" | tr " " "-")
      fi
    fi

    if [ -z "$archive_filebase" ]; then
      naming="tp2"
    fi
  fi

  if [ "$naming" = "tp2" ]; then
    archive_filebase=$(path_get_filename "$tp2_mod_path")
  fi

  if [ -z "$archive_filebase" ]; then
    archive_filebase="$naming"
  fi

  echo "${os_prefix}${archive_filebase}${extra}${version_suffix}${archive_ext}"
}
