#!/usr/bin/env bash
# Remove zstack-managed symlinks only (targets under this repo's skills/)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
REMOVED=0

for host_file in "$ROOT/hosts"/*.yaml; do
  [[ -f "$host_file" ]] || continue
  hroot="$(grep -E '^skills_root:' "$host_file" | head -1 | sed 's/^skills_root:[[:space:]]*//' | tr -d '"' | tr -d "'")"
  hroot="${hroot/#\~/$HOME}"
  [[ -d "$hroot" ]] || continue

  for link in "$hroot"/*; do
    [[ -L "$link" ]] || continue
    target="$(readlink "$link")"
    # Resolve relative links
    if [[ "$target" != /* ]]; then
      target="$(cd "$(dirname "$link")" && cd "$(dirname "$target")" 2>/dev/null && pwd -P)/$(basename "$target")" || continue
    fi
    case "$target" in
      "$ROOT/skills"/*)
        rm -f "$link"
        echo "removed $link"
        REMOVED=$((REMOVED + 1))
        ;;
    esac
  done
done

echo "Removed $REMOVED zstack symlink(s)."
