#!/usr/bin/env bash
# Remove zstack-managed symlinks and this repo's matching root record.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
REMOVED=0
STATE_DIR="$HOME/.zstack"
LINK_MANIFEST="$STATE_DIR/links"
OPERATION_LOCK=""
MANIFEST_NEXT_TMP=""

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
zstack_require_safe_state_dir "$STATE_DIR"
zstack_require_safe_state_file "$LINK_MANIFEST" "zstack install manifest"
zstack_require_safe_state_file "$STATE_DIR/root" "zstack root record"

mkdir -p "$STATE_DIR"
OPERATION_LOCK="$STATE_DIR/operations.lock"
zstack_acquire_pid_lock "$OPERATION_LOCK" "zstack setup/unlink" || exit 1

cleanup_unlink() {
  rm -f "${MANIFEST_NEXT_TMP:-}"
  [[ -n "${OPERATION_LOCK:-}" ]] && zstack_release_pid_lock "$OPERATION_LOCK"
}
trap cleanup_unlink EXIT

remove_managed_link() {
  local link="$1"
  local resolved_target

  [[ -L "$link" ]] || return 0
  resolved_target="$(zstack_resolve_link_target "$link")" || return 0

  case "$resolved_target" in
    "$ROOT/skills"/*)
      rm -f "$link"
      echo "removed $link"
      REMOVED=$((REMOVED + 1))
      ;;
  esac
}

if [[ -f "$LINK_MANIFEST" ]]; then
  MANIFEST_NEXT_TMP="$(mktemp "$STATE_DIR/links.next.XXXXXX")"
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
  done < "$LINK_MANIFEST"
  if [[ -s "$MANIFEST_NEXT_TMP" ]]; then
    mv "$MANIFEST_NEXT_TMP" "$LINK_MANIFEST"
  else
    rm -f "$MANIFEST_NEXT_TMP" "$LINK_MANIFEST"
  fi
  MANIFEST_NEXT_TMP=""
fi

shopt -s nullglob
for host_file in "$ROOT"/hosts/*.yaml; do
  [[ -f "$host_file" ]] || continue
  profile="$(zstack_host_profile "$host_file")"
  IFS='|' read -r _ _ skills_root _ <<< "$profile"
  if ! zstack_is_safe_home_relative_path "$skills_root"; then
    echo "skip unsafe host root in ${host_file##*/}: $skills_root" >&2
    continue
  fi
  hroot="$(zstack_expand_path "$skills_root")"
  [[ -d "$hroot" ]] || continue

  for link in "$hroot"/*; do
    [[ "$link" == *.zstack-backup-* ]] && continue
    remove_managed_link "$link"
  done
done

ROOT_RECORD="$STATE_DIR/root"
if [[ -f "$ROOT_RECORD" ]] && [[ "$(cat "$ROOT_RECORD")" == "$ROOT" ]]; then
  rm -f "$ROOT_RECORD"
  echo "removed $ROOT_RECORD"
fi
zstack_release_pid_lock "$OPERATION_LOCK"
OPERATION_LOCK=""
trap - EXIT
rmdir "$STATE_DIR" 2>/dev/null || true

echo "Removed $REMOVED zstack symlink(s). Backups and non-symlink paths were preserved."
