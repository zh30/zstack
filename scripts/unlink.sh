#!/usr/bin/env bash
# Remove zstack-managed symlinks and this repo's matching root record.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
REMOVED=0
STATE_DIR="$HOME/.zstack"
LINK_MANIFEST="$STATE_DIR/links"
OPERATION_LOCK=""
MANIFEST_SOURCE_TMP=""
MANIFEST_SOURCE_IDENTITY=""
MANIFEST_NEXT_TMP=""
MANIFEST_EXPECTED_TMP=""
MANIFEST_PUBLISH_IDENTITY=""
HOST_PROFILES_TMP=""
HOST_SOURCE_PATHS=()
HOST_SOURCE_IDENTITIES=()
HOST_SOURCE_SNAPSHOTS=()
HOST_SOURCE_COUNT=0
host_source_name=""
host_source_identity=""
host_source_snapshot=""
ROOT_SOURCE_TMP=""
ROOT_SOURCE_IDENTITY=""

# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  echo "Usage: ./scripts/unlink.sh"
  exit 0
fi
if [[ $# -gt 0 ]]; then
  echo "Unknown option: $1" >&2
  echo "Usage: ./scripts/unlink.sh" >&2
  exit 2
fi

zstack_require_safe_home
zstack_require_safe_install_state "$STATE_DIR"

(umask 077; mkdir -p "$STATE_DIR")
chmod 700 "$STATE_DIR"
OPERATION_LOCK="$STATE_DIR/operations.lock"
zstack_acquire_pid_lock "$OPERATION_LOCK" "zstack setup/unlink" || exit 1

cleanup_unlink() {
  zstack_cleanup_identity_temp_files || true
  [[ -n "${OPERATION_LOCK:-}" ]] && zstack_release_pid_lock "$OPERATION_LOCK"
}
trap cleanup_unlink EXIT

# Re-check after locking so unlink never consumes state swapped after preflight.
zstack_require_safe_install_state "$STATE_DIR"

# Parse every host before removing anything. A late parser failure must not
# leave manifest entries removed while host-root cleanup is only half complete.
zstack_make_identity_temp_file HOST_PROFILES_TMP "$STATE_DIR/hosts.pending.XXXXXX"
for host_file in "$ROOT"/hosts/*.yaml; do
  [[ -f "$host_file" ]] || continue
  host_source_name="${host_file##*/}"
  host_source_name="${host_source_name%.yaml}"
  if [[ -L "$host_file" || ! "$host_source_name" =~ ^[a-z][a-z0-9-]*$ ]]; then
    echo "Could not snapshot unsafe host profile source; no links were removed." >&2
    exit 1
  fi
  if ! zstack_capture_regular_file_snapshot \
    "$host_file" host_source_snapshot host_source_identity \
    "$STATE_DIR/host.$host_source_name.source.XXXXXX"; then
    echo "Host profile source changed while it was snapshotted; no links were removed." >&2
    exit 1
  fi
  HOST_SOURCE_PATHS+=("$host_file")
  HOST_SOURCE_IDENTITIES+=("$host_source_identity")
  HOST_SOURCE_SNAPSHOTS+=("$host_source_snapshot")
  HOST_SOURCE_COUNT=$((HOST_SOURCE_COUNT + 1))
  if ! profile="$(zstack_host_profile "$host_source_snapshot")"; then
    echo "Could not snapshot host profiles; no links were removed." >&2
    exit 1
  fi
  printf '%s\n' "$profile" >> "$HOST_PROFILES_TMP"
done
for ((host_source_index = 0; host_source_index < HOST_SOURCE_COUNT; host_source_index++)); do
  if ! zstack_regular_file_snapshot_is_unchanged \
    "${HOST_SOURCE_PATHS[$host_source_index]}" \
    "${HOST_SOURCE_IDENTITIES[$host_source_index]}" \
    "${HOST_SOURCE_SNAPSHOTS[$host_source_index]}"; then
    echo "Host profile source changed after snapshot validation; no links were removed." >&2
    exit 1
  fi
done

remove_managed_link() {
  local link="$1"
  local resolved_target
  local expected_link_identity=""
  local current_link_identity=""

  [[ -L "$link" ]] || return 0
  expected_link_identity="$(zstack_file_identity "$link")" || return 1
  resolved_target="$(zstack_resolve_link_target "$link")" || return 0
  current_link_identity="$(zstack_file_identity "$link" 2>/dev/null || true)"
  if [[ ! -L "$link" || "$current_link_identity" != "$expected_link_identity" ]]; then
    echo "managed link changed while it was inspected: $link" >&2
    return 1
  fi

  case "$resolved_target" in
    "$ROOT/skills"/*)
      if ! zstack_remove_symlink_if_identity "$link" "$expected_link_identity"; then
        echo "managed link changed before safe removal: $link" >&2
        return 1
      fi
      echo "removed $link"
      REMOVED=$((REMOVED + 1))
      ;;
  esac
}

if [[ -f "$LINK_MANIFEST" ]]; then
  if ! zstack_capture_regular_file_snapshot \
    "$LINK_MANIFEST" MANIFEST_SOURCE_TMP MANIFEST_SOURCE_IDENTITY \
    "$STATE_DIR/links.source.XXXXXX"; then
    echo "Install manifest changed while unlink input was snapshotted; no links were removed." >&2
    exit 1
  fi
  zstack_make_identity_temp_file MANIFEST_NEXT_TMP "$STATE_DIR/links.next.XXXXXX"
  manifest_line_number=0
  while IFS= read -r manifest_line || [[ -n "$manifest_line" ]]; do
    manifest_line_number=$((manifest_line_number + 1))
    [[ -n "$manifest_line" ]] || continue
    if ! zstack_is_manifest_line_safe "$manifest_line"; then
      echo "warning: preserving unsafe install manifest line $manifest_line_number" >&2
      printf '%s\n' "$manifest_line" >> "$MANIFEST_NEXT_TMP"
      continue
    fi
    recorded_root="${manifest_line%%|*}"
    recorded_link="${manifest_line#*|}"
    if [[ "$recorded_root" == "$ROOT" ]]; then
      remove_managed_link "$recorded_link"
    else
      printf '%s\n' "$manifest_line" >> "$MANIFEST_NEXT_TMP"
    fi
  done < "$MANIFEST_SOURCE_TMP"
  if ! zstack_regular_file_snapshot_is_unchanged \
    "$LINK_MANIFEST" "$MANIFEST_SOURCE_IDENTITY" "$MANIFEST_SOURCE_TMP"; then
    echo "Install manifest changed while unlink actions were prepared; refusing to publish stale state." >&2
    exit 1
  fi
  if [[ -s "$MANIFEST_NEXT_TMP" ]]; then
    if ! zstack_capture_regular_file_snapshot \
      "$MANIFEST_NEXT_TMP" MANIFEST_EXPECTED_TMP MANIFEST_PUBLISH_IDENTITY \
      "$STATE_DIR/links.expected.XXXXXX"; then
      echo "Unlink manifest candidate changed while it was snapshotted." >&2
      exit 1
    fi
    mv "$MANIFEST_NEXT_TMP" "$LINK_MANIFEST"
    if ! zstack_regular_file_snapshot_is_unchanged \
      "$LINK_MANIFEST" "$MANIFEST_PUBLISH_IDENTITY" "$MANIFEST_EXPECTED_TMP"; then
      echo "Install manifest changed during unlink publication; refusing to report success." >&2
      exit 1
    fi
  else
    if ! zstack_regular_file_snapshot_is_unchanged \
         "$LINK_MANIFEST" "$MANIFEST_SOURCE_IDENTITY" "$MANIFEST_SOURCE_TMP" ||
       ! zstack_remove_regular_file_strict_if_identity \
         "$LINK_MANIFEST" "$MANIFEST_SOURCE_IDENTITY" "$MANIFEST_SOURCE_TMP"; then
      echo "Install manifest changed before safe empty unlink publication; refusing to remove it." >&2
      exit 1
    fi
    if [[ -e "$LINK_MANIFEST" || -L "$LINK_MANIFEST" ]]; then
      echo "Install manifest appeared while empty unlink state was published; refusing to report success." >&2
      exit 1
    fi
  fi
  MANIFEST_NEXT_TMP=""
fi

while IFS='|' read -r _ _ skills_root _ _ _ _ _; do
  if ! zstack_is_safe_home_relative_path "$skills_root"; then
    echo "skip unsafe host root: $skills_root" >&2
    continue
  fi
  hroot="$(zstack_expand_path "$skills_root")"
  [[ -d "$hroot" ]] || continue

  for link in "$hroot"/*; do
    [[ "$link" == *.zstack-backup-* ]] && continue
    remove_managed_link "$link"
  done
done < "$HOST_PROFILES_TMP"

ROOT_RECORD="$STATE_DIR/root"
recorded_state_root=""
if [[ -f "$ROOT_RECORD" ]]; then
  if ! zstack_capture_regular_file_snapshot \
    "$ROOT_RECORD" ROOT_SOURCE_TMP ROOT_SOURCE_IDENTITY \
    "$STATE_DIR/root.source.XXXXXX"; then
    echo "Root record changed while unlink cleanup input was snapshotted; refusing to remove it." >&2
    exit 1
  fi
  if recorded_state_root="$(zstack_read_root_record "$ROOT_SOURCE_TMP" 2>/dev/null)" &&
     [[ "$recorded_state_root" == "$ROOT" ]]; then
    if ! zstack_regular_file_snapshot_is_unchanged \
         "$ROOT_RECORD" "$ROOT_SOURCE_IDENTITY" "$ROOT_SOURCE_TMP" ||
       ! zstack_remove_regular_file_strict_if_identity \
         "$ROOT_RECORD" "$ROOT_SOURCE_IDENTITY" "$ROOT_SOURCE_TMP"; then
      echo "Root record changed before safe unlink cleanup; refusing to report success." >&2
      exit 1
    fi
    echo "removed $ROOT_RECORD"
  fi
fi
zstack_cleanup_identity_temp_files
HOST_PROFILES_TMP=""
zstack_release_pid_lock "$OPERATION_LOCK"
OPERATION_LOCK=""
trap - EXIT
rmdir "$STATE_DIR" 2>/dev/null || true

echo "Removed $REMOVED zstack symlink(s). Backups and non-symlink paths were preserved."
