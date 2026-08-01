#!/usr/bin/env bash
# Atomically scaffold a skill and register it as a catalog draft.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
CATALOG="$ROOT/catalog.yaml"

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

if [[ ! -f "$CATALOG" ]]; then
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

cleanup() {
  local status=$?
  local catalog_restored=1
  trap - EXIT HUP INT TERM
  if [[ "$status" -ne 0 && "$COMPLETED" -eq 0 ]]; then
    if [[ "$CATALOG_REPLACE_STARTED" -eq 1 ]]; then
      if ! mv "$WORK_DIR/catalog.original.yaml" "$CATALOG"; then
        echo "Rollback warning: could not restore catalog.yaml; preserving $DEST for consistency." >&2
        catalog_restored=0
      fi
    fi
    if [[ "$MOVED_SKILL" -eq 1 && "$catalog_restored" -eq 1 ]]; then
      rm -f "$DEST/SKILL.md" "$DEST/references/quality-bar.md"
      rmdir "$DEST/references" 2>/dev/null || true
      rmdir "$DEST" 2>/dev/null || true
    fi
  fi
  if [[ -n "$WORK_DIR" ]]; then
    rm -f "$WORK_DIR/catalog.next.yaml" "$WORK_DIR/catalog.original.yaml" \
      "$WORK_DIR/$NAME/SKILL.md" "$WORK_DIR/$NAME/references/quality-bar.md"
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

if [[ -e "$DEST" ]]; then
  echo "Already exists: $DEST" >&2
  exit 1
fi
if grep -qE "^  - id:[[:space:]]*${NAME}[[:space:]]*$" "$CATALOG"; then
  echo "Already registered in catalog.yaml: $NAME" >&2
  exit 1
fi

WORK_DIR="$(mktemp -d "$ROOT/.zstack-new-skill.XXXXXX")"

mkdir -p "$WORK_DIR/$NAME/references"
TITLE="$(printf '%s\n' "${NAME#z-}" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1')"
sed "s/z-skill-name/$NAME/g; s/Z Skill Name/$TITLE/g" \
  "$ROOT/skills/_template/SKILL.md" > "$WORK_DIR/$NAME/SKILL.md"
sed "s/Z Skill Name/$TITLE/g" \
  "$ROOT/skills/_template/references/quality-bar.md" > \
  "$WORK_DIR/$NAME/references/quality-bar.md"

cp "$CATALOG" "$WORK_DIR/catalog.original.yaml"
cp "$CATALOG" "$WORK_DIR/catalog.next.yaml"
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
} >> "$WORK_DIR/catalog.next.yaml"

mv "$WORK_DIR/$NAME" "$DEST"
MOVED_SKILL=1
CATALOG_REPLACE_STARTED=1
mv "$WORK_DIR/catalog.next.yaml" "$CATALOG"
COMPLETED=1

echo "Created $DEST/SKILL.md and references/quality-bar.md"
echo "Registered $NAME as a draft in $CATALOG"
echo "Next:"
echo "  1. Replace scaffold placeholders in SKILL.md"
echo "  2. Edit catalog category, tags, and TODO summary"
echo "  3. Customize the generated quality bar and Evidence handoff for this workflow"
echo "  4. Add three behavioral (including happy-path) and two routing evals before activating"
echo "  5. Run ./scripts/test.sh, then smoke-test natural-language routing and the host's explicit invocation"
