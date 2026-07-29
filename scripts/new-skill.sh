#!/usr/bin/env bash
# Scaffold a new skill from skills/_template
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
NAME="${1:-}"

if [[ -z "$NAME" ]]; then
  echo "Usage: ./scripts/new-skill.sh <skill-name>" >&2
  exit 1
fi

if [[ ! "$NAME" =~ ^z-[a-z0-9]([a-z0-9-]{0,60}[a-z0-9])?$ ]]; then
  echo "Invalid name '$NAME'. Must use z- prefix + kebab-case (e.g. z-my-skill), max 64 chars." >&2
  exit 1
fi

DEST="$ROOT/skills/$NAME"
if [[ -e "$DEST" ]]; then
  echo "Already exists: $DEST" >&2
  exit 1
fi

mkdir -p "$DEST"
# Title: z-foo-bar -> Foo Bar (drop z- for heading)
TITLE="$(echo "${NAME#z-}" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1')"
sed "s/z-skill-name/$NAME/g; s/Z Skill Name/$TITLE/g; s/skill-name/$NAME/g" \
  "$ROOT/skills/_template/SKILL.md" > "$DEST/SKILL.md"

echo "Created $DEST/SKILL.md"
echo "Next:"
echo "  1. Edit description + steps"
echo "  2. Add entry to catalog.yaml (optional but recommended)"
echo "  3. ./scripts/doctor.sh"
echo "  4. ./scripts/setup.sh"
