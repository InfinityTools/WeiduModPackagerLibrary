#!/bin/bash

# Copyright (c) 2024 Argent77

########################################################
# This script is not intended to be executed directly. #
########################################################

# Downloads the WeiDU zip archive that matches the given parameters and unpacks the
# WeiDU binary to the specified target directory.
# Expected parameters: platform, architecture ($arch), weidu_version (latest), target_dir (.)
# Updates $weidu_info[*] entries with information about the WeiDU binary.
download_weidu() {
  if [ -z "$1" ]; then
    printerr "ERROR: No platform specified."
    return 1
  fi

  _weidu_os="${1}"
  _weidu_arch="${2:-$arch}"
  _weidu_version="${3:-latest}"
  _dest_dir="${4:-.}"
  _weidu_bin=$(get_weidu_binary_name "$_weidu_os")

  # Requesting WeiDU binary information
  if ! get_weidu_info "$_weidu_os" "$_weidu_arch" "$_weidu_version"; then
    return 1
  fi
  echo "WeiDU download URL: ${weidu_info[$key_url]}"

  # Downloading WeiDU archive
  if ! retrieve_weidu_bin "${weidu_info[$key_url]}" "$_weidu_bin" "${weidu_info[$key_arch]}" "$_dest_dir"; then
    return 1
  fi
}


# Retrieves information about available WeiDU binaries and assigns them to the "weidu" array.
# Use the "key_xxx" variables to retrieve individual information (see lib_params.sh).
# Expected parameters: weidu_os ($archive_type), weidu_arch ($arch), weidu_version ($weidu_version)
# weidu_os must be one of "windows", "linux" or "macos".
# Returns 0 if successful, non-zero otherwise
get_weidu_info() {
  _type="${1:-$archive_type}"
  case "$_type" in
    win*)
      _weidu_os="Windows"
      ;;
    lin*)
      _weidu_os="Linux"
      ;;
    mac*)
      _weidu_os="Mac"
      ;;
    *)
      printerr "ERROR: Unsupported WeiDU platform specified: $_type"
      return 1
      ;;
  esac
  _weidu_arch="${2:-$arch}"
  _weidu_version="${3:-$weidu_version}"

  # download json file if needed
  _weidu_json_file="weidu_${_weidu_version}.json"
  if [ ! -f "$_weidu_json_file" ]; then
    _pat_tag_full="^[[:digit:]]{3}\.[[:digit:]]{2}$"
    _pat_tag_short="^[[:digit:]]{3}$"
    if [ "$_weidu_version" = "latest" ]; then
      _weidu_json_url="${weidu_url_base}/${_weidu_version}"
    elif [[ "$_weidu_version" =~ $_pat_tag_full ]]; then
      _weidu_json_url="${weidu_url_base}/tags/v${_weidu_version}"
    elif [[ "$_weidu_version" =~ $_pat_tag_short ]]; then
      _weidu_json_url="${weidu_url_base}/tags/v${_weidu_version}.00"
    else
      printerr "ERROR: Not a valid WeiDU version: ${_weidu_version}"
      return 1
    fi

    echo "Fetching release info: $_weidu_json_url"
    curl -s "$_weidu_json_url" >"$_weidu_json_file"
    if [ $? -ne 0 ]; then
      printerr "ERROR: Could not retrieve WeiDU release information"
      return 1
    fi
    removables+=("$_weidu_json_file")
  fi

  # Reading json file content into a variable
  _weidu_json=$(<"$_weidu_json_file")

  _tag_name=$(echo "$_weidu_json" | jq -r '.tag_name')
  if [ $? -ne 0 ]; then
    printerr "ERROR: Could not retrieve WeiDU release tag name"
    return 1
  fi

  _pat_tag_name="^v([[:digit:]]{3})\.([[:digit:]]{2})$"
  if [[ "$_tag_name" =~ $_pat_tag_name ]]; then
    _version="${BASH_REMATCH[1]}"
    _stable=$([ "${BASH_REMATCH[2]}" -eq 0 ] && echo "1" || echo "0")
  else
    echo "Unsupported WeiDU tag name: $_tag_name"
    return 1
  fi

  # Adjusting parameters to current WeiDU version
  case $_version in
    246)
      # x86 and amd64 present inside the same zip archive
      if [ "$_weidu_arch" = "x86-legacy" ]; then
        _weidu_arch="x86"
      fi
      _req_arch=""
      ;;
    247)
      # non-Windows platforms dropped x86 architecture
      # Windows non-legacy x86 uses specific architecture name
      if [ "$_weidu_os" = "Windows" ]; then
        case "$_weidu_arch" in
          x86-legacy)
            _req_arch="x86"
            ;;
          x86)
            _req_arch="x86+win10+4.07.1"
            ;;
          *)
            _req_arch="$_weidu_arch"
            ;;
        esac
      else
        _weidu_arch="amd64"
        _req_arch="$_weidu_arch"
      fi
      ;;
    *)
      # non-Windows platforms dropped x86 architecture
      if [ "$_weidu_os" != "Windows" ]; then
        _weidu_arch="amd64"
      fi
      _req_arch="$_weidu_arch"
      ;;
  esac

  # Resetting WeiDU information from an earlier call
  weidu_info[$key_tag_name]=""
  weidu_info[$key_version]=0
  weidu_info[$key_stable]=0
  weidu_info[$key_arch]=""
  weidu_info[$key_url]=""
  weidu_info[$key_filename]=""
  weidu_info[$key_size]=0

  # Pattern groups: 1=os, 2=version, 3=[arch]
  _pat_weidu_name="^WeiDU-([^-.]+)-([^-.]+)-?(.*)\.zip$"
  _asset_count=$(echo "$_weidu_json" | jq -r '.assets | length')
  if [ $? -ne 0 ]; then
    printerr "ERROR: Could not parse WeiDU release information"
    return 1
  fi
  for ((_index=0; _index < _asset_count; _index++)); do
    _url=$(echo "$_weidu_json" | jq -r ".assets[$_index].browser_download_url")
    if [ $? -ne 0 ]; then
      printerr "ERROR: Could not parse WeiDU release information"
      return 1
    fi
    _name=$(decode_url_string "${_url##*/}")
    if [[ "$_name" =~ $_pat_weidu_name ]]; then
      _os="${BASH_REMATCH[1]}"
      _ver="${BASH_REMATCH[2]}"
      _arch="${BASH_REMATCH[3]}"
    fi

    if [ "$_os" = "$_weidu_os" ]; then
      if [ "$_arch" = "$_req_arch" -o -z "${weidu_info[$key_arch]}" ]; then
        _size=$(echo "$weidu_json" | jq -r ".assets[$index].size")
        if [ $? -ne 0 ]; then
          printerr "ERROR: Could not parse WeiDU release information"
          return 1
        fi
        weidu_info[$key_arch]="$_weidu_arch"
        weidu_info[$key_url]="$_url"
        weidu_info[$key_filename]="$_name"
        weidu_info[$key_size]=$_size
      fi
    fi
  done

  if [ -n "${weidu_info[$key_arch]}" ]; then
    weidu_info[$key_tag_name]="$_tag_name"
    weidu_info[$key_version]=$_version
    weidu_info[$key_stable]=$_stable
  fi

  return 0
}


# Downloads and extracts the WeiDU binary to the system, based on the given parameters.
# Expected parameters: weidu_url, weidu_bin (autodetect), weidu_arch ($arch), target_dir (.)
# Updates $weidu_info[$key_bin] with the extracted WeiDU binary path if successful.
retrieve_weidu_bin() {
  if [ -z "$1" ]; then
    printerr "ERROR: No URL specified."
    return 1
  fi
  if [ -z "$2" ]; then
    printerr "ERROR: WeiDU binary name not specified."
    return 1
  fi

  _url="$1"
  _filename=$(decode_url_string "${_url##*/}")
  _weidu_arch="${3:-$arch}"
  _weidu_bin="${2:-$(get_weidu_binary_name $_weidu_arch)}"
  _dest_dir="${4:-.}"
  _weidu_path="${_dest_dir}/${_filename}"

  # Downloading WeiDU zip archive
  if ! curl -L --retry-delay 3 --retry 3 "$_url" >"$_weidu_path"; then
    printerr "ERROR: Could not download WeiDU binary from: $_url."
    return 1
  fi

  # Unpacking WeiDU binary
  if ! unpack_weidu_bin "$_weidu_path" "$_weidu_bin" "$_weidu_arch" "$_dest_dir"; then
    clean_up "$_weidu_path"
    return 1
  fi

  clean_up "$_weidu_path"
  return 0
}


# Unpacks the WeiDU binary from the specified WeiDU zip archive and updates $weidu_info[$key_bin]
# with the extracted WeiDU binary path if successful.
# Expected parameters: weidu_archive_path, weidu_bin (autodetect), weidu_arch ($arch), target_dir (.)
unpack_weidu_bin() {
  if [ -z "$1" ]; then
    printerr "ERROR: WeiDU archive path not specified."
    return 1
  fi
  if [ -z "$2" ]; then
    printerr "ERROR: WeiDU binary name not specified."
    return 1
  fi

  _weidu_path="$1"
  _weidu_arch="${3:-$arch}"
  _weidu_bin="${2:-$(get_weidu_binary_name $_weidu_arch)}"
  _dest_dir="${4:-.}"

  # Determining WeiDU binary path in zip archive
  _zip_file=$(zipinfo -2 "$_weidu_path" "**/$_weidu_arch/$_weidu_bin" 2>/dev/null | head -1)
  if [ -z "$_zip_file" ]; then
    _zip_file=$(zipinfo -2 "$_weidu_path" "**/$_weidu_bin" 2>/dev/null | head -1)
    if [ -z "$_zip_file" ]; then
      printerr "ERROR: WeiDU binary not found in zip archive: $_weidu_path"
      return 1
    fi
  fi

  # Unpacking WeiDU binary
  if ! unzip -jo "$_weidu_path" "$_zip_file" -d "$_dest_dir"; then
    printerr "ERROR: WeiDU binary not in zip archive: $_weidu_path"
    return 1
  fi

  weidu_info[$key_bin]="$_dest_dir/$_weidu_bin"
  return 0
}


# Prints the name of the WeiDU executable for the specified platform to stdout,
# optionally with a given path.
# Expected parameters: weidu_arch ($arch), weidu_path (<empty>)
get_weidu_binary_name() {
  _weidu_arch="${1:-$arch}"
  _weidu_bin=$([ "$_weidu_arch" = "windows" ] && echo "weidu.exe" || echo "weidu")
  _weidu_dir=$([ -n "$2" ] && echo "${2}/" || echo "")
  echo "${_weidu_dir}${_weidu_bin}"
}


# Prints the setup filename to stdout.
# Expected parameters: tp2_file_path, platform ($archive_type)
# Returns empty string on error.
get_setup_binary_name() {
(
  if [ $# -gt 1 ]; then
    ext=$([ "${2:-$archive_type}" = "windows" ] && echo ".exe" || echo "")
    prefix=$(path_get_tp2_prefix "$1")
    name=$(path_get_tp2_name "$1")
    name="$prefix$name$ext"
    echo "$name"
  fi
)
}

# Prints the setup .command script filename (macOS only).
# Expected parameters: tp2_file_path, platform ($archive_type)
# Returns empty string on error or non-macOS architectures.
get_setup_command_name() {
(
  if [ $# -gt 1 ]; then
    if [ "${2:-$archive_type}" = "macos" ]; then
      prefix=$(path_get_tp2_prefix "$1")
      name=$(path_get_tp2_name "$1")
      name="$prefix${name}.command"
      echo "$name"
    fi
  fi
)
}


# Creates a setup binary from a weidu binary.
# Expected parameters: weidu_binary, tp2_file_path, platform ($archive_type)
# Returns with an error code on failure.
create_setup_binaries() {
(
  if [ $# -gt 1 ]; then
    platform="${3:-$archive_type}"
    setup_file=$(get_setup_binary_name "$2" "$platform")
    if [ -z "$setup_file" ]; then
      printerr "ERROR: Could not determine setup binary filename."
      return 1
    fi
    command_file=$(get_setup_command_name "$2" "$platform")

    cp -v "$1" "$setup_file"
    chmod -v 755 "$setup_file"

    # macOS-specific
    if [ -n "$command_file" ]; then
      echo "Creating script: $command_file"
      echo 'cd "${0%/*}"' > "$command_file"
      echo 'ScriptName="${0##*/}"' >> "$command_file"
      echo '"./${ScriptName%.*}"' >> "$command_file"
      chmod -v 755 "$command_file"
    fi

    return 0
  else
    return 1
  fi
)
}


# Reads the VERSION string from the specified tp2 file if available and prints the result to stdout.
# Expected parameters: tp2_file_path
get_tp2_version() {
(
  if [ $# -gt 0 ]; then
    v=""
    match=0
    line=$(cat "$1" | grep '^\s*VERSION' | head -1)
    if [ -n "$line" ]; then
      # String can be delimited by tilde (~), quotation marks (") or percent signs (%)
      for delim in '~' '"' '%'; do
        pat="^[[:blank:]]*VERSION[[:blank:]]*${delim}([^${delim}]*)${delim}?.*$"
        if [[ "$line" =~ $pat ]]; then
          v="${BASH_REMATCH[1]}"
          match=1
          break
        fi
      done

      if [ $match -eq 0 ]; then
        # Special: String may not be delimited at all; ignore potential tra references
        pat="^[[:blank:]]*VERSION[[:blank:]]+([^@][^[:blank:]]*).*$"
        if [[ "$line" =~ $pat ]]; then
          v="${BASH_REMATCH[1]}"
        fi

      fi
    fi

    echo "$v"
  fi
)
}
