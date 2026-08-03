#!/usr/bin/env bash
# Shared, dependency-free helpers for zstack scripts.

readonly ZSTACK_LINK_MANIFEST_MAX_BYTES=1048576
readonly ZSTACK_ROOT_RECORD_MAX_BYTES=4096
readonly ZSTACK_PID_LOCK_OWNER_MAX_BYTES=32
# Consumed by doctor and direct contract tests after this library is sourced.
# shellcheck disable=SC2034
readonly ZSTACK_REPOSITORY_CANDIDATE_MAX_FILE_BYTES=2097152
# shellcheck disable=SC2034
readonly ZSTACK_REPOSITORY_CANDIDATE_MAX_FILES=100000
# shellcheck disable=SC2034
readonly ZSTACK_REPOSITORY_CANDIDATE_MAX_BYTES=536870912
# shellcheck disable=SC2034
readonly ZSTACK_REPOSITORY_CANDIDATE_MAX_INVENTORY_BYTES=16777216
# Kept aligned with EvalLimits so doctor can fail closed before reading skill
# content even when Ruby is unavailable.
# shellcheck disable=SC2034
readonly ZSTACK_SKILL_TREE_MAX_FILE_BYTES=2097152
# shellcheck disable=SC2034
readonly ZSTACK_SKILL_TREE_MAX_FILES=10000
# shellcheck disable=SC2034
readonly ZSTACK_SKILL_TREE_MAX_BYTES=536870912
# shellcheck disable=SC2034
readonly ZSTACK_SKILL_TREE_MAX_ENTRIES=100000
readonly ZSTACK_SECRET_ASSIGNMENT_NAMES='XAI_API_KEY|CLOUDFLARE_(API_TOKEN|API_KEY|ACCESS_CLIENT_SECRET)|WRANGLER_R2_SQL_AUTH_TOKEN|CF_API_(TOKEN|KEY)'
readonly ZSTACK_SECRET_ASSIGNMENT_PATTERN="(${ZSTACK_SECRET_ASSIGNMENT_NAMES})[[:space:]]*=[[:space:]]*['\"]?[a-zA-Z0-9._-]{20,}"
# Consumed by doctor and direct contract tests after this library is sourced.
# shellcheck disable=SC2034
readonly ZSTACK_SECRET_PATTERN="(^|[^a-zA-Z0-9_])(sk-[a-zA-Z0-9_-]{20,}|hf_[a-zA-Z0-9]{20,}|(sk|rk)_(live|test)_[a-zA-Z0-9]{16,}|whsec_[a-zA-Z0-9]{16,}|${ZSTACK_SECRET_ASSIGNMENT_PATTERN}|gh[pousr]_[a-zA-Z0-9]{20,}|github_pat_[a-zA-Z0-9_]{20,}|npm_[a-zA-Z0-9]{20,}|AIza[0-9a-zA-Z_-]{35}|xox[baprs]-[0-9a-zA-Z-]{20,}|AKIA[A-Z0-9]{16}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----)"

zstack_require_safe_home() {
  local home_value="${HOME:-}"
  local resolved_home parent leaf

  case "$home_value" in
    ""|/)
      echo "Unsafe HOME value; refusing to manage global skill links." >&2
      return 2
      ;;
    /*) ;;
    *)
      echo "HOME must be an absolute path; refusing to manage global skill links." >&2
      return 2
      ;;
  esac

  if [[ -d "$home_value" ]]; then
    resolved_home="$(cd "$home_value" 2>/dev/null && pwd -P)" || {
      echo "HOME cannot be resolved safely; refusing to manage global skill links." >&2
      return 2
    }
  else
    parent="$(dirname "$home_value")"
    leaf="$(basename "$home_value")"
    if [[ "$leaf" == "." || "$leaf" == ".." || ! -d "$parent" ]]; then
      echo "HOME parent must exist and HOME must not end in '.' or '..'." >&2
      return 2
    fi
    parent="$(cd "$parent" 2>/dev/null && pwd -P)" || {
      echo "HOME parent cannot be resolved safely." >&2
      return 2
    }
    resolved_home="${parent%/}/$leaf"
  fi

  if [[ "$resolved_home" == "/" ]]; then
    echo "Unsafe HOME value resolves to filesystem root; refusing to manage global skill links." >&2
    return 2
  fi
  if [[ "$home_value" == *"|"* || "$home_value" =~ [[:cntrl:]] ]]; then
    echo "HOME cannot contain '|' or control characters; these are unsafe in the install manifest." >&2
    return 2
  fi
}

zstack_require_safe_state_dir() {
  local state_dir="$1"

  if [[ -L "$state_dir" ]]; then
    echo "zstack state directory must not be a symlink: $state_dir" >&2
    return 2
  fi
  if [[ -e "$state_dir" && ! -d "$state_dir" ]]; then
    echo "zstack state path exists but is not a directory: $state_dir" >&2
    return 2
  fi
}

zstack_require_safe_state_file() {
  local state_file="$1"
  local label="$2"
  local link_count=""

  if [[ -L "$state_file" ]]; then
    echo "$label must not be a symlink: $state_file" >&2
    return 2
  fi
  if [[ -e "$state_file" && ! -f "$state_file" ]]; then
    echo "$label exists but is not a regular file: $state_file" >&2
    return 2
  fi
  if [[ -f "$state_file" ]]; then
    link_count="$(zstack_file_link_count "$state_file")" || {
      echo "$label hard-link count cannot be measured safely: $state_file" >&2
      return 2
    }
    if [[ "$link_count" != "1" ]]; then
      echo "$label must have exactly one hard link: $state_file" >&2
      return 2
    fi
  fi
}

zstack_file_size_bytes() {
  local state_file="$1"
  local byte_count=""

  byte_count="$(stat -f '%z' "$state_file" 2>/dev/null)" || byte_count=""
  if [[ "$byte_count" =~ ^[0-9]+$ ]]; then
    printf '%s\n' "$byte_count"
    return 0
  fi

  byte_count="$(stat -c '%s' "$state_file" 2>/dev/null)" || byte_count=""
  if [[ "$byte_count" =~ ^[0-9]+$ ]]; then
    printf '%s\n' "$byte_count"
    return 0
  fi

  byte_count="$(LC_ALL=C wc -c < "$state_file" 2>/dev/null | tr -d '[:space:]')" || byte_count=""
  [[ "$byte_count" =~ ^[0-9]+$ ]] || return 1
  printf '%s\n' "$byte_count"
}

zstack_file_mode_bits() {
  local path="$1"
  local mode=""

  mode="$(stat -f '%Lp' "$path" 2>/dev/null)" || mode=""
  if [[ "$mode" =~ ^[0-7]{3,4}$ ]]; then
    printf '%s\n' "$mode"
    return 0
  fi

  mode="$(stat -c '%a' "$path" 2>/dev/null)" || mode=""
  [[ "$mode" =~ ^[0-7]{3,4}$ ]] || return 1
  printf '%s\n' "$mode"
}

zstack_file_uid() {
  local path="$1"
  local uid=""

  uid="$(stat -f '%u' "$path" 2>/dev/null)" || uid=""
  if [[ "$uid" =~ ^[0-9]+$ ]]; then
    printf '%s\n' "$uid"
    return 0
  fi

  uid="$(stat -c '%u' "$path" 2>/dev/null)" || uid=""
  [[ "$uid" =~ ^[0-9]+$ ]] || return 1
  printf '%s\n' "$uid"
}

zstack_file_link_count() {
  local path="$1"
  local link_count=""

  link_count="$(stat -f '%l' "$path" 2>/dev/null)" || link_count=""
  if [[ "$link_count" =~ ^[1-9][0-9]*$ ]]; then
    printf '%s\n' "$link_count"
    return 0
  fi

  link_count="$(stat -c '%h' "$path" 2>/dev/null)" || link_count=""
  [[ "$link_count" =~ ^[1-9][0-9]*$ ]] || return 1
  printf '%s\n' "$link_count"
}

zstack_file_identity() {
  local path="$1"
  local identity=""

  identity="$(stat -f '%d:%i' "$path" 2>/dev/null)" || identity=""
  if [[ "$identity" =~ ^[0-9]+:[0-9]+$ ]]; then
    printf '%s\n' "$identity"
    return 0
  fi

  identity="$(stat -c '%d:%i' "$path" 2>/dev/null)" || identity=""
  [[ "$identity" =~ ^[0-9]+:[0-9]+$ ]] || return 1
  printf '%s\n' "$identity"
}

zstack_regular_file_snapshot_is_unchanged() {
  local source_path="$1"
  local source_identity="$2"
  local snapshot_path="$3"
  local current_identity=""
  local source_link_count=""
  local snapshot_link_count=""

  [[ ! -L "$source_path" && -f "$source_path" ]] || return 1
  [[ ! -L "$snapshot_path" && -f "$snapshot_path" ]] || return 1
  current_identity="$(zstack_file_identity "$source_path")" || return 1
  source_link_count="$(zstack_file_link_count "$source_path")" || return 1
  snapshot_link_count="$(zstack_file_link_count "$snapshot_path")" || return 1
  [[ "$current_identity" == "$source_identity" ]] || return 1
  [[ "$source_link_count" == "1" && "$snapshot_link_count" == "1" ]] || return 1
  cmp -s "$source_path" "$snapshot_path"
}

zstack_remove_regular_file_if_identity() {
  local path="$1"
  local expected_identity="$2"
  local current_identity=""

  [[ -n "$path" && -n "$expected_identity" ]] || return 0
  [[ ! -L "$path" && -f "$path" ]] || return 0
  current_identity="$(zstack_file_identity "$path")" || return 0
  [[ "$current_identity" == "$expected_identity" ]] || return 0
  zstack_remove_regular_file_strict_if_identity "$path" "$expected_identity"
}

zstack_restore_quarantined_path() {
  local path="$1"
  local quarantine_path="$2"
  local quarantine_dir="$3"

  if [[ ! -e "$path" && ! -L "$path" ]] &&
     [[ -e "$quarantine_path" || -L "$quarantine_path" ]] &&
     mv "$quarantine_path" "$path"; then
    rmdir "$quarantine_dir" 2>/dev/null || true
    return 0
  fi
  echo "Preserved a path at $quarantine_path because $path could not be restored safely." >&2
  return 1
}

zstack_make_private_quarantine_dir() {
  local variable_name="$1"
  local base_path="$2"
  local candidate=""
  local _

  for _ in 1 2 3 4 5 6 7 8; do
    candidate="${base_path}.zstack-remove.$$.$RANDOM.$RANDOM"
    if (umask 077; mkdir "$candidate") 2>/dev/null; then
      chmod 700 "$candidate" || {
        rmdir "$candidate" 2>/dev/null || true
        return 1
      }
      printf -v "$variable_name" '%s' "$candidate"
      return 0
    fi
  done
  return 1
}

zstack_remove_path_strict_if_identity() {
  local path="$1"
  local expected_identity="$2"
  local expected_kind="$3"
  local expected_bytes_path="${4:-}"
  local current_identity=""
  local quarantine_dir=""
  local quarantine_path=""
  local quarantined_identity=""
  local link_count=""
  local quarantined_link_count=""
  local expected_bytes_identity=""
  local expected_bytes_current_identity=""
  local expected_bytes_link_count=""

  [[ -n "$path" && -n "$expected_identity" ]] || return 1
  if [[ -n "$expected_bytes_path" ]]; then
    [[ ! -L "$expected_bytes_path" && -f "$expected_bytes_path" ]] || return 1
    expected_bytes_identity="$(zstack_file_identity "$expected_bytes_path")" || return 1
    expected_bytes_link_count="$(zstack_file_link_count "$expected_bytes_path")" || return 1
    [[ "$expected_bytes_link_count" == "1" ]] || return 1
  fi
  case "$expected_kind" in
    regular)
      [[ ! -L "$path" && -f "$path" ]] || return 1
      link_count="$(zstack_file_link_count "$path")" || return 1
      [[ "$link_count" == "1" ]] || return 1
      ;;
    symlink) [[ -L "$path" ]] || return 1 ;;
    *) return 1 ;;
  esac
  current_identity="$(zstack_file_identity "$path")" || return 1
  [[ "$current_identity" == "$expected_identity" ]] || return 1

  zstack_make_private_quarantine_dir quarantine_dir "$path" || return 1
  quarantine_path="$quarantine_dir/entry"
  if ! mv "$path" "$quarantine_path"; then
    rmdir "$quarantine_dir" 2>/dev/null || true
    return 1
  fi

  quarantined_identity="$(zstack_file_identity "$quarantine_path" 2>/dev/null || true)"
  if [[ "$expected_kind" == "regular" ]]; then
    quarantined_link_count="$(zstack_file_link_count "$quarantine_path" 2>/dev/null || true)"
  fi
  if [[ -n "$expected_bytes_path" ]]; then
    expected_bytes_current_identity="$(
      zstack_file_identity "$expected_bytes_path" 2>/dev/null || true
    )"
    expected_bytes_link_count="$(
      zstack_file_link_count "$expected_bytes_path" 2>/dev/null || true
    )"
    if [[ -L "$expected_bytes_path" || ! -f "$expected_bytes_path" ]] ||
       [[ "$expected_bytes_current_identity" != "$expected_bytes_identity" ]] ||
       [[ "$expected_bytes_link_count" != "1" ]]; then
      zstack_restore_quarantined_path "$path" "$quarantine_path" "$quarantine_dir" || true
      return 1
    fi
  fi
  if [[ "$quarantined_identity" != "$expected_identity" ]] ||
     { [[ "$expected_kind" == "regular" ]] && [[ -L "$quarantine_path" || ! -f "$quarantine_path" ]]; } ||
     { [[ "$expected_kind" == "regular" ]] && [[ "$quarantined_link_count" != "1" ]]; } ||
     { [[ "$expected_kind" == "symlink" ]] && [[ ! -L "$quarantine_path" ]]; } ||
     { [[ -n "$expected_bytes_path" ]] && ! cmp -s "$quarantine_path" "$expected_bytes_path"; }; then
    zstack_restore_quarantined_path "$path" "$quarantine_path" "$quarantine_dir" || true
    return 1
  fi

  if ! rm -f "$quarantine_path"; then
    if [[ -e "$quarantine_path" || -L "$quarantine_path" ]]; then
      zstack_restore_quarantined_path "$path" "$quarantine_path" "$quarantine_dir" || true
      return 1
    fi
  fi
  if [[ -e "$quarantine_path" || -L "$quarantine_path" ]]; then
    zstack_restore_quarantined_path "$path" "$quarantine_path" "$quarantine_dir" || true
    return 1
  fi
  if ! rmdir "$quarantine_dir"; then
    echo "Removed $path but could not remove empty quarantine directory $quarantine_dir." >&2
    return 1
  fi
}

zstack_remove_regular_file_strict_if_identity() {
  zstack_remove_path_strict_if_identity "$1" "$2" regular "${3:-}"
}

zstack_remove_symlink_if_identity() {
  zstack_remove_path_strict_if_identity "$1" "$2" symlink
}

ZSTACK_IDENTITY_TEMP_PATHS=()
ZSTACK_IDENTITY_TEMP_IDENTITIES=()

zstack_make_identity_temp_file() {
  local variable_name="$1"
  local template="$2"
  local identity_variable="${3:-}"
  local path=""
  local identity=""

  [[ "$variable_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || return 1
  if [[ -n "$identity_variable" ]]; then
    [[ "$identity_variable" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || return 1
    [[ "$variable_name" != "$identity_variable" ]] || return 1
  fi
  path="$(mktemp "$template")" || return
  identity="$(zstack_file_identity "$path")" || {
    echo "Could not identify temporary file safely: $path" >&2
    return 1
  }
  ZSTACK_IDENTITY_TEMP_PATHS+=("$path")
  ZSTACK_IDENTITY_TEMP_IDENTITIES+=("$identity")
  printf -v "$variable_name" '%s' "$path"
  [[ -z "$identity_variable" ]] || printf -v "$identity_variable" '%s' "$identity"
}

zstack_capture_regular_file_snapshot() {
  local source_path="$1"
  local snapshot_variable="$2"
  local identity_variable="$3"
  local template="$4"
  local snapshot_identity_variable="${5:-}"
  local zstack_captured_snapshot=""
  local zstack_captured_identity=""
  local zstack_captured_snapshot_identity=""
  local zstack_current_snapshot_identity=""

  [[ "$snapshot_variable" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || return 1
  [[ "$identity_variable" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || return 1
  [[ "$snapshot_variable" != "$identity_variable" ]] || return 1
  if [[ -n "$snapshot_identity_variable" ]]; then
    [[ "$snapshot_identity_variable" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || return 1
    [[ "$snapshot_identity_variable" != "$snapshot_variable" ]] || return 1
    [[ "$snapshot_identity_variable" != "$identity_variable" ]] || return 1
  fi
  [[ ! -L "$source_path" && -f "$source_path" ]] || return 1
  zstack_captured_identity="$(zstack_file_identity "$source_path")" || return 1
  zstack_make_identity_temp_file \
    zstack_captured_snapshot "$template" zstack_captured_snapshot_identity || return 1
  cp "$source_path" "$zstack_captured_snapshot" || return 1
  zstack_current_snapshot_identity="$(
    zstack_file_identity "$zstack_captured_snapshot" 2>/dev/null || true
  )"
  [[ "$zstack_current_snapshot_identity" == "$zstack_captured_snapshot_identity" ]] || return 1
  zstack_regular_file_snapshot_is_unchanged \
    "$source_path" "$zstack_captured_identity" "$zstack_captured_snapshot" || return 1
  zstack_current_snapshot_identity="$(
    zstack_file_identity "$zstack_captured_snapshot" 2>/dev/null || true
  )"
  [[ "$zstack_current_snapshot_identity" == "$zstack_captured_snapshot_identity" ]] || return 1
  printf -v "$snapshot_variable" '%s' "$zstack_captured_snapshot"
  printf -v "$identity_variable" '%s' "$zstack_captured_identity"
  [[ -z "$snapshot_identity_variable" ]] ||
    printf -v "$snapshot_identity_variable" '%s' "$zstack_captured_snapshot_identity"
}

zstack_publish_identity_temp_file() {
  local source_path="$1"
  local expected_identity="$2"
  local destination_path="$3"
  local current_identity=""
  local source_link_count=""
  local destination_link_count=""
  local quarantine_dir=""
  local quarantine_path=""
  local registry_index=-1
  local matched_registry_entries=0
  local index

  [[ -n "$source_path" && -n "$expected_identity" && -n "$destination_path" ]] || return 1
  [[ ! -L "$source_path" && -f "$source_path" ]] || return 1
  [[ ! -e "$destination_path" && ! -L "$destination_path" ]] || return 1
  current_identity="$(zstack_file_identity "$source_path")" || return 1
  source_link_count="$(zstack_file_link_count "$source_path")" || return 1
  [[ "$current_identity" == "$expected_identity" && "$source_link_count" == "1" ]] || return 1

  for ((index = 0; index < ${#ZSTACK_IDENTITY_TEMP_PATHS[@]}; index++)); do
    if [[ "${ZSTACK_IDENTITY_TEMP_PATHS[$index]}" == "$source_path" &&
          "${ZSTACK_IDENTITY_TEMP_IDENTITIES[$index]}" == "$expected_identity" ]]; then
      registry_index=$index
      matched_registry_entries=$((matched_registry_entries + 1))
    fi
  done
  [[ "$matched_registry_entries" -eq 1 ]] || return 1

  ln "$source_path" "$destination_path" || return 1
  current_identity="$(zstack_file_identity "$destination_path" 2>/dev/null || true)"
  source_link_count="$(zstack_file_link_count "$source_path" 2>/dev/null || true)"
  destination_link_count="$(zstack_file_link_count "$destination_path" 2>/dev/null || true)"
  if [[ -L "$destination_path" || ! -f "$destination_path" ]] ||
     [[ "$current_identity" != "$expected_identity" ]] ||
     [[ "$source_link_count" != "2" || "$destination_link_count" != "2" ]]; then
    return 1
  fi

  zstack_make_private_quarantine_dir quarantine_dir "$source_path" || return 1
  quarantine_path="$quarantine_dir/entry"
  if ! mv "$source_path" "$quarantine_path"; then
    rmdir "$quarantine_dir" 2>/dev/null || true
    return 1
  fi
  current_identity="$(zstack_file_identity "$quarantine_path" 2>/dev/null || true)"
  source_link_count="$(zstack_file_link_count "$quarantine_path" 2>/dev/null || true)"
  destination_link_count="$(zstack_file_link_count "$destination_path" 2>/dev/null || true)"
  if [[ -L "$quarantine_path" || ! -f "$quarantine_path" ]] ||
     [[ "$current_identity" != "$expected_identity" ]] ||
     [[ "$source_link_count" != "2" || "$destination_link_count" != "2" ]]; then
    zstack_restore_quarantined_path \
      "$source_path" "$quarantine_path" "$quarantine_dir" || true
    return 1
  fi
  if ! unlink "$quarantine_path"; then
    if [[ -e "$quarantine_path" || -L "$quarantine_path" ]]; then
      zstack_restore_quarantined_path \
        "$source_path" "$quarantine_path" "$quarantine_dir" || true
      return 1
    fi
  fi
  if [[ -e "$quarantine_path" || -L "$quarantine_path" ]] ||
     ! rmdir "$quarantine_dir"; then
    return 1
  fi

  current_identity="$(zstack_file_identity "$destination_path" 2>/dev/null || true)"
  destination_link_count="$(zstack_file_link_count "$destination_path" 2>/dev/null || true)"
  if [[ -L "$destination_path" || ! -f "$destination_path" ]] ||
     [[ "$current_identity" != "$expected_identity" ]] ||
     [[ "$destination_link_count" != "1" ]]; then
    return 1
  fi
  ZSTACK_IDENTITY_TEMP_PATHS[registry_index]="$destination_path"
  ZSTACK_IDENTITY_TEMP_IDENTITIES[registry_index]="$expected_identity"
  current_identity="$(zstack_file_identity "$destination_path" 2>/dev/null || true)"
  destination_link_count="$(zstack_file_link_count "$destination_path" 2>/dev/null || true)"
  [[ ! -L "$destination_path" && -f "$destination_path" ]] || return 1
  [[ "$current_identity" == "$expected_identity" && "$destination_link_count" == "1" ]]
}

zstack_track_identity_temp_file() {
  local path="$1"
  local identity_variable="${2:-}"
  local identity=""

  [[ ! -L "$path" && -f "$path" ]] || {
    echo "Could not track unsafe temporary file: $path" >&2
    return 1
  }
  identity="$(zstack_file_identity "$path")" || {
    echo "Could not identify temporary file safely: $path" >&2
    return 1
  }
  ZSTACK_IDENTITY_TEMP_PATHS+=("$path")
  ZSTACK_IDENTITY_TEMP_IDENTITIES+=("$identity")
  [[ -z "$identity_variable" ]] || printf -v "$identity_variable" '%s' "$identity"
}

zstack_cleanup_identity_temp_files() {
  local index
  local path
  local identity
  local cleanup_failed=0
  local remaining_paths=()
  local remaining_identities=()

  for ((index = 0; index < ${#ZSTACK_IDENTITY_TEMP_PATHS[@]}; index++)); do
    path="${ZSTACK_IDENTITY_TEMP_PATHS[$index]}"
    identity="${ZSTACK_IDENTITY_TEMP_IDENTITIES[$index]}"
    if ! zstack_remove_regular_file_if_identity "$path" "$identity"; then
      remaining_paths+=("$path")
      remaining_identities+=("$identity")
      cleanup_failed=1
    fi
  done
  if [[ "$cleanup_failed" -eq 1 ]]; then
    ZSTACK_IDENTITY_TEMP_PATHS=("${remaining_paths[@]}")
    ZSTACK_IDENTITY_TEMP_IDENTITIES=("${remaining_identities[@]}")
  else
    ZSTACK_IDENTITY_TEMP_PATHS=()
    ZSTACK_IDENTITY_TEMP_IDENTITIES=()
  fi
  return "$cleanup_failed"
}

zstack_mode_is_owner_only() {
  local mode="$1"

  [[ "$mode" =~ ^[0-7]{3,4}$ ]] || return 1
  (( (8#$mode & 077) == 0 ))
}

zstack_require_private_owned_path() {
  local path="$1"
  local label="$2"
  local mode=""
  local path_uid=""
  local current_uid=""

  mode="$(zstack_file_mode_bits "$path")" || {
    echo "Refusing unsafe $label whose permissions cannot be measured: $path" >&2
    return 1
  }
  if ! zstack_mode_is_owner_only "$mode"; then
    echo "Refusing unsafe $label permissions $mode: $path" >&2
    return 1
  fi
  path_uid="$(zstack_file_uid "$path")" || {
    echo "Refusing unsafe $label whose owner cannot be measured: $path" >&2
    return 1
  }
  current_uid="$(id -u 2>/dev/null)" || {
    echo "Refusing unsafe $label because the current user cannot be identified: $path" >&2
    return 1
  }
  if [[ "$path_uid" != "$current_uid" ]]; then
    echo "Refusing unsafe $label owned by uid $path_uid instead of uid $current_uid: $path" >&2
    return 1
  fi
}

zstack_require_bounded_state_file() {
  local state_file="$1"
  local label="$2"
  local max_bytes="$3"
  local byte_count=""
  local text_byte_count=""

  zstack_require_safe_state_file "$state_file" "$label" || return
  [[ -f "$state_file" ]] || return 0
  if ! byte_count="$(zstack_file_size_bytes "$state_file")"; then
    echo "$label size cannot be measured safely: $state_file" >&2
    return 2
  fi
  if [[ "$byte_count" -gt "$max_bytes" ]]; then
    echo "$label exceeds the $max_bytes-byte safety limit: $state_file" >&2
    return 2
  fi
  if ! text_byte_count="$(LC_ALL=C tr -d '\000' < "$state_file" | wc -c | tr -d '[:space:]')" ||
     [[ ! "$text_byte_count" =~ ^[0-9]+$ ]]; then
    echo "$label text integrity cannot be verified safely: $state_file" >&2
    return 2
  fi
  if [[ "$text_byte_count" -ne "$byte_count" ]]; then
    echo "$label contains a NUL byte and is not valid text: $state_file" >&2
    return 2
  fi
}

zstack_is_manifest_safe_path() {
  local path="$1"
  [[ "$path" == /* && "$path" != *"|"* && ! "$path" =~ [[:cntrl:]] ]]
}

zstack_read_root_record() {
  local root_record="$1"
  local line_count=""
  local root_value=""

  zstack_require_bounded_state_file \
    "$root_record" \
    "zstack root record" \
    "$ZSTACK_ROOT_RECORD_MAX_BYTES" >/dev/null 2>&1 || return 1
  [[ -f "$root_record" ]] || return 1
  line_count="$(awk 'END { print NR + 0 }' "$root_record" 2>/dev/null)" || return 1
  [[ "$line_count" == "1" ]] || return 1
  if ! IFS= read -r root_value < "$root_record"; then
    [[ -n "$root_value" ]] || return 1
  fi
  zstack_is_manifest_safe_path "$root_value" || return 1
  printf '%s\n' "$root_value"
}

zstack_require_safe_root_record() {
  local root_record="$1"

  zstack_require_bounded_state_file \
    "$root_record" \
    "zstack root record" \
    "$ZSTACK_ROOT_RECORD_MAX_BYTES" || return
  [[ -f "$root_record" ]] || return 0
  if ! zstack_read_root_record "$root_record" >/dev/null; then
    echo "zstack root record must contain exactly one safe absolute path: $root_record" >&2
    return 2
  fi
}

zstack_require_safe_install_state() {
  local state_dir="$1"

  zstack_require_safe_state_dir "$state_dir" || return
  zstack_require_bounded_state_file \
    "$state_dir/links" \
    "zstack install manifest" \
    "$ZSTACK_LINK_MANIFEST_MAX_BYTES" || return
  zstack_require_safe_root_record "$state_dir/root"
}

zstack_is_manifest_line_safe() {
  local line="$1"
  local recorded_root recorded_link

  [[ "$line" == *"|"* ]] || return 1
  recorded_root="${line%%|*}"
  recorded_link="${line#*|}"
  [[ "$recorded_link" != *"|"* ]] || return 1
  zstack_is_manifest_safe_path "$recorded_root" &&
    zstack_is_manifest_safe_path "$recorded_link"
}

zstack_quote_for_log() {
  printf '%q' "$1"
}

zstack_is_safe_home_relative_path() {
  local path="$1"
  local remainder

  [[ "${path:0:2}" == $'\x7e/' ]] || return 1
  remainder="${path#\~/}"
  [[ -n "$remainder" ]] || return 1
  case "/$remainder/" in
    *"/./"*|*"/../"*|*"//"*) return 1 ;;
  esac
  [[ "$remainder" =~ ^[a-zA-Z0-9._-]+(/[a-zA-Z0-9._-]+)*$ ]]
}

zstack_expand_path() {
  local path="$1"
  if ! zstack_is_safe_home_relative_path "$path"; then
    echo "Unsafe HOME-relative path: $path" >&2
    return 2
  fi
  printf '%s\n' "${path/#\~/$HOME}"
}

zstack_resolve_link_target() {
  local link="$1"
  local target target_leaf target_parent resolved_parent

  [[ -L "$link" ]] || return 1
  target="$(readlink "$link")"
  [[ ! "$target" =~ [[:cntrl:]] ]] || return 1
  target_leaf="$(basename "$target")"
  [[ "$target_leaf" != "." && "$target_leaf" != ".." ]] || return 1
  if [[ "$target" == /* ]]; then
    target_parent="$(dirname "$target")"
  else
    target_parent="$(dirname "$link")/$(dirname "$target")"
  fi
  resolved_parent="$(cd "$target_parent" 2>/dev/null && pwd -P)" || return 1
  printf '%s/%s\n' "${resolved_parent%/}" "$target_leaf"
}

zstack_find_unexpected_lock_entry() (
  local lock_path="$1"
  local owner_path="$lock_path/pid"
  local entry=""
  local -a entries=()

  if [[ ! -r "$lock_path" || ! -x "$lock_path" ]]; then
    zstack_quote_for_log "$lock_path"
    return 0
  fi

  shopt -u failglob
  shopt -s dotglob nullglob
  entries=("$lock_path"/*)
  for entry in "${entries[@]}"; do
    [[ "$entry" == "$owner_path" ]] && continue
    zstack_quote_for_log "$entry"
    return 0
  done
  return 1
)

zstack_read_pid_lock_owner() {
  local owner_path="$1"
  local line_count=""
  local owner_pid=""

  zstack_require_bounded_state_file \
    "$owner_path" \
    "PID lock owner" \
    "$ZSTACK_PID_LOCK_OWNER_MAX_BYTES" >/dev/null 2>&1 || return 1
  [[ -f "$owner_path" ]] || return 1
  line_count="$(awk 'END { print NR + 0 }' "$owner_path" 2>/dev/null)" || return 1
  [[ "$line_count" == "1" ]] || return 1
  if ! IFS= read -r owner_pid 2>/dev/null < "$owner_path"; then
    [[ -n "$owner_pid" ]] || return 1
  fi
  [[ "$owner_pid" =~ ^[1-9][0-9]*$ ]] || return 1
  printf '%s\n' "$owner_pid"
}

zstack_acquire_pid_lock() {
  local lock_path="$1"
  local label="$2"
  local existing_pid=""
  local owner_path=""
  local unexpected_entry=""
  local lock_identity=""
  local owner_identity=""
  local current_identity=""
  local current_pid=""
  local _

  for _ in 1 2 3 4; do
    if (umask 077; mkdir "$lock_path") 2>/dev/null; then
      owner_path="$lock_path/pid"
      if (umask 077; printf '%s\n' "$$" > "$lock_path/pid"); then
        owner_identity="$(zstack_file_identity "$owner_path" 2>/dev/null || true)"
        current_pid="$(zstack_read_pid_lock_owner "$owner_path" 2>/dev/null || true)"
        current_identity="$(zstack_file_identity "$owner_path" 2>/dev/null || true)"
        if [[ ! -L "$owner_path" && -f "$owner_path" ]] &&
           zstack_require_private_owned_path \
             "$owner_path" "$label lock owner file" >/dev/null 2>&1 &&
           [[ -n "$owner_identity" && "$current_identity" == "$owner_identity" ]] &&
           [[ "$current_pid" == "$$" ]]; then
          return 0
        fi
      fi
      if [[ ! -L "$owner_path" && -f "$owner_path" ]] &&
         zstack_require_private_owned_path \
           "$owner_path" "$label lock owner file" >/dev/null 2>&1; then
        owner_identity="$(zstack_file_identity "$owner_path" 2>/dev/null || true)"
        if [[ -n "$owner_identity" ]]; then
          zstack_remove_regular_file_strict_if_identity \
            "$owner_path" "$owner_identity" || true
        fi
      fi
      rmdir "$lock_path" 2>/dev/null || true
      echo "Could not initialize $label lock: $lock_path" >&2
      return 1
    fi

    if [[ -L "$lock_path" ]]; then
      echo "Refusing unsafe $label lock symlink: $lock_path" >&2
      return 1
    fi
    if [[ -e "$lock_path" && ! -f "$lock_path" && ! -d "$lock_path" ]]; then
      echo "Refusing unsafe $label lock path type: $lock_path" >&2
      return 1
    fi
    if [[ -e "$lock_path" ]] && ! zstack_require_private_owned_path "$lock_path" "$label lock"; then
      return 1
    fi
    if [[ -f "$lock_path" ]] && ! zstack_require_bounded_state_file \
      "$lock_path" "PID lock owner" "$ZSTACK_PID_LOCK_OWNER_MAX_BYTES"; then
      return 1
    fi
    if [[ -d "$lock_path" ]]; then
      owner_path="$lock_path/pid"
      if [[ -L "$owner_path" ]] || { [[ -e "$owner_path" ]] && [[ ! -f "$owner_path" ]]; }; then
        echo "Refusing unsafe $label lock owner file: $owner_path" >&2
        return 1
      fi
      if [[ -e "$owner_path" ]] && ! zstack_require_private_owned_path "$owner_path" "$label lock owner file"; then
        return 1
      fi
      if [[ -f "$owner_path" ]] && ! zstack_require_bounded_state_file \
        "$owner_path" "PID lock owner" "$ZSTACK_PID_LOCK_OWNER_MAX_BYTES"; then
        return 1
      fi
    fi

    existing_pid=""
    if [[ -f "$lock_path" ]]; then
      lock_identity="$(zstack_file_identity "$lock_path")" || continue
      if ! existing_pid="$(zstack_read_pid_lock_owner "$lock_path")"; then
        echo "Refusing to recover $label lock with invalid or unreadable owner metadata: $lock_path" >&2
        return 1
      fi
      current_identity="$(zstack_file_identity "$lock_path" 2>/dev/null || true)"
      [[ "$current_identity" == "$lock_identity" ]] || continue
    elif [[ -d "$lock_path" ]]; then
      owner_path="$lock_path/pid"
      if [[ ! -f "$owner_path" ]]; then
        echo "Refusing to recover $label lock with missing owner metadata: $owner_path" >&2
        return 1
      fi
      owner_identity="$(zstack_file_identity "$owner_path")" || continue
      if ! existing_pid="$(zstack_read_pid_lock_owner "$owner_path")"; then
        echo "Refusing to recover $label lock with invalid or unreadable owner metadata: $owner_path" >&2
        return 1
      fi
      current_identity="$(zstack_file_identity "$owner_path" 2>/dev/null || true)"
      [[ "$current_identity" == "$owner_identity" ]] || continue
    fi
    if kill -0 "$existing_pid" 2>/dev/null; then
      echo "Another $label operation is in progress (pid $existing_pid): $lock_path" >&2
      return 1
    fi

    if [[ -d "$lock_path" ]]; then
      if unexpected_entry="$(zstack_find_unexpected_lock_entry "$lock_path")"; then
        echo "Refusing to recover stale $label lock directory with unexpected entry: $unexpected_entry" >&2
        return 1
      fi
      current_identity="$(zstack_file_identity "$owner_path" 2>/dev/null || true)"
      current_pid="$(zstack_read_pid_lock_owner "$owner_path" 2>/dev/null || true)"
      if [[ "$current_identity" != "$owner_identity" || "$current_pid" != "$existing_pid" ]] ||
         ! zstack_remove_regular_file_strict_if_identity "$owner_path" "$owner_identity"; then
        continue
      fi
      if ! rmdir "$lock_path" 2>/dev/null; then
        echo "Cannot recover stale $label lock directory: $lock_path" >&2
        return 1
      fi
    elif [[ -e "$lock_path" ]]; then
      current_identity="$(zstack_file_identity "$lock_path" 2>/dev/null || true)"
      current_pid="$(zstack_read_pid_lock_owner "$lock_path" 2>/dev/null || true)"
      if [[ "$current_identity" != "$lock_identity" || "$current_pid" != "$existing_pid" ]] ||
         ! zstack_remove_regular_file_strict_if_identity "$lock_path" "$lock_identity"; then
        continue
      fi
    else
      continue
    fi
    echo "Recovered stale $label lock: $lock_path" >&2
  done

  echo "Could not acquire $label lock after concurrent retries: $lock_path" >&2
  return 1
}

zstack_release_pid_lock() {
  local lock_path="$1"
  local owner_pid=""
  local owner_path=""
  local lock_identity=""
  local owner_identity=""
  local current_identity=""

  [[ ! -L "$lock_path" ]] || return 0
  if [[ -f "$lock_path" ]]; then
    zstack_require_private_owned_path "$lock_path" "PID lock" >/dev/null 2>&1 || return 0
    lock_identity="$(zstack_file_identity "$lock_path")" || return 0
    owner_pid="$(zstack_read_pid_lock_owner "$lock_path" 2>/dev/null || true)"
    current_identity="$(zstack_file_identity "$lock_path" 2>/dev/null || true)"
    if [[ "$owner_pid" == "$$" && "$current_identity" == "$lock_identity" ]]; then
      zstack_remove_regular_file_strict_if_identity "$lock_path" "$lock_identity" || true
    fi
  elif [[ -d "$lock_path" ]]; then
    zstack_require_private_owned_path "$lock_path" "PID lock" >/dev/null 2>&1 || return 0
    owner_path="$lock_path/pid"
    [[ ! -L "$owner_path" && -f "$owner_path" ]] || return 0
    zstack_require_private_owned_path "$owner_path" "PID lock owner file" >/dev/null 2>&1 || return 0
    owner_identity="$(zstack_file_identity "$owner_path")" || return 0
    owner_pid="$(zstack_read_pid_lock_owner "$owner_path" 2>/dev/null || true)"
    current_identity="$(zstack_file_identity "$owner_path" 2>/dev/null || true)"
    if [[ "$owner_pid" == "$$" ]]; then
      [[ "$current_identity" == "$owner_identity" ]] || return 0
      if zstack_find_unexpected_lock_entry "$lock_path" >/dev/null; then
        return 0
      fi
      zstack_remove_regular_file_strict_if_identity "$owner_path" "$owner_identity" || return 0
      rmdir "$lock_path" 2>/dev/null || true
    fi
  fi
}

# Print: name|display_name|skills_root|link_mode|enabled|max_description|required_name|required_description
zstack_host_profile() {
  local file="$1"
  awk '
    /^name:[[:space:]]*/ { value = $0; sub(/^name:[[:space:]]*/, "", value); name = value }
    /^display_name:[[:space:]]*/ { value = $0; sub(/^display_name:[[:space:]]*/, "", value); display = value }
    /^skills_root:[[:space:]]*/ { value = $0; sub(/^skills_root:[[:space:]]*/, "", value); root = value }
    /^link_mode:[[:space:]]*/ { value = $0; sub(/^link_mode:[[:space:]]*/, "", value); mode = value }
    /^enabled:[[:space:]]*/ { value = $0; sub(/^enabled:[[:space:]]*/, "", value); enabled = value }
    /^[[:space:]]+description_max_chars:[[:space:]]*/ {
      value = $0
      sub(/^[[:space:]]+description_max_chars:[[:space:]]*/, "", value)
      max = value
    }
    /^[[:space:]]+-[[:space:]]+name[[:space:]]*$/ { required_name = 1 }
    /^[[:space:]]+-[[:space:]]+description[[:space:]]*$/ { required_description = 1 }
    END {
      gsub(/^[\047\"]|[\047\"]$/, "", name)
      gsub(/^[\047\"]|[\047\"]$/, "", display)
      gsub(/^[\047\"]|[\047\"]$/, "", root)
      gsub(/^[\047\"]|[\047\"]$/, "", mode)
      gsub(/^[\047\"]|[\047\"]$/, "", enabled)
      if (enabled == "") enabled = "true"
      print name "|" display "|" root "|" mode "|" enabled "|" max "|" (required_name + 0) "|" (required_description + 0)
    }
  ' "$file"
}

# Print entries as: id|path|status|comma-separated-hosts|category|comma-separated-tags|summary-chars
# This intentionally supports only zstack's documented, small YAML shape.
zstack_catalog_entries() {
  local catalog="$1"
  awk '
    function clean(value) {
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      gsub(/^[\047\"]|[\047\"]$/, "", value)
      return value
    }
    function flush() {
      if (id != "") {
        print id "|" path "|" status "|" hosts "|" category "|" tags "|" summary_chars
      }
    }
    function inline_list_values(value, parts, count, i, item, result) {
      gsub(/^\[|\]$/, "", value)
      if (clean(value) == "") return ""
      count = split(value, parts, ",")
      for (i = 1; i <= count; i++) {
        item = clean(parts[i])
        if (item != "") result = result (result == "" ? "" : ",") item
      }
      return result
    }
    /^  - id:[[:space:]]*/ {
      flush()
      id = $0
      sub(/^  - id:[[:space:]]*/, "", id)
      id = clean(id)
      path = ""
      status = ""
      hosts = ""
      category = ""
      tags = ""
      summary_chars = 0
      section = ""
      next
    }
    id != "" && /^    path:[[:space:]]*/ {
      path = $0
      sub(/^    path:[[:space:]]*/, "", path)
      path = clean(path)
      section = ""
      next
    }
    id != "" && /^    status:[[:space:]]*/ {
      status = $0
      sub(/^    status:[[:space:]]*/, "", status)
      status = clean(status)
      section = ""
      next
    }
    id != "" && /^    category:[[:space:]]*/ {
      category = $0
      sub(/^    category:[[:space:]]*/, "", category)
      category = clean(category)
      section = ""
      next
    }
    id != "" && /^    hosts:[[:space:]]*/ {
      value = $0
      sub(/^    hosts:[[:space:]]*/, "", value)
      value = clean(value)
      if (value ~ /^\[.*\]$/) {
        gsub(/^\[|\]$/, "", value)
        gsub(/[[:space:]]+/, "", value)
        hosts = value
        section = ""
      } else {
        section = "hosts"
      }
      next
    }
    id != "" && /^    tags:[[:space:]]*/ {
      value = $0
      sub(/^    tags:[[:space:]]*/, "", value)
      value = clean(value)
      if (value ~ /^\[.*\]$/) {
        tags = inline_list_values(value)
        section = ""
      } else {
        section = "tags"
      }
      next
    }
    id != "" && /^    summary:[[:space:]]*/ {
      value = $0
      sub(/^    summary:[[:space:]]*/, "", value)
      value = clean(value)
      if (value == ">-" || value == ">" || value == "|-" || value == "|") {
        section = "summary"
      } else {
        summary_chars = length(value)
        section = ""
      }
      next
    }
    id != "" && section == "hosts" && /^      -[[:space:]]*/ {
      value = $0
      sub(/^      -[[:space:]]*/, "", value)
      value = clean(value)
      hosts = hosts (hosts == "" ? "" : ",") value
      next
    }
    id != "" && section == "tags" && /^      -[[:space:]]*/ {
      value = $0
      sub(/^      -[[:space:]]*/, "", value)
      value = clean(value)
      if (value != "") tags = tags (tags == "" ? "" : ",") value
      next
    }
    id != "" && section == "summary" && /^      / {
      value = clean($0)
      summary_chars += length(value)
      next
    }
    id != "" && /^    [a-zA-Z0-9_-]+:[[:space:]]*/ {
      section = ""
    }
    END { flush() }
  ' "$catalog"
}

zstack_active_skill_dirs() {
  local catalog="$1"
  local root="$2"
  local host="${3:-}"

  zstack_catalog_entries "$catalog" | awk -F'|' -v root="$root" -v host="$host" '
    $3 == "active" && (host == "" || index("," $4 ",", "," host ",") != 0) {
      print root "/" $2
    }
  '
}
