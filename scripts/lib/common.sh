#!/usr/bin/env bash
# Shared, dependency-free helpers for zstack scripts.

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

  if [[ -L "$state_file" ]]; then
    echo "$label must not be a symlink: $state_file" >&2
    return 2
  fi
  if [[ -e "$state_file" && ! -f "$state_file" ]]; then
    echo "$label exists but is not a regular file: $state_file" >&2
    return 2
  fi
}

zstack_is_manifest_safe_path() {
  local path="$1"
  [[ "$path" == /* && "$path" != *"|"* && ! "$path" =~ [[:cntrl:]] ]]
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

zstack_acquire_pid_lock() {
  local lock_path="$1"
  local label="$2"
  local existing_pid=""
  local owner_path=""
  local _

  for _ in 1 2 3 4; do
    if (umask 077; mkdir "$lock_path") 2>/dev/null; then
      if printf '%s\n' "$$" > "$lock_path/pid"; then
        return 0
      fi
      rm -f "$lock_path/pid"
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
    if [[ -d "$lock_path" ]]; then
      owner_path="$lock_path/pid"
      if [[ -L "$owner_path" ]] || { [[ -e "$owner_path" ]] && [[ ! -f "$owner_path" ]]; }; then
        echo "Refusing unsafe $label lock owner file: $owner_path" >&2
        return 1
      fi
    fi

    existing_pid=""
    if [[ -f "$lock_path" ]]; then
      read -r existing_pid < "$lock_path" || true
    elif [[ -d "$lock_path" && -f "$lock_path/pid" ]]; then
      read -r existing_pid < "$lock_path/pid" || true
    fi
    if [[ "$existing_pid" =~ ^[1-9][0-9]*$ ]] && kill -0 "$existing_pid" 2>/dev/null; then
      echo "Another $label operation is in progress (pid $existing_pid): $lock_path" >&2
      return 1
    fi

    if [[ -d "$lock_path" ]]; then
      rm -f "$lock_path/pid"
      if ! rmdir "$lock_path" 2>/dev/null; then
        echo "Cannot recover stale $label lock directory: $lock_path" >&2
        return 1
      fi
    elif [[ -e "$lock_path" ]]; then
      if ! rm -f "$lock_path"; then
        echo "Cannot recover stale $label lock: $lock_path" >&2
        return 1
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

  [[ ! -L "$lock_path" ]] || return 0
  if [[ -f "$lock_path" ]]; then
    read -r owner_pid < "$lock_path" || true
    [[ "$owner_pid" == "$$" ]] && rm -f "$lock_path"
  elif [[ -d "$lock_path" ]]; then
    owner_path="$lock_path/pid"
    [[ ! -L "$owner_path" && -f "$owner_path" ]] || return 0
    read -r owner_pid < "$owner_path" || true
    if [[ "$owner_pid" == "$$" ]]; then
      rm -f "$owner_path"
      rmdir "$lock_path" 2>/dev/null || true
    fi
  fi
}

zstack_host_field() {
  local file="$1"
  local field="$2"
  awk -v field="$field" '
    $0 ~ "^[[:space:]]*" field ":[[:space:]]*" {
      sub("^[[:space:]]*" field ":[[:space:]]*", "")
      gsub(/^[\047\"]|[\047\"]$/, "")
      print
      exit
    }
  ' "$file"
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
