#!/bin/bash

# Copyright (c) 2024 Argent77
# Version 1.0

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

# Parameter check
eval_arguments $@ || exit 1

# Supported types: iemod, windows, linux, macos
archive_type=$(eval_type $@)
echo "Archive type: $archive_type"

# Supported architectures: amd64, x86, x86-legacy
arch=$(eval_arch $@)
if [ "$archive_type" = "iemod" ]; then
  echo "Architecture: platform-neutral"
else
  echo "Architecture: $arch"
fi

# Supported suffixes: none, version, <literal string>
suffix=$(eval_suffix $@)
if [ "$suffix" = "version" ]; then
  echo "Suffix: <tp2 VERSION string>"
elif [ -z "$suffix" ]; then
  echo "Suffix: <none>"
else
  echo "Suffix: $suffix"
fi

# Returns colon-delimited path strings:
# - relative base path for mod structure
# - tp2 file path
# - optional mod folder path (for old-style mods only).
tp2_result=$(find_tp2)
if [ -z "$tp2_result" ]; then
  printerr "ERROR: No tp2 file found."
  exit 1
fi

# initializing mod paths
mod_root=""
tp2_file=""
tp2_mod_path=""

old_ifs=$IFS
IFS=:
counter=0
for item in $tp2_result; do
  case $counter in
    0)  # mod base path
      mod_root="$item"
      ;;
    1)  # tp2 file path
      tp2_file="$item"
      ;;
    2)  # optional mod folder path
      tp2_mod_path="$item"
      ;;
  esac
  counter=$((counter+1))
done
IFS=$old_ifs

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
  bin_ext=$(get_bin_ext "$arch")

  # Downloading WeiDU binary
  download_weidu "$archive_type" "$arch"
  if [ $? -ne 0 ]; then
    exit 1
  fi
  weidu_bin="weidu$bin_ext"
  if [ ! -f "$weidu_bin" ]; then
    printerr "ERROR: Could not find WeiDU binary on the system."
    exit 1
  fi
  echo "WeiDU binary: $weidu_bin"

  # Setting up setup binaries
  create_setup_binaries "$weidu_bin" "$tp2_file" "$archive_type"
  if [ $? -ne 0 ]; then
    printerr "ERROR: Could not create setup binaries."
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
  version_suffix=$(get_tp2_version "$tp2_file" "1")
fi
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
    os_prefix="win-"
    ;;
  linux)
    os_prefix="lin-"
    ;;
  macos)
    os_prefix="mac-"
    ;;
  *)
    os_prefix=""
esac

archive_filename=$(path_get_filename "$tp2_mod_path")
archive_filename="${os_prefix}${archive_filename}${version_suffix}${archive_ext}"
archive_file_path="${root}/${archive_filename}"

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
for arg in "**/.*" "**/*.bak" "**/*.iemod" "**/*.tmp" "**/*.temp" "**/Thumbs.db" "**/ehthumbs.db" "**/backup/*" "**/__macosx/*" "**/\$RECYCLE.BIN/*"; do
  echo "$arg" >>zip_exclude.lst
done

zip -r "$archive_file_path" "$tp2_mod_path" --exclude @zip_exclude.lst || ( printerr "ERROR: Could not create zip archive \"$archive_filename\" from \"$tp2_mod_path\""; exit 1)
rm -fv zip_exclude.lst

if [ -n "$tp2_file" ]; then
  zip -u "$archive_file_path" "$tp2_file" || ( printerr "ERROR: Could not add \"$tp2_file\" to zip archive \"$archive_filename\""; exit 1)
fi

if [ -n "$ini_file" ]; then
  zip -u "$archive_file_path" "$ini_file" || ( printerr "ERROR: Could not add \"$ini_file\" to zip archive \"$archive_filename\""; exit 1)
fi

if [ -n "$setup_file" ]; then
  zip -u "$archive_file_path" "$setup_file" || ( printerr "ERROR: Could not add \"$setup_file\" to zip archive \"$archive_filename\""; exit 1)
fi

if [ -n "$command_file" ]; then
  zip -u "$archive_file_path" "$command_file" || ( printerr "ERROR: Could not add \"$command_file\" to zip archive \"$archive_filename\""; exit 1)
fi

# Cleaning up
test -n "$command_file" && rm -fv "$command_file"
test -n "$setup_file" && rm -fv "$setup_file"
test -n "$weidu_bin" && rm -fv "$weidu_bin"

# Back to the roots
cd "$root"

# Storing mod archive filename in file "PACKAGE_NAME"
echo "Storing mod archive name in ./PACKAGE_NAME"
echo "$archive_filename" >"PACKAGE_NAME"

# Passing mod package name to the GitHub Action parameter "weidu_mod_package"
echo "Passing mod package name to GitHub Action output..."
echo "weidu_mod_package=$archive_filename" >> $GITHUB_OUTPUT

exit 0