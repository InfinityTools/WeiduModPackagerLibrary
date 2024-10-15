#!/bin/bash

# Copyright (c) 2024 Argent77
# Version 1.3

# Supported parameters for script execution:
# type={archive_type}
# This parameter determines the resulting archive format.
# Supported archive types: iemod, windows, linux, macos
# - iemod:    Creates a zip archive with the .iemod extension and no setup binary.
# - windows:  Creates a regular zip archive which includes a Windows setup binary.
# - linux:    Creates a regular zip archive which includes a Linux setup binary.
# - macos:    Creates a regular zip archive which includes a macOS setup binary
#             and associated setup-*.command script file.
# Default archive type: iemod

# arch={architecture}
# This parameter determines the architecture of the included setup binary.
# It is currently only effective for Windows, as all other platforms provide only binaries
# for a single architecture.
# Supported architectures: amd64, x86, x86-legacy
# - x86-legacy: Specify this option to include a special WeiDU binary that is compatible with
#               older Windows versions and does not mangle non-ASCII characters in resource
#               filenames. This can be useful for specific mods, such as Infinity Animations.
# Default architecture: amd64

# suffix={type_or_string}
# Supported suffix type: version, none. Everything else is treated as a literal string.
# - none:    A symbolic name to indicate that no version suffix is added.
# - version: Uses the VERSION definition of the tp2 file of the mod.
# In all cases:
# - everything after the first whitespace character in the version string is ignored
# - illegal filename characters are replaced by underscores
# Default suffix: version

# extra={string}
# An arbitrary string that will be appended after the package base name but before the version suffix.
# Default: <empty string>

# naming: {type_or_string}
# This parameter defines the mod package base name.
# Supported naming types: tp2, ini. Everything else is treated as a literal string.
# - tp2: Uses the tp2 filename as base for generating the mod package base name.
# - ini: Fetches the "name" definition from the associated Project Infinity metadata ini file.
#        Falls back to "tp2" if not available.
# Default: tp2

# weidu: {type_or_number}
# WeiDU version to use for the setup binaries for platform-specific zip archives.
# Specify "latest" to use the latest WeiDU version, or a specific WeiDU version.
# Currently supported versions: 246 or later.
# Default: latest

# prefix_win, prefix_lin, prefix_mac: {string}
# Prefix string to use for platform-specific zip archive names.
# Default: win, lin, osx (for Windows, Linux and macOS platforms respectively)

# tp2_name: {string}
# This parameter defines the tp2 filename of the mod to include in the mod package.
# Specifying this option is only useful if a project contains multiple mods
# (e.g. EET, EET_end, EET_gui).
# Default: <empty string>


#####################################
#     Start of script execution     #
#####################################

# Prints a specified message to stderr.
printerr() {
  if [ $# -gt 0 ]; then
    printf "%s\n" "$*" >&2
  fi
}

# Including shell script libraries
DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
for name in "lib_base" "lib_params" "lib_paths" "lib_weidu"; do
  source "$DIR/${name}.sh"
  if [ $? -ne 0 ]; then printerr "ERROR: Unable to source script: ${name}.sh"; exit 1; fi
done

root="$PWD"

# Files to clean up after operation is completed
removables=()

# Paths to include in mod package if defined:
# - tp2_mod_path: path of mod folder
# - tp2_file:     path of separate tp2 file (old-style mods only)
# - ini_file:     path of separate ini file (old-style mods only; defined only if "tp2_file" is set)
# - setup_file:   path of setup binary
# - command_file: path of setup .command script (macOS only)

# Filenames for zip inclusion and exclusion lists
zip_include="zip_include.lst"
zip_exclude="zip_exclude.lst"

# Filename and full path of the mod package to create
archive_filename=""
archive_file_path=""

# Returns colon-delimited path strings:
# - relative base path for mod structure
# - tp2 file path
# - optional mod folder path (for old-style mods only).
# May contain more than one set of strings (e.g. if multiple tp2 files are found)
tp2_result=$(find_tp2)
if [ -z "$tp2_result" ]; then
  printerr "ERROR: No tp2 file found."
  exit 1
fi

# Loop through every potential mod
while [ -n "$tp2_result" ]; do
  # splitting tp2_result into variables: mod_root, tp2_file, tp2_mod_path
  split_to_vars "$tp2_result" "tp2_result" ":" "mod_root" "tp2_file" "tp2_mod_path"
  echo "mod root: $mod_root"
  echo "tp2 file: $tp2_file"
  if [ -n "$tp2_mod_path" ]; then
    echo "tp2 mod folder: $tp2_mod_path"
  fi

  # Setting root folder for the mod file structure
  cd "$mod_root"

  # Setup binary filename
  setup_file=""
  # macOS setup .command filename
  command_file=""

  # Setting up setup binary file(s)
  if [ "$archive_type" != "iemod" ]; then
    if [ ! -e "$weidu_bin" ]; then
      # Downloading WeiDU binary
      echo "Downloading WeiDU executable: $weidu_bin ($archive_type)"
      download_weidu "$archive_type" "$arch" "$weidu_tag_name"
      if [ $? -ne 0 ]; then
        exit 1
      fi
      if [ ! -e "$weidu_bin" ]; then
        printerr "ERROR: Could not find WeiDU binary on the system."
        exit 1
      fi
      removables+=("$weidu_bin")
      echo "WeiDU binary: $weidu_bin"
    fi

    # Setting up setup binaries
    create_setup_binaries "$weidu_bin" "$tp2_file" "$archive_type"
    if [ $? -ne 0 ]; then
      printerr "ERROR: Could not create setup binaries."
      clean_up "$weidu_bin"
      exit 1
    fi

    setup_file=$(get_setup_binary_name "$tp2_file" "$archive_type")
    echo "${setup_file}" >>"$zip_include"
    removables+=("$setup_file")
    echo "Setup name: $setup_file"

    command_file=$(get_setup_command_name "$tp2_file" "$archive_type")
    if [ -n "$command_file" ]; then
      echo "${command_file}" >>"$zip_include"
      removables+=("$command_file")
      echo "Command script name: $command_file"
    fi
  fi

  # Getting version suffix
  version_suffix="$suffix"
  if [ "$suffix" = "version" ]; then
    version_suffix=$(get_tp2_version "$tp2_file")
  fi
  version_suffix=$(normalize_version "$version_suffix")
  echo "Version suffix: $version_suffix"
  if [ -n "$version_suffix" -a "${version_suffix:0:1}" != "-" ]; then
    version_suffix="-$version_suffix"
  fi

  # getting mod folder and (optional) tp2 file paths
  if [ -z "$tp2_mod_path" ]; then
    tp2_mod_path=$(path_get_parent_path "$tp2_file")
    tp2_file=""
  fi

  echo "${tp2_mod_path}/**" >>"$zip_include"
  if [ -n "$tp2_file" ]; then
    echo "${tp2_file}" >>"$zip_include"
  fi

  # PI meta file may exist in the root folder for old-style mods
  ini_file=""
  if [ -n "$tp2_file" ]; then
    file_base=$(path_get_tp2_name "$tp2_file")
    file_root=$(path_get_parent_path "$tp2_file")
    if [ -z "$file_root" ]; then
      file_root="."
    fi
    ini_file=$(find_file "$file_root" "*${file_base}.ini")
  fi

  if [ -n "$ini_file" ]; then
    echo "${ini_file}" >>"$zip_include"
  fi

  # Assembling mod archive filename and path
  if [ -z "$archive_filename" ]; then
    archive_filename=$(create_package_name "$tp2_mod_path" "$version_suffix" "$ini_file")
    archive_file_path="${root}/${archive_filename}"
  fi
done

# Creating mod package
echo "Mod archive: $archive_filename"

# Exclude certain file and folder patterns from the zip archive
cat << "EOF" > "$zip_exclude"
**/.*
**/*.bak
**/*.iemod
**/*.tmp
**/*.temp
**/Thumbs.db
**/ehthumbs.db
**/backup/*
**/__macosx/*
**/$RECYCLE.BIN/*
EOF
removables+=("$zip_include" "$zip_exclude")

# Creating zip archive
zip -r "$archive_file_path" . -i "@$zip_include" -x "@$zip_exclude"

# Cleaning up files
clean_up "${removables[@]}"

# Back to the roots
cd "$root"

# Passing mod package name to the GitHub Action parameter "weidu_mod_package"
echo "Passing mod package name to GitHub Action output..."
echo "weidu_mod_package=$archive_filename" >> $GITHUB_OUTPUT

exit 0
