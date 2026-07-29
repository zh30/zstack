#!/usr/bin/env bash
# zstack setup — symlink skills into agent host skill roots
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
CATALOG="$ROOT/catalog.yaml"
HOSTS_DIR="$ROOT/hosts"
FORCE=0
PROJECT=0
HOST_FILTER=""

usage() {
  cat <<'EOF'
Usage: ./scripts/setup.sh [options]

  --force          Replace conflicting non-zstack paths when safe to reason about
  --project        Also link into <cwd>/.agents/skills (project-local)
  --hosts a,b,c    Only these host profile names (default: all enabled)
  -h, --help       Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    --project) PROJECT=1; shift ;;
    --hosts) HOST_FILTER="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

expand_path() {
  local p="$1"
  p="${p/#\~/$HOME}"
  echo "$p"
}

# Minimal YAML-ish extraction without requiring yq (v1 bootstrap).
# Expects catalog skills entries with "path: skills/foo" and "status: active".
list_active_skill_dirs() {
  if [[ ! -f "$CATALOG" ]]; then
    echo "Missing catalog.yaml" >&2
    return 1
  fi
  # If no skills registered yet, discover skills/* that have SKILL.md (except _template)
  local found=0
  while IFS= read -r dir; do
    local base
    base="$(basename "$dir")"
    [[ "$base" == _* ]] && continue
    [[ -f "$dir/SKILL.md" ]] || continue
    echo "$dir"
    found=1
  done < <(find "$ROOT/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)

  if [[ "$found" -eq 0 ]]; then
    echo "No skills found under skills/ (only template?). Add a skill first." >&2
  fi
}

host_enabled() {
  local file="$1"
  # default enabled if key missing
  if grep -qE '^enabled:[[:space:]]*false' "$file" 2>/dev/null; then
    return 1
  fi
  return 0
}

host_name() {
  local file="$1"
  grep -E '^name:' "$file" | head -1 | sed 's/^name:[[:space:]]*//' | tr -d '"' | tr -d "'"
}

host_root() {
  local file="$1"
  local r
  r="$(grep -E '^skills_root:' "$file" | head -1 | sed 's/^skills_root:[[:space:]]*//' | tr -d '"' | tr -d "'")"
  expand_path "$r"
}

link_skill() {
  local src="$1"
  local dest_root="$2"
  local name
  name="$(basename "$src")"
  local dest="$dest_root/$name"

  mkdir -p "$dest_root"

  if [[ -L "$dest" ]]; then
    local cur
    cur="$(readlink "$dest")"
    if [[ "$cur" == "$src" ]]; then
      echo "  ok  $dest"
      return 0
    fi
    # refresh link
    ln -sfn "$src" "$dest"
    echo "  upd $dest -> $src"
    return 0
  fi

  if [[ -e "$dest" ]]; then
    if [[ "$FORCE" -eq 1 ]]; then
      echo "  warn: $dest exists and is not a zstack symlink; --force not removing non-links for safety" >&2
      echo "  skip $dest (manual resolve required)" >&2
      return 0
    fi
    echo "  skip $dest (exists, not a symlink; use care / migrate manually)" >&2
    return 0
  fi

  ln -sfn "$src" "$dest"
  echo "  new $dest -> $src"
}

echo "zstack setup"
echo "  ZSTACK_ROOT=$ROOT"
mkdir -p "$HOME/.zstack"
echo "$ROOT" > "$HOME/.zstack/root"

echo "Skills:"
while IFS= read -r skill_dir; do
  [[ -z "$skill_dir" ]] && continue
  echo " · $(basename "$skill_dir")"
done < <(list_active_skill_dirs)

echo "Hosts:"
for host_file in "$HOSTS_DIR"/*.yaml; do
  [[ -f "$host_file" ]] || continue
  hname="$(host_name "$host_file")"
  if [[ -n "$HOST_FILTER" ]]; then
    [[ ",$HOST_FILTER," == *",$hname,"* ]] || continue
  fi
  if ! host_enabled "$host_file"; then
    echo " · $hname (disabled)"
    continue
  fi
  hroot="$(host_root "$host_file")"
  echo " · $hname → $hroot"
  while IFS= read -r skill_dir; do
    [[ -z "$skill_dir" ]] && continue
    link_skill "$skill_dir" "$hroot"
  done < <(list_active_skill_dirs)
done

if [[ "$PROJECT" -eq 1 ]]; then
  proj="$(pwd)/.agents/skills"
  echo "Project: $proj"
  while IFS= read -r skill_dir; do
    [[ -z "$skill_dir" ]] && continue
    link_skill "$skill_dir" "$proj"
  done < <(list_active_skill_dirs)
fi

echo "Done. Run ./scripts/doctor.sh to validate."
