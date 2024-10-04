#!/bin/bash

# Copyright (c) 2024 Argent77

########################################################
# This script is not intended to be executed directly. #
########################################################

# Downloads the WeiDU binary matching the specified arguments and prints the name of the WeiDU binary to stdout.
# Expected parameters: platform, architecture, git tag name
# Returns with an error code on failure.
download_weidu() {
  weidu_tag_name="latest"
  weidu_os=""
  if [ $# -gt 1 ]; then
    weidu_arch="$2"
  else
    weidu_arch="amd64"
  fi
  bin_ext=""
  if [ $# -gt 0 ]; then
    case $1 in
      windows)
        weidu_os="Windows"
        bin_ext=".exe"
        ;;
      linux)
        weidu_os="Linux"
        ;;
      macos)
        weidu_os="Mac"
        ;;
    esac
  fi

  if [ $# -gt 2 ]; then
    weidu_tag_name="$3"
  fi

  # Fetching compatible WeiDU package URL
  echo "Fetching release info: ${weidu_url_base}/${weidu_tag_name}"
  weidu_json=$(curl -s "${weidu_url_base}/${weidu_tag_name}")
  if [ $? -ne 0 ]; then
    printerr "ERROR: Could not retrieve WeiDU release information"
    return 1
  fi
  weidu_tag_name=$(echo "$weidu_json" | jq -r '.tag_name')
  
  weidu_url=""
  for url in $(echo "$weidu_json" | jq -r '.assets[].browser_download_url'); do
    result=$(validate_weidu_url "$url" "$weidu_arch" "$weidu_os" "$weidu_tag_name")
    if [ -n "$result" ]; then
      weidu_url="$result"
      break
    fi
  done

  if [ -z "$weidu_url" ]; then
    printerr "ERROR: No compatible WeiDU package found."
    return 1
  fi
  echo "WeiDU download URL: $weidu_url"

  # Downloading WeiDU archive
  weidu_file=$(decode_url_string "${weidu_url##*/}")
  weidu_path="./$weidu_file"
  curl -L --retry-delay 3 --retry 3 "$weidu_url" >"$weidu_path"
  if [ $? -ne 0 ]; then
    printerr "ERROR: Could not download WeiDU binary."
    return 1
  fi

  # Extracting WeiDU binary
  weidu_bin="weidu$bin_ext"
  if ! unpack_weidu "$weidu_path" "$weidu_bin" "$weidu_arch" "$weidu_tag_name" ; then
    printerr "ERROR: Could not extract WeiDU binary."
    rm -fv "$weidu_path"
    return 1
  fi

  rm -fv "$weidu_path"

  return 0
}


# Unpacks a specific file from the given WeiDU zip archive.
# Expected parameters: weidu_path, weidu_bin, arch, tag_name
unpack_weidu() {
  if [ $# -gt 3 ]; then
    weidu_path="$1"
    weidu_bin="$2"
    arch="$3"
    version=$(echo "$4" | sed -re 's/^v([0-9]+).*/\1/')

    if [ $version -lt 247 ]; then
      # WeiDU 246: zip archive includes binaries for "amd64" and "x86"
      if [ "$arch" != "amd64" ]; then
        arch="x86"
      fi
      unzip -jo "$weidu_path" "**/$arch/$weidu_bin"
    else
      unzip -jo "$weidu_path" "**/$weidu_bin"
    fi

    if [ $? -ne 0 ]; then
      return 1
    fi
    return 0
  fi
  return 1
}


# Validates the given URL with the specified parameters and returns it to stdout if successful.
# Expected parameters: url, arch, os, tag_name
validate_weidu_url() {
  if [ $# -gt 3 ]; then
    url="$1"
    arch="$2"
    os="$3"
    version=$(echo "$4" | sed -re 's/^v([0-9]+).*/\1/')

    if [ "$os" != "Windows" -a $version -gt 246 ]; then
      arch=""
    fi

    if [ $version -le 246 ]; then
      if echo "$url" | grep -F -qe "-$os" ; then
        echo "$url"
      fi
    elif [ $version -eq 247 ]; then
      if echo "$url" | grep -F -qe "-$os" ; then
        if [ "$os" = "Windows" ]; then
          # updating architecture name
          if [ "$arch" = "x86" ]; then
            # Note: URL string requires %-encoded special characters
            arch="x86%2Bwin10"
          elif [ "$arch" = "x86-legacy" ]; then
            arch="x86."
          fi
        fi

        if echo "$url" | grep -F -qe "-$arch"; then
          echo "$url"
        fi
      fi
    else
      if echo "$url" | grep -F -qe "-$os" ; then
        if echo "$url" | grep -F -qe "-$arch"; then
          echo "$url"
        fi
      fi
    fi
  fi
}


# Prints the setup filename to stdout.
# Expected parameters: tp2_file_path, platform
# Returns empty string on error.
get_setup_binary_name() {
  if [ $# -gt 1 ]; then
    ext=""
    if [ "$2" = "windows" ]; then
      ext=".exe"
    fi
    name=$(path_get_tp2_name "$1")
    name="setup-$name$ext"
    echo "$name"
  fi
}

# Prints the setup .command script filename (macOS only).
# Expected parameters: tp2_file_path, platform
# Returns empty string on error or non-macOS architectures.
get_setup_command_name() {
  if [ $# -gt 1 ]; then
    if [ "$2" = "macos" ]; then
      name=$(path_get_tp2_name "$1")
      name="setup-${name}.command"
      echo "$name"
    fi
  fi
}


# Creates a setup binary from a weidu binary.
# Expected parameters: weidu_binary, tp2_file_path, platform
# Returns with an error code on failure.
create_setup_binaries() {
  if [ $# -gt 2 ]; then
    setup_file=$(get_setup_binary_name "$2" "$3")
    if [ -z "$setup_file" ]; then
      printerr "ERROR: Could not determine setup binary filename."
      return 1
    fi
    command_file=$(get_setup_command_name "$2" "$3")

    cp -v "$1" "$setup_file"
    chmod -v 755 "$setup_file"

    # macOS-specific
    if [ -n "$command_file" ]; then
      echo "Creating script: $command_file"
      echo 'command_path=${0%/*}' >"$command_file"
      echo 'cd "$command_path"' >>"$command_file"
      echo "./${setup_file}" >>"$command_file"
      chmod -v 755 "$command_file"
    fi

    return 0
  else
    return 1
  fi
}


# Reads the VERSION string from the specified tp2 file if available and prints the result to stdout.
# Expected parameters: tp2_file_path, [beautify: boolean as 0 or 1]
# If "Beautify" is enabled then the returned string is prepended by letter 'v' if a version number
# is detected (e.g. "12.1" -> "v12.1").
get_tp2_version() {
  if [ $# -gt 0 ]; then
    # Try string in tilde delimiters first
    v=$(cat "$1" | grep '^\s*VERSION' | sed -re 's/^\s*VERSION\s+~([^~]*)~.*/\1/')
    if [ -z "$v" ]; then
      # Try string in double quotes
      v=$(cat "$1" | grep '^\s*VERSION' | sed -re 's/^\s*VERSION\s+"([^"]*)".*/\1/')
      if [ -z "$v" ]; then
        # Try string in percent signs
        v=$(cat "$1" | grep '^\s*VERSION' | sed -re 's/^\s*VERSION\s+%([^%]*)%.*/\1/')
        if [ -z "$v" ]; then
          # Finally, try string without delimiters
          v=$(cat "$1" | grep '^\s*VERSION' | sed -re 's/^\s*VERSION\s+([^ \t]*).*/\1/')
          if echo "$v" | grep -qe '^@-\?[0-9]\+'; then
            # Discard tra references
            v=""
          fi
        fi
      fi
    fi

    # Checking for malformed VERSION definition
    if echo "$v" | grep -qe '^\s*VERSION' ; then
      v=""
    fi

    # Removing everything after the first whitespace character
    v=$(echo "$v" | xargs | sed -re 's/\s.*//')
    # Removing illegal characters for filenames
    v=$(normalize_filename "$v")

    if [ $# -gt 1 -a "$2" = "1" ]; then
      # Beautifying version string
      if echo "$v" | grep -qe '^[0-9]\+' ; then
        v="v$v"
      fi
    fi

    echo "$v"
  fi
}
