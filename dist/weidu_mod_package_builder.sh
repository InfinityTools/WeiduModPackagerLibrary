#!/bin/bash

# Copyright (c) 2024 Argent77
# Version 1.2

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


# Including shellscript libraries
DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
source "$DIR/lib_base.sh" || exit 1
source "$DIR/lib_params.sh" || exit 1
source "$DIR/lib_paths.sh" || exit 1
source "$DIR/lib_weidu.sh" || exit 1


#####################################
#     Start of script execution     #
#####################################

root="$PWD"

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

archive_filename=""
archive_file_path=""

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
    command_file=$(get_setup_command_name "$tp2_file" "$archive_type")
    echo "Setup name: $setup_file"
    if [ -n "$command_file" ]; then
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
  if [ -n "$version_suffix" ]; then
    version_suffix="-$version_suffix"
  fi

  # getting mod folder and (optional) tp2 file paths
  if [ -z "$tp2_mod_path" ]; then
    tp2_mod_path=$(path_get_parent_path "$tp2_file")
    tp2_file=""
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

  # Assembling mod archive filename
  if [ "$archive_type" = "iemod" ]; then
    archive_ext=".iemod"
  else
    archive_ext=".zip"
  fi

  # Platform-specific prefix needed to prevent overwriting package files
  case $archive_type in
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
  echo "Package file base: $archive_filebase"


  if [ -z "$archive_filename" ]; then
    update_zip=0
    archive_filename="${os_prefix}${archive_filebase}${extra}${version_suffix}${archive_ext}"
    archive_file_path="${root}/${archive_filename}"
  else
    update_zip=1
  fi

  # Paths to add if defined:
  # - tp2_mod_path: path of mod folder
  # - tp2_file:     path of separate tp2 file (old-style mods only)
  # - ini_file:     path of separate ini file (old-style mods only; defined only if "tp2_file" is set)
  # - setup_file:   path of setup binary
  # - command_file: path of setup .command script (macOS only)

  # Creating mod package
  echo "Mod archive: $archive_filename"

  # Exclude certain file and folder patterns from the zip archive
  echo "Generating 'zip_exclude.lst'"
  for arg in "**/.*" \
             "**/*.bak" \
             "**/*.iemod" \
             "**/*.tmp" \
             "**/*.temp" \
             "**/Thumbs.db" \
             "**/ehthumbs.db" \
             "**/backup/*" \
             "**/__macosx/*" \
             "**/\$RECYCLE.BIN/*"; do
    echo "$arg" >>zip_exclude.lst
  done

  if [ $update_zip -eq 0 ]; then
    zip_cmd="zip -r"
  else
    zip_cmd="zip -ur"
  fi
  $zip_cmd "$archive_file_path" "$tp2_mod_path" --exclude @zip_exclude.lst || (
    printerr "ERROR: Could not create zip archive \"$archive_filename\" from \"$tp2_mod_path\"";
    clean_up "zip_exclude.lst" "$command_file" "$setup_file" "$weidu_bin"
    exit 1
  )
  clean_up "zip_exclude.lst"

  if [ -n "$tp2_file" ]; then
    zip -u "$archive_file_path" "$tp2_file" || (
      printerr "ERROR: Could not add \"$tp2_file\" to zip archive \"$archive_filename\""
      clean_up "$command_file" "$setup_file" "$weidu_bin"
      exit 1
    )
  fi

  if [ -n "$ini_file" ]; then
    zip -u "$archive_file_path" "$ini_file" || (
      printerr "ERROR: Could not add \"$ini_file\" to zip archive \"$archive_filename\""
      clean_up "$command_file" "$setup_file" "$weidu_bin"
      exit 1
    )
  fi

  if [ -n "$setup_file" ]; then
    zip -u "$archive_file_path" "$setup_file" || (
      printerr "ERROR: Could not add \"$setup_file\" to zip archive \"$archive_filename\""
      clean_up "$command_file" "$setup_file" "$weidu_bin"
      exit 1
    )
  fi

  if [ -n "$command_file" ]; then
    zip -u "$archive_file_path" "$command_file" || (
      printerr "ERROR: Could not add \"$command_file\" to zip archive \"$archive_filename\""
      clean_up "$command_file" "$setup_file" "$weidu_bin"
      exit 1
    )
  fi

  # Cleaning up files
  clean_up "$command_file" "$setup_file"
done

# Cleaning up remaining files
clean_up "$weidu_bin"

# Back to the roots
cd "$root"

# Passing mod package name to the GitHub Action parameter "weidu_mod_package"
echo "Passing mod package name to GitHub Action output..."
echo "weidu_mod_package=$archive_filename" >> $GITHUB_OUTPUT

exit 0
