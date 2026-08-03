#!/usr/bin/env bash
# Atomically scaffold a skill and register it as a catalog draft.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
CATALOG="$ROOT/catalog.yaml"
SKILL_TEMPLATE="$ROOT/skills/_template/SKILL.md"
QUALITY_TEMPLATE="$ROOT/skills/_template/references/quality-bar.md"

# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"

usage() {
  echo "Usage: ./scripts/new-skill.sh <skill-name> [category]"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi
if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage >&2
  exit 2
fi

NAME="$1"
CATEGORY="${2:-uncategorized}"

if [[ -z "$NAME" ]]; then
  usage >&2
  exit 1
fi

if [[ ! "$NAME" =~ ^z-[a-z0-9]([a-z0-9-]{0,60}[a-z0-9])?$ ]]; then
  echo "Invalid name '$NAME'. Must use z- prefix + kebab-case (e.g. z-my-skill), max 64 chars." >&2
  exit 1
fi

if [[ ! "$CATEGORY" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "Invalid category '$CATEGORY'. Use kebab-case." >&2
  exit 1
fi

if [[ ! -f "$CATALOG" || -L "$CATALOG" ]]; then
  echo "Missing catalog.yaml" >&2
  exit 1
fi

DEST="$ROOT/skills/$NAME"
LOCK_DIR="$ROOT/.zstack-new-skill.lock"
WORK_DIR=""
LOCK_HELD=0
MOVED_SKILL=0
CATALOG_REPLACE_STARTED=0
COMPLETED=0
SKILL_FILE_IDENTITY=""
QUALITY_FILE_IDENTITY=""
CATALOG_BEFORE_IDENTITY=""
CATALOG_NEXT_IDENTITY=""
CATALOG_ORIGINAL_SNAPSHOT=""
CATALOG_NEXT_SNAPSHOT=""
CATALOG_EXPECTED_SNAPSHOT=""
SKILL_TEMPLATE_SNAPSHOT=""
QUALITY_TEMPLATE_SNAPSHOT=""
SKILL_TEMPLATE_IDENTITY=""
QUALITY_TEMPLATE_IDENTITY=""
GENERATED_SKILL_TMP=""
GENERATED_QUALITY_TMP=""
captured_catalog_identity=""
captured_candidate_identity=""
captured_template_identity=""
GENERATED_SKILL_DIRECTORY_IDENTITY=""
published_skill_identity=""

remove_generated_skill_directory() {
  local directory="$1"
  local expected_identity="$2"
  local current_identity=""

  [[ -d "$directory" && ! -L "$directory" ]] || return 0
  current_identity="$(zstack_file_identity "$directory" 2>/dev/null || true)"
  [[ "$current_identity" == "$expected_identity" ]] || return 0
  zstack_remove_regular_file_if_identity "$directory/SKILL.md" "$SKILL_FILE_IDENTITY" || true
  zstack_remove_regular_file_if_identity \
    "$directory/references/quality-bar.md" "$QUALITY_FILE_IDENTITY" || true
  rmdir "$directory/references" 2>/dev/null || true
  rmdir "$directory" 2>/dev/null || true
}

cleanup() {
  local status=$?
  local catalog_restored=1
  local current_catalog_identity=""
  trap - EXIT HUP INT TERM
  if [[ "$status" -ne 0 && "$COMPLETED" -eq 0 ]]; then
    if [[ "$CATALOG_REPLACE_STARTED" -eq 1 ]]; then
      current_catalog_identity="$(zstack_file_identity "$CATALOG" 2>/dev/null || true)"
      if [[ "$current_catalog_identity" == "$CATALOG_NEXT_IDENTITY" ]]; then
        if [[ -z "$CATALOG_EXPECTED_SNAPSHOT" ]] ||
           ! zstack_regular_file_snapshot_is_unchanged \
             "$CATALOG" "$CATALOG_NEXT_IDENTITY" "$CATALOG_EXPECTED_SNAPSHOT"; then
          echo "Rollback warning: the published catalog inode was edited externally; preserving it and $DEST." >&2
          catalog_restored=0
        elif ! mv "$CATALOG_ORIGINAL_SNAPSHOT" "$CATALOG"; then
          echo "Rollback warning: could not restore catalog.yaml; preserving $DEST for consistency." >&2
          catalog_restored=0
        fi
      elif [[ "$current_catalog_identity" != "$CATALOG_BEFORE_IDENTITY" ]]; then
        echo "Rollback warning: catalog.yaml was replaced externally; preserving it and $DEST." >&2
        catalog_restored=0
      fi
    fi
    if [[ "$MOVED_SKILL" -eq 1 && "$catalog_restored" -eq 1 ]]; then
      remove_generated_skill_directory "$DEST" "$GENERATED_SKILL_DIRECTORY_IDENTITY"
    fi
  fi
  if [[ -n "$WORK_DIR" ]]; then
    zstack_cleanup_identity_temp_files || true
    rmdir "$WORK_DIR/$NAME/references" 2>/dev/null || true
    rmdir "$WORK_DIR/$NAME" "$WORK_DIR" 2>/dev/null || true
  fi
  if [[ "$LOCK_HELD" -eq 1 ]]; then
    zstack_release_pid_lock "$LOCK_DIR"
  fi
  exit "$status"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

zstack_acquire_pid_lock "$LOCK_DIR" "new-skill" || exit 1
LOCK_HELD=1
CATALOG_BEFORE_IDENTITY="$(zstack_file_identity "$CATALOG")" || {
  echo "Could not identify catalog.yaml safely." >&2
  exit 1
}

if [[ -e "$DEST" ]]; then
  echo "Already exists: $DEST" >&2
  exit 1
fi
if grep -qE "^  - id:[[:space:]]*${NAME}[[:space:]]*$" "$CATALOG"; then
  echo "Already registered in catalog.yaml: $NAME" >&2
  exit 1
fi
for template_path in "$SKILL_TEMPLATE" "$QUALITY_TEMPLATE"; do
  if [[ ! -f "$template_path" || -L "$template_path" ]]; then
    echo "Scaffold template must be a real regular file: $template_path" >&2
    exit 1
  fi
done
SKILL_TEMPLATE_IDENTITY="$(zstack_file_identity "$SKILL_TEMPLATE")" || {
  echo "Could not identify the skill template safely." >&2
  exit 1
}
QUALITY_TEMPLATE_IDENTITY="$(zstack_file_identity "$QUALITY_TEMPLATE")" || {
  echo "Could not identify the quality-bar template safely." >&2
  exit 1
}

WORK_DIR="$(mktemp -d "$ROOT/.zstack-new-skill.XXXXXX")"
if ! zstack_capture_regular_file_snapshot \
  "$SKILL_TEMPLATE" SKILL_TEMPLATE_SNAPSHOT captured_template_identity \
  "$WORK_DIR/template.skill.XXXXXX" ||
   [[ "$captured_template_identity" != "$SKILL_TEMPLATE_IDENTITY" ]]; then
  echo "Scaffold templates changed while they were captured; no skill was published." >&2
  exit 1
fi
captured_template_identity=""
if ! zstack_capture_regular_file_snapshot \
  "$QUALITY_TEMPLATE" QUALITY_TEMPLATE_SNAPSHOT captured_template_identity \
  "$WORK_DIR/template.quality-bar.XXXXXX" ||
   [[ "$captured_template_identity" != "$QUALITY_TEMPLATE_IDENTITY" ]]; then
  echo "Scaffold templates changed while they were captured; no skill was published." >&2
  exit 1
fi

mkdir -p "$WORK_DIR/$NAME/references"
TITLE="$(printf '%s\n' "${NAME#z-}" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1')"
zstack_make_identity_temp_file \
  GENERATED_SKILL_TMP "$WORK_DIR/$NAME/.skill.XXXXXX" SKILL_FILE_IDENTITY
sed "s/z-skill-name/$NAME/g; s/Z Skill Name/$TITLE/g" \
  "$SKILL_TEMPLATE_SNAPSHOT" > "$GENERATED_SKILL_TMP"
if ! zstack_publish_identity_temp_file \
  "$GENERATED_SKILL_TMP" "$SKILL_FILE_IDENTITY" "$WORK_DIR/$NAME/SKILL.md"; then
  echo "Could not publish the generated SKILL.md safely." >&2
  exit 1
fi
zstack_make_identity_temp_file \
  GENERATED_QUALITY_TMP "$WORK_DIR/$NAME/references/.quality-bar.XXXXXX" \
  QUALITY_FILE_IDENTITY
sed "s/Z Skill Name/$TITLE/g" \
  "$QUALITY_TEMPLATE_SNAPSHOT" > \
  "$GENERATED_QUALITY_TMP"
if ! zstack_publish_identity_temp_file \
  "$GENERATED_QUALITY_TMP" "$QUALITY_FILE_IDENTITY" \
  "$WORK_DIR/$NAME/references/quality-bar.md"; then
  echo "Could not publish the generated quality-bar.md safely." >&2
  exit 1
fi
GENERATED_SKILL_DIRECTORY_IDENTITY="$(zstack_file_identity "$WORK_DIR/$NAME")" || {
  echo "Could not identify the generated skill directory safely." >&2
  exit 1
}

if ! zstack_capture_regular_file_snapshot \
  "$CATALOG" CATALOG_ORIGINAL_SNAPSHOT captured_catalog_identity \
  "$WORK_DIR/catalog.original.XXXXXX" ||
   [[ "$captured_catalog_identity" != "$CATALOG_BEFORE_IDENTITY" ]]; then
  echo "catalog.yaml changed while its original bytes were captured; no skill was published." >&2
  exit 1
fi
zstack_make_identity_temp_file \
  CATALOG_NEXT_SNAPSHOT "$WORK_DIR/catalog.next.XXXXXX" CATALOG_NEXT_IDENTITY
cp "$CATALOG_ORIGINAL_SNAPSHOT" "$CATALOG_NEXT_SNAPSHOT"
if ! zstack_regular_file_snapshot_is_unchanged \
  "$CATALOG_NEXT_SNAPSHOT" "$CATALOG_NEXT_IDENTITY" "$CATALOG_ORIGINAL_SNAPSHOT"; then
  echo "Catalog candidate changed while it was initialized; no skill was published." >&2
  exit 1
fi
{
  printf '\n  - id: %s\n' "$NAME"
  printf '    path: skills/%s\n' "$NAME"
  printf '    status: draft\n'
  printf '    category: %s\n' "$CATEGORY"
  printf '    hosts:\n'
  printf '      - agents\n      - claude\n      - codex\n      - grok\n'
  printf '    tags:\n      - indie\n'
  printf '    summary: >-\n'
  printf '      TODO: Describe the recurring solo-developer outcome for %s.\n' "$TITLE"
} >> "$CATALOG_NEXT_SNAPSHOT"
if ! zstack_capture_regular_file_snapshot \
  "$CATALOG_NEXT_SNAPSHOT" CATALOG_EXPECTED_SNAPSHOT captured_candidate_identity \
  "$WORK_DIR/catalog.expected.XXXXXX" ||
   [[ "$captured_candidate_identity" != "$CATALOG_NEXT_IDENTITY" ]]; then
  echo "Catalog candidate changed while it was snapshotted; no skill was published." >&2
  exit 1
fi

if ! zstack_regular_file_snapshot_is_unchanged \
  "$CATALOG" "$CATALOG_BEFORE_IDENTITY" "$CATALOG_ORIGINAL_SNAPSHOT"; then
  echo "catalog.yaml changed while the scaffold was prepared; no skill was published." >&2
  exit 1
fi
if [[ ! -f "$SKILL_TEMPLATE" || -L "$SKILL_TEMPLATE" ]] ||
   [[ ! -f "$QUALITY_TEMPLATE" || -L "$QUALITY_TEMPLATE" ]] ||
   ! zstack_regular_file_snapshot_is_unchanged \
     "$SKILL_TEMPLATE" "$SKILL_TEMPLATE_IDENTITY" "$SKILL_TEMPLATE_SNAPSHOT" ||
   ! zstack_regular_file_snapshot_is_unchanged \
     "$QUALITY_TEMPLATE" "$QUALITY_TEMPLATE_IDENTITY" "$QUALITY_TEMPLATE_SNAPSHOT"; then
  echo "Scaffold templates changed while the scaffold was prepared; no skill was published." >&2
  exit 1
fi
if [[ -e "$DEST" || -L "$DEST" ]]; then
  echo "Skill destination appeared while the scaffold was prepared: $DEST" >&2
  exit 1
fi
mv "$WORK_DIR/$NAME" "$DEST"
published_skill_identity="$(zstack_file_identity "$DEST" 2>/dev/null || true)"
if [[ "$published_skill_identity" != "$GENERATED_SKILL_DIRECTORY_IDENTITY" ]]; then
  remove_generated_skill_directory "$DEST/$NAME" "$GENERATED_SKILL_DIRECTORY_IDENTITY"
  echo "Skill destination changed during publication; catalog.yaml was not updated: $DEST" >&2
  exit 1
fi
MOVED_SKILL=1
CATALOG_REPLACE_STARTED=1
mv "$CATALOG_NEXT_SNAPSHOT" "$CATALOG"
if ! zstack_regular_file_snapshot_is_unchanged \
  "$CATALOG" "$CATALOG_NEXT_IDENTITY" "$CATALOG_EXPECTED_SNAPSHOT"; then
  echo "catalog.yaml changed during publication; the transaction did not complete." >&2
  exit 1
fi
COMPLETED=1

echo "Created $DEST/SKILL.md and references/quality-bar.md"
echo "Registered $NAME as a draft in $CATALOG"
echo "Next:"
echo "  1. Replace scaffold placeholders in SKILL.md"
echo "  2. Edit catalog category, tags, and TODO summary"
echo "  3. Customize the generated quality bar and Evidence handoff for this workflow"
echo "  4. Add three behavioral (including happy-path) and two routing evals before activating"
echo "  5. Run ./scripts/test.sh, then smoke-test natural-language routing and the host's explicit invocation"
