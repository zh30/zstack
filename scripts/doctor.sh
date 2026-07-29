#!/usr/bin/env bash
# zstack doctor — validate skill structure and optional install links
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
ERRORS=0
WARNINGS=0

err() { echo "ERROR: $*" >&2; ERRORS=$((ERRORS + 1)); }
warn() { echo "WARN:  $*" >&2; WARNINGS=$((WARNINGS + 1)); }
ok() { echo "OK:   $*"; }

check_skill() {
  local dir="$1"
  local name base
  base="$(basename "$dir")"
  [[ "$base" == _* ]] && return 0

  local skill_md="$dir/SKILL.md"
  if [[ ! -f "$skill_md" ]]; then
    err "$base: missing SKILL.md"
    return
  fi

  if ! grep -qE '^---[[:space:]]*$' "$skill_md"; then
    err "$base: missing YAML frontmatter"
    return
  fi

  # Extract frontmatter name (simple)
  local fm_name fm_desc
  fm_name="$(awk 'BEGIN{fm=0} /^---/{fm++; next} fm==1 && /^name:/{sub(/^name:[[:space:]]*/,""); gsub(/["'\'']/,""); print; exit}' "$skill_md")"
  fm_desc="$(awk 'BEGIN{fm=0} /^---/{fm++; next} fm==1 && /^description:/{print; exit}' "$skill_md")"

  if [[ -z "$fm_name" ]]; then
    err "$base: frontmatter missing name"
  elif [[ "$fm_name" != "$base" ]]; then
    err "$base: name '$fm_name' != directory '$base'"
  else
    ok "$base: name matches"
  fi

  if [[ -z "$fm_desc" ]]; then
    err "$base: frontmatter missing description"
  else
    ok "$base: has description"
  fi

  # name regex — z- prefix required
  if [[ ! "$base" =~ ^z-[a-z0-9]([a-z0-9-]{0,60}[a-z0-9])?$ ]]; then
    err "$base: directory name must match ^z-[a-z0-9-]+\$ (z- prefix required)"
  fi

  # portability nits
  if grep -qE 'mcp__claude-in-chrome' "$skill_md"; then
    warn "$base: references claude-in-chrome MCP (prefer portable browse instructions)"
  fi
  if grep -qE '/Users/henry/' "$skill_md"; then
    warn "$base: hardcodes /Users/henry path"
  fi
}

echo "zstack doctor (root=$ROOT)"
echo "── skills ──"
shopt -s nullglob
for dir in "$ROOT/skills"/*/; do
  check_skill "${dir%/}"
done

echo "── links (if hosts configured) ──"
if [[ -f "$HOME/.zstack/root" ]]; then
  ZROOT="$(cat "$HOME/.zstack/root")"
  ok "recorded ZSTACK_ROOT=$ZROOT"
else
  warn "no ~/.zstack/root yet — run setup.sh"
fi

for host_file in "$ROOT/hosts"/*.yaml; do
  [[ -f "$host_file" ]] || continue
  if grep -qE '^enabled:[[:space:]]*false' "$host_file"; then
    continue
  fi
  hname="$(grep -E '^name:' "$host_file" | head -1 | sed 's/^name:[[:space:]]*//')"
  hroot="$(grep -E '^skills_root:' "$host_file" | head -1 | sed 's/^skills_root:[[:space:]]*//' | tr -d '"' | tr -d "'")"
  hroot="${hroot/#\~/$HOME}"
  [[ -d "$hroot" ]] || { warn "host $hname root missing: $hroot"; continue; }

  for dir in "$ROOT/skills"/*/; do
    base="$(basename "${dir%/}")"
    [[ "$base" == _* ]] && continue
    [[ -f "${dir}SKILL.md" ]] || continue
    dest="$hroot/$base"
    if [[ -L "$dest" ]]; then
      target="$(readlink "$dest")"
      resolved="$(cd "$(dirname "$dest")" && cd "$(dirname "$target")" 2>/dev/null && pwd -P)/$(basename "$target")" || resolved="$target"
      case "$target" in
        "$ROOT/skills/$base"|*/zstack/skills/"$base")
          ok "link $hname:$base"
          ;;
        *)
          # also accept if realpath equals skill dir
          if [[ "$(cd "$dest" 2>/dev/null && pwd -P)" == "$(cd "${dir%/}" && pwd -P)" ]]; then
            ok "link $hname:$base (resolves to zstack)"
          else
            warn "link $hname:$base points elsewhere: $target"
          fi
          ;;
      esac
    elif [[ -e "$dest" ]]; then
      warn "host $hname has non-link $base (not managed by zstack)"
    fi
  done
done

echo "── summary ──"
echo "errors=$ERRORS warnings=$WARNINGS"
[[ "$ERRORS" -eq 0 ]] || exit 1
