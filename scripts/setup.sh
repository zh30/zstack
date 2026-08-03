#!/usr/bin/env bash
# Symlink active catalog skills into configured agent host roots.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
CATALOG="$ROOT/catalog.yaml"
HOSTS_DIR="$ROOT/hosts"
FORCE=0
PROJECT=0
PROJECT_BASE=""
HOST_FILTER=""
BACKUP_STAMP="$(date +%Y%m%d%H%M%S)-$$"
SKIPPED=0
FAILURES=0
RECORDED=0
REMOVED_STALE=0
RETIRED_OWNERS=0
STATE_DIR="$HOME/.zstack"
LINK_MANIFEST="$STATE_DIR/links"
LINK_RECORD_TMP=""
SCOPE_ROOTS_TMP=""
OPERATION_LOCK=""
MANIFEST_SOURCE_TMP=""
MANIFEST_SOURCE_IDENTITY=""
MANIFEST_SOURCE_PRESENT=0
MANIFEST_NEXT_TMP=""
MANIFEST_MERGED_TMP=""
MANIFEST_EXPECTED_TMP=""
MANIFEST_PUBLISH_IDENTITY=""
ROOT_NEXT_TMP=""
ROOT_EXPECTED_TMP=""
ROOT_PUBLISH_IDENTITY=""
ROOT_SOURCE_TMP=""
ROOT_SOURCE_IDENTITY=""
CATALOG_SOURCE_TMP=""
CATALOG_SOURCE_IDENTITY=""
CATALOG_ENTRIES_TMP=""
HOST_PROFILES_TMP=""
HOST_SOURCE_PATHS=()
HOST_SOURCE_IDENTITIES=()
HOST_SOURCE_SNAPSHOTS=()
HOST_SOURCE_COUNT=0
host_source_name=""
host_source_identity=""
host_source_snapshot=""

# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: ./scripts/setup.sh [options]

  --force          Back up conflicting paths, then install zstack links
  --project        Also link Agent Skills into <cwd>/.agents/skills
  --hosts a,b,c    Reconcile only these profiles; explicitly enables optional profiles
  -h, --help       Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    --project) PROJECT=1; shift ;;
    --hosts)
      [[ $# -ge 2 && -n "$2" ]] || { echo "--hosts requires a comma-separated value" >&2; exit 2; }
      HOST_FILTER="$2"
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

zstack_require_safe_home
zstack_require_safe_install_state "$STATE_DIR"

if [[ -n "$HOST_FILTER" ]]; then
  if [[ ! "$HOST_FILTER" =~ ^[a-z][a-z0-9-]*(,[a-z][a-z0-9-]*)*$ ]]; then
    echo "Invalid --hosts list '$HOST_FILTER'. Use unique comma-separated profile names." >&2
    exit 2
  fi
  duplicate_requested_host="$(printf '%s\n' "$HOST_FILTER" | tr ',' '\n' | sort | uniq -d | sed -n '1p')"
  if [[ -n "$duplicate_requested_host" ]]; then
    echo "Duplicate host profile in --hosts: $duplicate_requested_host" >&2
    exit 2
  fi
  old_ifs="$IFS"
  IFS=','
  for requested_host in $HOST_FILTER; do
    if [[ ! "$requested_host" =~ ^[a-z][a-z0-9-]*$ ]]; then
      echo "Invalid host profile name: $requested_host" >&2
      exit 2
    fi
    if [[ ! -f "$HOSTS_DIR/$requested_host.yaml" ]]; then
      echo "Unknown host profile: $requested_host" >&2
      exit 2
    fi
  done
  IFS="$old_ifs"
fi

if [[ "$PROJECT" -eq 1 ]]; then
  PROJECT_BASE="$(pwd -P)"
  if [[ "$PROJECT_BASE" == "/" ]]; then
    echo "Refusing --project install from filesystem root" >&2
    exit 2
  fi
  if ! zstack_is_manifest_safe_path "$PROJECT_BASE"; then
    echo "Project path cannot contain '|' or control characters because setup records it in the install manifest." >&2
    exit 2
  fi
fi

if ! zstack_is_manifest_safe_path "$ROOT"; then
  echo "Repository path cannot contain '|' or control characters because setup records it in the install manifest." >&2
  exit 2
fi

"$ROOT/scripts/doctor.sh" --source-only

(umask 077; mkdir -p "$STATE_DIR")
chmod 700 "$STATE_DIR"
OPERATION_LOCK="$STATE_DIR/operations.lock"
zstack_acquire_pid_lock "$OPERATION_LOCK" "zstack setup/unlink" || exit 1

cleanup_setup() {
  zstack_cleanup_identity_temp_files || true
  [[ -n "${OPERATION_LOCK:-}" ]] && zstack_release_pid_lock "$OPERATION_LOCK"
}
trap cleanup_setup EXIT

# Source validation can be slow enough for local state to change before the
# mutation lock is acquired, so re-check the exact bytes under the lock.
zstack_require_safe_install_state "$STATE_DIR"

manifest_source_is_unchanged() {
  if [[ "$MANIFEST_SOURCE_PRESENT" -eq 0 ]]; then
    [[ ! -e "$LINK_MANIFEST" && ! -L "$LINK_MANIFEST" ]]
    return
  fi
  zstack_regular_file_snapshot_is_unchanged \
    "$LINK_MANIFEST" "$MANIFEST_SOURCE_IDENTITY" "$MANIFEST_SOURCE_TMP"
}

if [[ -f "$LINK_MANIFEST" ]]; then
  MANIFEST_SOURCE_PRESENT=1
  if ! zstack_capture_regular_file_snapshot \
    "$LINK_MANIFEST" MANIFEST_SOURCE_TMP MANIFEST_SOURCE_IDENTITY \
    "$STATE_DIR/links.source.XXXXXX"; then
    echo "Install manifest changed while setup input was snapshotted; no links were changed." >&2
    exit 1
  fi
fi

[[ ! -L "$CATALOG" && -f "$CATALOG" ]] || {
  echo "Catalog source must be a regular file; no links were changed." >&2
  exit 1
}
if ! zstack_capture_regular_file_snapshot \
  "$CATALOG" CATALOG_SOURCE_TMP CATALOG_SOURCE_IDENTITY \
  "$STATE_DIR/catalog.source.XXXXXX"; then
  echo "Catalog source changed while it was snapshotted; no links were changed." >&2
  exit 1
fi

zstack_make_identity_temp_file LINK_RECORD_TMP "$STATE_DIR/links.pending.XXXXXX"
zstack_make_identity_temp_file SCOPE_ROOTS_TMP "$STATE_DIR/scopes.pending.XXXXXX"
zstack_make_identity_temp_file CATALOG_ENTRIES_TMP "$STATE_DIR/catalog.pending.XXXXXX"
if ! zstack_catalog_entries "$CATALOG_SOURCE_TMP" > "$CATALOG_ENTRIES_TMP"; then
  echo "Could not snapshot catalog entries; no links were changed." >&2
  exit 1
fi
zstack_make_identity_temp_file HOST_PROFILES_TMP "$STATE_DIR/hosts.pending.XXXXXX"
for host_file in "$HOSTS_DIR"/*.yaml; do
  host_source_name="${host_file##*/}"
  host_source_name="${host_source_name%.yaml}"
  [[ -f "$host_file" ]] || continue
  if [[ -L "$host_file" || ! "$host_source_name" =~ ^[a-z][a-z0-9-]*$ ]]; then
    echo "Could not snapshot unsafe host profile source; no links were changed." >&2
    exit 1
  fi
  if ! zstack_capture_regular_file_snapshot \
    "$host_file" host_source_snapshot host_source_identity \
    "$STATE_DIR/host.$host_source_name.source.XXXXXX"; then
    echo "Host profile source changed while it was snapshotted; no links were changed." >&2
    exit 1
  fi
  HOST_SOURCE_PATHS+=("$host_file")
  HOST_SOURCE_IDENTITIES+=("$host_source_identity")
  HOST_SOURCE_SNAPSHOTS+=("$host_source_snapshot")
  HOST_SOURCE_COUNT=$((HOST_SOURCE_COUNT + 1))
  if ! profile="$(zstack_host_profile "$host_source_snapshot")"; then
    echo "Could not snapshot host profiles; no links were changed." >&2
    exit 1
  fi
  printf '%s\n' "$profile" >> "$HOST_PROFILES_TMP"
done

SNAPSHOT_HOST_NAMES=","
validate_host_profile_snapshot() {
  local hname display_name skills_root link_mode enabled description_max required_name required_description
  local profile_count=0
  local old_ifs requested_host

  while IFS='|' read -r hname display_name skills_root link_mode enabled description_max required_name required_description; do
    profile_count=$((profile_count + 1))
    [[ "$hname" =~ ^[a-z][a-z0-9-]*$ ]] || return 1
    [[ -n "${display_name//[[:space:]]/}" ]] || return 1
    zstack_is_safe_home_relative_path "$skills_root" || return 1
    [[ "$link_mode" == "symlink" ]] || return 1
    [[ "$enabled" == "true" || "$enabled" == "false" ]] || return 1
    [[ "$required_name" == "1" && "$required_description" == "1" ]] || return 1
    if [[ -n "$description_max" && ! "$description_max" =~ ^[1-9][0-9]*$ ]]; then
      return 1
    fi
    [[ "$SNAPSHOT_HOST_NAMES" != *",$hname,"* ]] || return 1
    SNAPSHOT_HOST_NAMES="${SNAPSHOT_HOST_NAMES}${hname},"
  done < "$HOST_PROFILES_TMP"
  [[ "$profile_count" -gt 0 ]] || return 1

  if [[ -n "$HOST_FILTER" ]]; then
    old_ifs="$IFS"
    IFS=','
    for requested_host in $HOST_FILTER; do
      [[ "$SNAPSHOT_HOST_NAMES" == *",$requested_host,"* ]] || {
        IFS="$old_ifs"
        return 1
      }
    done
    IFS="$old_ifs"
  fi
}

validate_catalog_snapshot() {
  local id path status hosts host
  local entry_count=0
  local active_count=0
  local seen_ids=","
  local old_ifs

  [[ -d "$ROOT/skills" && ! -L "$ROOT/skills" ]] || return 1
  while IFS='|' read -r id path status hosts _ _ _; do
    entry_count=$((entry_count + 1))
    [[ "$id" =~ ^z-[a-z0-9]([a-z0-9-]{0,60}[a-z0-9])?$ ]] || return 1
    [[ "$seen_ids" != *",$id,"* ]] || return 1
    seen_ids="${seen_ids}${id},"
    [[ "$path" == "skills/$id" ]] || return 1
    [[ -d "$ROOT/$path" && ! -L "$ROOT/$path" ]] || return 1
    case "$status" in
      active) active_count=$((active_count + 1)) ;;
      draft|deprecated) ;;
      *) return 1 ;;
    esac
    [[ "$hosts" =~ ^[a-z][a-z0-9-]*(,[a-z][a-z0-9-]*)*$ ]] || return 1
    old_ifs="$IFS"
    IFS=','
    for host in $hosts; do
      if [[ "$SNAPSHOT_HOST_NAMES" != *",$host,"* ]]; then
        IFS="$old_ifs"
        return 1
      fi
    done
    IFS="$old_ifs"
  done < "$CATALOG_ENTRIES_TMP"
  [[ "$entry_count" -gt 0 && "$active_count" -gt 0 ]]
}

if ! validate_host_profile_snapshot || ! validate_catalog_snapshot; then
  echo "Source snapshots failed mutation safety checks; no links were changed." >&2
  exit 1
fi

if ! zstack_regular_file_snapshot_is_unchanged \
  "$CATALOG" "$CATALOG_SOURCE_IDENTITY" "$CATALOG_SOURCE_TMP"; then
  echo "Catalog source changed after snapshot validation; no links were changed." >&2
  exit 1
fi
for ((host_source_index = 0; host_source_index < HOST_SOURCE_COUNT; host_source_index++)); do
  if ! zstack_regular_file_snapshot_is_unchanged \
    "${HOST_SOURCE_PATHS[$host_source_index]}" \
    "${HOST_SOURCE_IDENTITIES[$host_source_index]}" \
    "${HOST_SOURCE_SNAPSHOTS[$host_source_index]}"; then
    echo "Host profile source changed after snapshot validation; no links were changed." >&2
    exit 1
  fi
done

record_link() {
  local dest="$1"
  printf '%s|%s\n' "$ROOT" "$dest" >> "$LINK_RECORD_TMP"
  RECORDED=$((RECORDED + 1))
}

record_scope() {
  local scope_root="$1"
  local grep_status=0

  grep -Fxq "$scope_root" "$SCOPE_ROOTS_TMP" 2>/dev/null || grep_status=$?
  case "$grep_status" in
    0) return 0 ;;
    1) printf '%s\n' "$scope_root" >> "$SCOPE_ROOTS_TMP" ;;
    *)
      echo "Could not inspect the setup scope snapshot; refusing to continue." >&2
      return "$grep_status"
      ;;
  esac
}

link_is_desired() {
  local link="$1"
  local grep_status=0

  grep -Fxq "$ROOT|$link" "$LINK_RECORD_TMP" || grep_status=$?
  case "$grep_status" in
    0) return 0 ;;
    1) return 1 ;;
    *)
      echo "Could not inspect the desired-link snapshot; refusing to reconcile links." >&2
      exit 1
      ;;
  esac
}

link_is_in_scope() {
  local link="$1"
  local parent
  local grep_status=0
  parent="$(dirname "$link")"
  grep -Fxq "$parent" "$SCOPE_ROOTS_TMP" || grep_status=$?
  case "$grep_status" in
    0) return 0 ;;
    1) return 1 ;;
    *)
      echo "Could not inspect the setup scope snapshot; refusing to reconcile links." >&2
      exit 1
      ;;
  esac
}

remove_stale_link() {
  local link="$1"
  local resolved_link
  local expected_link_identity=""
  local current_link_identity=""

  [[ -L "$link" ]] || return 0
  expected_link_identity="$(zstack_file_identity "$link")" || return 1
  resolved_link="$(zstack_resolve_link_target "$link")" || return 0
  current_link_identity="$(zstack_file_identity "$link" 2>/dev/null || true)"
  if [[ ! -L "$link" || "$current_link_identity" != "$expected_link_identity" ]]; then
    echo "  fail stale link changed while it was inspected: $link" >&2
    return 1
  fi
  case "$resolved_link" in
    "$ROOT/skills"/*)
      if ! zstack_remove_symlink_if_identity "$link" "$expected_link_identity"; then
        echo "  fail stale link changed before safe removal: $link" >&2
        return 1
      fi
      echo "  old $link"
      REMOVED_STALE=$((REMOVED_STALE + 1))
      ;;
  esac
}

link_skill() {
  local src="$1"
  local dest_root="$2"
  local name dest current current_display backup backup_entry
  name="$(basename "$src")"
  dest="$dest_root/$name"

  mkdir -p "$dest_root"

  if [[ -L "$dest" ]]; then
    if [[ -d "$dest" ]] && [[ "$(cd "$dest" && pwd -P)" == "$(cd "$src" && pwd -P)" ]]; then
      echo "  ok  $dest"
      record_link "$dest"
      return 0
    fi
    current="$(readlink "$dest")"
    current_display="$(zstack_quote_for_log "$current")"
    if [[ "$FORCE" -ne 1 ]]; then
      echo "  skip $dest (symlink points elsewhere: $current_display; use --force to back it up)" >&2
      SKIPPED=$((SKIPPED + 1))
      return 0
    fi
  elif [[ -e "$dest" ]]; then
    if [[ "$FORCE" -ne 1 ]]; then
      echo "  skip $dest (exists and is not managed by zstack; use --force to back it up)" >&2
      SKIPPED=$((SKIPPED + 1))
      return 0
    fi
  else
    if ln -s "$src" "$dest"; then
      echo "  new $dest -> $src"
      record_link "$dest"
    else
      echo "  fail could not create $dest" >&2
      FAILURES=$((FAILURES + 1))
    fi
    return 0
  fi

  if ! backup="$(mktemp -d "$dest.zstack-backup-$BACKUP_STAMP.XXXXXX")"; then
    echo "  fail could not reserve a collision-free backup for $dest" >&2
    FAILURES=$((FAILURES + 1))
    return 0
  fi
  backup_entry="$backup/original"
  if ! mv "$dest" "$backup_entry"; then
    echo "  fail could not back up $dest" >&2
    rmdir "$backup" 2>/dev/null || true
    FAILURES=$((FAILURES + 1))
    return 0
  fi
  if ln -s "$src" "$dest"; then
    echo "  bak $backup_entry"
    echo "  new $dest -> $src"
    record_link "$dest"
    return 0
  fi

  echo "  fail could not create $dest after backup" >&2
  if [[ ! -e "$dest" && ! -L "$dest" ]] && mv "$backup_entry" "$dest"; then
    rmdir "$backup" 2>/dev/null || true
    echo "  restored $dest" >&2
  else
    echo "  warning: original remains at $backup_entry; automatic restore failed" >&2
  fi
  FAILURES=$((FAILURES + 1))
}

echo "zstack setup"
echo "  ZSTACK_ROOT=$ROOT"

echo "Skills (active):"
skill_count=0
while IFS='|' read -r id _ status _ _ _ _; do
  [[ "$status" == "active" ]] || continue
  echo " · $id"
  skill_count=$((skill_count + 1))
done < "$CATALOG_ENTRIES_TMP"
if [[ "$skill_count" -eq 0 ]]; then
  echo "No active skills in catalog.yaml" >&2
  exit 1
fi

echo "Hosts:"
while IFS='|' read -r hname _ skills_root _ enabled _ _ _; do
  explicitly_selected=0
  if [[ -n "$HOST_FILTER" ]]; then
    [[ ",$HOST_FILTER," == *",$hname,"* ]] || continue
    explicitly_selected=1
  fi
  if [[ "$enabled" == "false" && "$explicitly_selected" -eq 0 ]]; then
    echo " · $hname (disabled)"
    continue
  fi
  hroot="$(zstack_expand_path "$skills_root")"
  record_scope "$hroot"
  if [[ "$enabled" == "false" ]]; then
    echo " · $hname → $hroot (explicit opt-in)"
  else
    echo " · $hname → $hroot"
  fi
  while IFS='|' read -r _ path status hosts _ _ _; do
    [[ "$status" == "active" ]] || continue
    [[ ",$hosts," == *",$hname,"* ]] || continue
    link_skill "$ROOT/$path" "$hroot"
  done < "$CATALOG_ENTRIES_TMP"
done < "$HOST_PROFILES_TMP"

if [[ "$PROJECT" -eq 1 ]]; then
  project_root="$PROJECT_BASE/.agents/skills"
  record_scope "$project_root"
  echo "Project: $project_root"
  while IFS='|' read -r _ path status hosts _ _ _; do
    [[ "$status" == "active" ]] || continue
    [[ ",$hosts," == *",agents,"* ]] || continue
    link_skill "$ROOT/$path" "$project_root"
  done < "$CATALOG_ENTRIES_TMP"
fi

zstack_make_identity_temp_file MANIFEST_NEXT_TMP "$STATE_DIR/links.next.XXXXXX"
if [[ "$MANIFEST_SOURCE_PRESENT" -eq 1 ]]; then
  manifest_line_number=0
  while IFS= read -r manifest_line || [[ -n "$manifest_line" ]]; do
    manifest_line_number=$((manifest_line_number + 1))
    [[ -n "$manifest_line" ]] || continue
    if ! zstack_is_manifest_line_safe "$manifest_line"; then
      echo "  warning: preserving unsafe install manifest line $manifest_line_number" >&2
      printf '%s\n' "$manifest_line" >> "$MANIFEST_NEXT_TMP"
      continue
    fi
    recorded_root="${manifest_line%%|*}"
    recorded_link="${manifest_line#*|}"
    if [[ "$recorded_root" != "$ROOT" ]] && link_is_desired "$recorded_link"; then
      RETIRED_OWNERS=$((RETIRED_OWNERS + 1))
      continue
    fi
    if [[ "$recorded_root" == "$ROOT" ]] &&
       ! link_is_desired "$recorded_link" &&
       link_is_in_scope "$recorded_link"; then
      remove_stale_link "$recorded_link"
      continue
    fi
    printf '%s\n' "$manifest_line" >> "$MANIFEST_NEXT_TMP"
  done < "$MANIFEST_SOURCE_TMP"
fi

while IFS= read -r scope_root; do
  [[ -d "$scope_root" ]] || continue
  for candidate in "$scope_root"/*; do
    [[ -L "$candidate" ]] || continue
    [[ "$candidate" == *.zstack-backup-* ]] && continue
    link_is_desired "$candidate" && continue
    remove_stale_link "$candidate"
  done
done < "$SCOPE_ROOTS_TMP"

if ! manifest_source_is_unchanged; then
  echo "Install manifest changed while setup actions were prepared; refusing to publish stale state." >&2
  exit 1
fi

zstack_make_identity_temp_file MANIFEST_MERGED_TMP "$STATE_DIR/links.merged.XXXXXX"
{
  cat "$MANIFEST_NEXT_TMP"
  cat "$LINK_RECORD_TMP"
} | awk 'NF && !seen[$0]++' > "$MANIFEST_MERGED_TMP"
MANIFEST_NEXT_TMP="$MANIFEST_MERGED_TMP"
MANIFEST_MERGED_TMP=""

if [[ -s "$MANIFEST_NEXT_TMP" ]]; then
  if ! zstack_capture_regular_file_snapshot \
    "$MANIFEST_NEXT_TMP" MANIFEST_EXPECTED_TMP MANIFEST_PUBLISH_IDENTITY \
    "$STATE_DIR/links.expected.XXXXXX"; then
    echo "Install manifest candidate changed while it was snapshotted." >&2
    exit 1
  fi
  mv "$MANIFEST_NEXT_TMP" "$LINK_MANIFEST"
  if ! zstack_regular_file_snapshot_is_unchanged \
    "$LINK_MANIFEST" "$MANIFEST_PUBLISH_IDENTITY" "$MANIFEST_EXPECTED_TMP"; then
    echo "Install manifest changed during publication; refusing to write the root record." >&2
    exit 1
  fi
else
  if [[ "$MANIFEST_SOURCE_PRESENT" -eq 1 ]]; then
    if ! manifest_source_is_unchanged ||
       ! zstack_remove_regular_file_strict_if_identity \
         "$LINK_MANIFEST" "$MANIFEST_SOURCE_IDENTITY" "$MANIFEST_SOURCE_TMP"; then
      echo "Install manifest changed before safe empty-state publication; refusing to remove it." >&2
      exit 1
    fi
  fi
  if [[ -e "$LINK_MANIFEST" || -L "$LINK_MANIFEST" ]]; then
    echo "Install manifest appeared while an empty state was published; refusing to write the root record." >&2
    exit 1
  fi
fi
MANIFEST_NEXT_TMP=""

current_manifest_count=0
recorded_state_root=""
if [[ -f "$LINK_MANIFEST" ]]; then
  while IFS= read -r manifest_line || [[ -n "$manifest_line" ]]; do
    zstack_is_manifest_line_safe "$manifest_line" || continue
    recorded_root="${manifest_line%%|*}"
    [[ "$recorded_root" == "$ROOT" ]] || continue
    current_manifest_count=$((current_manifest_count + 1))
  done < "$LINK_MANIFEST"
fi
if [[ "$current_manifest_count" -gt 0 ]]; then
  zstack_make_identity_temp_file ROOT_NEXT_TMP "$STATE_DIR/root.next.XXXXXX"
  printf '%s\n' "$ROOT" > "$ROOT_NEXT_TMP"
  if ! zstack_capture_regular_file_snapshot \
    "$ROOT_NEXT_TMP" ROOT_EXPECTED_TMP ROOT_PUBLISH_IDENTITY \
    "$STATE_DIR/root.expected.XXXXXX"; then
    echo "Root record candidate changed while it was snapshotted." >&2
    exit 1
  fi
  mv "$ROOT_NEXT_TMP" "$STATE_DIR/root"
  if ! zstack_regular_file_snapshot_is_unchanged \
    "$STATE_DIR/root" "$ROOT_PUBLISH_IDENTITY" "$ROOT_EXPECTED_TMP"; then
    echo "Root record changed during publication; refusing to report setup success." >&2
    exit 1
  fi
  ROOT_NEXT_TMP=""
elif [[ -f "$STATE_DIR/root" ]]; then
  if ! zstack_capture_regular_file_snapshot \
    "$STATE_DIR/root" ROOT_SOURCE_TMP ROOT_SOURCE_IDENTITY \
    "$STATE_DIR/root.source.XXXXXX"; then
    echo "Root record changed while cleanup input was snapshotted; refusing to remove it." >&2
    exit 1
  fi
  if recorded_state_root="$(zstack_read_root_record "$ROOT_SOURCE_TMP" 2>/dev/null)" &&
     [[ "$recorded_state_root" == "$ROOT" ]]; then
    if ! zstack_regular_file_snapshot_is_unchanged \
         "$STATE_DIR/root" "$ROOT_SOURCE_IDENTITY" "$ROOT_SOURCE_TMP" ||
       ! zstack_remove_regular_file_strict_if_identity \
         "$STATE_DIR/root" "$ROOT_SOURCE_IDENTITY" "$ROOT_SOURCE_TMP"; then
      echo "Root record changed before safe cleanup; refusing to report setup success." >&2
      exit 1
    fi
  fi
fi

if [[ "$RECORDED" -eq 0 && "$REMOVED_STALE" -eq 0 ]]; then
  echo "No matching links were installed or already managed." >&2
  FAILURES=$((FAILURES + 1))
fi

zstack_cleanup_identity_temp_files
LINK_RECORD_TMP=""
SCOPE_ROOTS_TMP=""
CATALOG_ENTRIES_TMP=""
HOST_PROFILES_TMP=""
zstack_release_pid_lock "$OPERATION_LOCK"
OPERATION_LOCK=""
trap - EXIT

echo "Summary: recorded=$RECORDED removed_stale=$REMOVED_STALE retired_owners=$RETIRED_OWNERS skipped=$SKIPPED failures=$FAILURES"
if [[ "$SKIPPED" -gt 0 || "$FAILURES" -gt 0 ]]; then
  echo "Setup incomplete; resolve the reported paths and run again." >&2
  exit 1
fi

echo "Done. Run ./scripts/doctor.sh to validate installed links."
