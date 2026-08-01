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
MANIFEST_NEXT_TMP=""
MANIFEST_MERGED_TMP=""
ROOT_NEXT_TMP=""

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
zstack_require_safe_state_dir "$STATE_DIR"
zstack_require_safe_state_file "$LINK_MANIFEST" "zstack install manifest"
zstack_require_safe_state_file "$STATE_DIR/root" "zstack root record"

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

mkdir -p "$STATE_DIR"
OPERATION_LOCK="$STATE_DIR/operations.lock"
zstack_acquire_pid_lock "$OPERATION_LOCK" "zstack setup/unlink" || exit 1

cleanup_setup() {
  rm -f \
    "${LINK_RECORD_TMP:-}" \
    "${SCOPE_ROOTS_TMP:-}" \
    "${MANIFEST_NEXT_TMP:-}" \
    "${MANIFEST_MERGED_TMP:-}" \
    "${ROOT_NEXT_TMP:-}"
  [[ -n "${OPERATION_LOCK:-}" ]] && zstack_release_pid_lock "$OPERATION_LOCK"
}
trap cleanup_setup EXIT

LINK_RECORD_TMP="$(mktemp "$STATE_DIR/links.pending.XXXXXX")"
SCOPE_ROOTS_TMP="$(mktemp "$STATE_DIR/scopes.pending.XXXXXX")"

record_link() {
  local dest="$1"
  printf '%s|%s\n' "$ROOT" "$dest" >> "$LINK_RECORD_TMP"
  RECORDED=$((RECORDED + 1))
}

record_scope() {
  local scope_root="$1"
  grep -Fxq "$scope_root" "$SCOPE_ROOTS_TMP" 2>/dev/null || printf '%s\n' "$scope_root" >> "$SCOPE_ROOTS_TMP"
}

link_is_desired() {
  local link="$1"
  grep -Fxq "$ROOT|$link" "$LINK_RECORD_TMP"
}

link_is_in_scope() {
  local link="$1"
  local parent
  parent="$(dirname "$link")"
  grep -Fxq "$parent" "$SCOPE_ROOTS_TMP"
}

remove_stale_link() {
  local link="$1"
  local resolved_link

  [[ -L "$link" ]] || return 0
  resolved_link="$(zstack_resolve_link_target "$link")" || return 0
  case "$resolved_link" in
    "$ROOT/skills"/*)
      rm -f "$link"
      echo "  old $link"
      REMOVED_STALE=$((REMOVED_STALE + 1))
      ;;
  esac
}

link_skill() {
  local src="$1"
  local dest_root="$2"
  local name dest current current_display backup
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

  backup="$dest.zstack-backup-$BACKUP_STAMP"
  if ! mv "$dest" "$backup"; then
    echo "  fail could not back up $dest" >&2
    FAILURES=$((FAILURES + 1))
    return 0
  fi
  if ln -s "$src" "$dest"; then
    echo "  bak $backup"
    echo "  new $dest -> $src"
    record_link "$dest"
    return 0
  fi

  echo "  fail could not create $dest after backup" >&2
  if [[ ! -e "$dest" && ! -L "$dest" ]] && mv "$backup" "$dest"; then
    echo "  restored $dest" >&2
  else
    echo "  warning: original remains at $backup; automatic restore failed" >&2
  fi
  FAILURES=$((FAILURES + 1))
}

echo "zstack setup"
echo "  ZSTACK_ROOT=$ROOT"

echo "Skills (active):"
skill_count=0
while IFS= read -r skill_dir; do
  [[ -n "$skill_dir" ]] || continue
  echo " · $(basename "$skill_dir")"
  skill_count=$((skill_count + 1))
done < <(zstack_active_skill_dirs "$CATALOG" "$ROOT")
if [[ "$skill_count" -eq 0 ]]; then
  echo "No active skills in catalog.yaml" >&2
  exit 1
fi

echo "Hosts:"
for host_file in "$HOSTS_DIR"/*.yaml; do
  [[ -f "$host_file" ]] || continue
  profile="$(zstack_host_profile "$host_file")"
  IFS='|' read -r hname _ skills_root _ enabled _ <<< "$profile"
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
  while IFS= read -r skill_dir; do
    [[ -n "$skill_dir" ]] || continue
    link_skill "$skill_dir" "$hroot"
  done < <(zstack_active_skill_dirs "$CATALOG" "$ROOT" "$hname")
done

if [[ "$PROJECT" -eq 1 ]]; then
  project_root="$PROJECT_BASE/.agents/skills"
  record_scope "$project_root"
  echo "Project: $project_root"
  while IFS= read -r skill_dir; do
    [[ -n "$skill_dir" ]] || continue
    link_skill "$skill_dir" "$project_root"
  done < <(zstack_active_skill_dirs "$CATALOG" "$ROOT" agents)
fi

MANIFEST_NEXT_TMP="$(mktemp "$STATE_DIR/links.next.XXXXXX")"
if [[ -f "$LINK_MANIFEST" ]]; then
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
  done < "$LINK_MANIFEST"
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

MANIFEST_MERGED_TMP="$MANIFEST_NEXT_TMP.merged"
{
  cat "$MANIFEST_NEXT_TMP"
  cat "$LINK_RECORD_TMP"
} | awk 'NF && !seen[$0]++' > "$MANIFEST_MERGED_TMP"
mv "$MANIFEST_MERGED_TMP" "$MANIFEST_NEXT_TMP"
MANIFEST_MERGED_TMP=""

if [[ -s "$MANIFEST_NEXT_TMP" ]]; then
  mv "$MANIFEST_NEXT_TMP" "$LINK_MANIFEST"
else
  rm -f "$MANIFEST_NEXT_TMP" "$LINK_MANIFEST"
fi
MANIFEST_NEXT_TMP=""

current_manifest_count=0
if [[ -f "$LINK_MANIFEST" ]]; then
  while IFS= read -r manifest_line || [[ -n "$manifest_line" ]]; do
    zstack_is_manifest_line_safe "$manifest_line" || continue
    recorded_root="${manifest_line%%|*}"
    [[ "$recorded_root" == "$ROOT" ]] || continue
    current_manifest_count=$((current_manifest_count + 1))
  done < "$LINK_MANIFEST"
fi
if [[ "$current_manifest_count" -gt 0 ]]; then
  ROOT_NEXT_TMP="$(mktemp "$STATE_DIR/root.next.XXXXXX")"
  printf '%s\n' "$ROOT" > "$ROOT_NEXT_TMP"
  mv "$ROOT_NEXT_TMP" "$STATE_DIR/root"
  ROOT_NEXT_TMP=""
elif [[ -f "$STATE_DIR/root" ]] && [[ "$(cat "$STATE_DIR/root")" == "$ROOT" ]]; then
  rm -f "$STATE_DIR/root"
fi

if [[ "$RECORDED" -eq 0 && "$REMOVED_STALE" -eq 0 ]]; then
  echo "No matching links were installed or already managed." >&2
  FAILURES=$((FAILURES + 1))
fi

rm -f "$LINK_RECORD_TMP" "$SCOPE_ROOTS_TMP"
LINK_RECORD_TMP=""
SCOPE_ROOTS_TMP=""
zstack_release_pid_lock "$OPERATION_LOCK"
OPERATION_LOCK=""
trap - EXIT

echo "Summary: recorded=$RECORDED removed_stale=$REMOVED_STALE retired_owners=$RETIRED_OWNERS skipped=$SKIPPED failures=$FAILURES"
if [[ "$SKIPPED" -gt 0 || "$FAILURES" -gt 0 ]]; then
  echo "Setup incomplete; resolve the reported paths and run again." >&2
  exit 1
fi

echo "Done. Run ./scripts/doctor.sh to validate installed links."
