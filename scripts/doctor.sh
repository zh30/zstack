#!/usr/bin/env bash
# Validate zstack source structure and, optionally, installed links.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
CATALOG="$ROOT/catalog.yaml"
EVALS="$ROOT/evals/cases.yaml"
ROUTING_EVALS="$ROOT/evals/routing.yaml"
SOURCE_ONLY=0
FAIL_FAST=0
DESCRIPTION_MAX=1024
ERRORS=0
WARNINGS=0

# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: ./scripts/doctor.sh [--source-only] [--fail-fast]

  --source-only   Validate repository content without checking installed links
  --fail-fast     Stop after the first validation error
  -h, --help      Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source-only) SOURCE_ONLY=1; shift ;;
    --fail-fast) FAIL_FAST=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

err() {
  echo "ERROR: $*" >&2
  ERRORS=$((ERRORS + 1))
  [[ "$FAIL_FAST" -eq 0 ]] || exit 1
}
warn() { echo "WARN:  $*" >&2; WARNINGS=$((WARNINGS + 1)); }
ok() { echo "OK:   $*"; }

repository_candidates() {
  if command -v git >/dev/null 2>&1 && git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$ROOT" ls-files --cached --others --exclude-standard -z
  else
    (
      cd "$ROOT"
      find . \( -path './.git' -o -path './.gstack' -o -path './node_modules' \) -prune -o \
        \( -type f -o -type l \) -print0
    )
  fi
}

inspect_skill_file() {
  local skill_md="$1"
  awk '
    function clean(value) {
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      gsub(/^[\047\"]|[\047\"]$/, "", value)
      return value
    }
    function find_references(text, value) {
      while (match(text, /references\/[a-zA-Z0-9._\/-]+\.md/)) {
        value = substr(text, RSTART, RLENGTH)
        references[value] = 1
        text = substr(text, RSTART + RLENGTH)
      }
    }
    BEGIN { separator = sprintf("%c", 28) }
    {
      find_references($0)
    }
    NR == 1 {
      first_line_valid = ($0 == "---")
      if (first_line_valid) {
        in_frontmatter = 1
        next
      }
    }
    in_frontmatter && /^---[[:space:]]*$/ {
      in_frontmatter = 0
      frontmatter_closed = 1
      in_body = 1
      capture_description = 0
      next
    }
    in_frontmatter && /^[a-zA-Z0-9_-]+:[[:space:]]*/ {
      capture_description = 0
      line = $0
      key = line
      sub(/:.*/, "", key)
      keys = keys (keys == "" ? "" : ",") key
      key_count++
      sub(/^[a-zA-Z0-9_-]+:[[:space:]]*/, "", line)
      if (key == "name") {
        name = clean(line)
      } else if (key == "description") {
        capture_description = 1
        if (line != ">-" && line != ">" && line != "|-" && line != "|") {
          description = clean(line) " "
        }
      }
      next
    }
    in_frontmatter && capture_description {
      description = description clean($0) " "
      next
    }
    in_frontmatter { next }
    in_body && body_heading == "" && NF { body_heading = $0 }
    END {
      sub(/[[:space:]]+$/, "", description)
      print "META" separator first_line_valid separator frontmatter_closed separator name separator key_count separator keys separator description separator body_heading separator NR
      for (reference in references) {
        print "REF" separator reference
      }
    }
  ' "$skill_md"
}

check_skill() {
  local dir="$1"
  local expected_name="$2"
  local skill_md="$dir/SKILL.md"
  local base fm_name fm_keys key key_count description description_chars lines ref ref_lines body_heading
  local first_line_valid frontmatter_closed record field_a field_b field_c field_d field_e field_f field_g field_h
  local referenced_files skill_text
  base="${dir##*/}"

  if [[ ! -f "$skill_md" ]]; then
    err "$base: missing SKILL.md"
    return
  fi

  first_line_valid=0
  frontmatter_closed=0
  fm_name=""
  key_count=0
  fm_keys=""
  description=""
  body_heading=""
  lines=0
  referenced_files=""
  while IFS=$'\034' read -r record field_a field_b field_c field_d field_e field_f field_g field_h; do
    if [[ "$record" == "META" ]]; then
      first_line_valid="$field_a"
      frontmatter_closed="$field_b"
      fm_name="$field_c"
      key_count="$field_d"
      fm_keys="$field_e"
      description="$field_f"
      body_heading="$field_g"
      lines="$field_h"
    elif [[ "$record" == "REF" ]]; then
      referenced_files="${referenced_files}${referenced_files:+$'\n'}$field_a"
    fi
  done < <(inspect_skill_file "$skill_md")

  if [[ "$first_line_valid" -ne 1 ]]; then
    err "$base: SKILL.md must start with YAML frontmatter"
    return
  fi

  if [[ "$frontmatter_closed" -ne 1 ]]; then
    err "$base: YAML frontmatter is not closed"
    return
  fi

  if [[ "$fm_name" != "$expected_name" ]]; then
    err "$base: frontmatter name '$fm_name' != expected '$expected_name'"
  else
    ok "$base: name matches"
  fi

  if [[ "$key_count" -ne 2 ]]; then
    err "$base: frontmatter must contain exactly name + description (found $key_count keys)"
  fi
  old_ifs="$IFS"
  IFS=','
  for key in $fm_keys; do
    [[ -n "$key" ]] || continue
    case "$key" in
      name|description) ;;
      *) err "$base: unsupported frontmatter key '$key'" ;;
    esac
  done
  IFS="$old_ifs"

  description_chars="${#description}"
  if [[ -z "${description//[[:space:]]/}" ]]; then
    err "$base: frontmatter description is empty"
  elif [[ "$description_chars" -lt 80 ]]; then
    err "$base: description must explain what the skill does and when to use it (found $description_chars characters)"
  elif [[ "$description_chars" -gt "$DESCRIPTION_MAX" ]]; then
    err "$base: description is $description_chars characters (configured limit: $DESCRIPTION_MAX)"
  elif [[ "$description" == *"/z-"* || "$description" == *"\$z-"* ]]; then
    err "$base: description must not include host-specific /z-* or \$z-* invocation syntax"
  else
    ok "$base: description routes by intent ($description_chars chars)"
  fi

  skill_text="$(<"$skill_md")"
  if [[ "$expected_name" != "z-skill-name" ]] && {
    [[ "$skill_text" == *"TODO: Describe the recurring independent-developer outcome"* ]] ||
    [[ "$skill_text" == *"Describe the recurring independent-developer outcome in one or two sentences."* ]] ||
    [[ "$skill_text" == *"What this skill does in one or two sentences."* ]] ||
    [[ "$skill_text" == *$'\n- …\n'* ]] ||
    [[ "$skill_text" == *$'\n1. …\n'* ]] ||
    [[ "$skill_text" == *$'\n2. …\n'* ]];
  }; then
    err "$base: SKILL.md still contains scaffold placeholder content"
  fi

  if grep -q '^## When to use[[:space:]]*$' "$skill_md"; then
    err "$base: put trigger guidance in frontmatter description, not a body 'When to use' section"
  fi

  if [[ "$expected_name" != "z-skill-name" ]] && [[ ! "$base" =~ ^z-[a-z0-9]([a-z0-9-]{0,60}[a-z0-9])?$ ]]; then
    err "$base: directory name must use the z- prefix, kebab-case, and at most 64 characters"
  fi

  if [[ "$body_heading" != "# "* ]]; then
    err "$base: SKILL.md body must start with a level-one heading"
  fi

  if [[ "$lines" -gt 500 ]]; then
    warn "$base: SKILL.md is $lines lines; move detail into references/"
  fi

  while IFS= read -r ref; do
    [[ -n "$ref" ]] || continue
    if [[ ! -f "$dir/$ref" ]]; then
      err "$base: referenced file does not exist: $ref"
    fi
  done <<< "$referenced_files"

  if [[ -d "$dir/references" ]]; then
    for ref in "$dir"/references/*.md; do
      [[ -e "$ref" ]] || continue
      ref_name="${ref##*/}"
      if [[ "$skill_text" != *"references/$ref_name"* ]]; then
        err "$base: reference is not discoverable from SKILL.md: references/$ref_name"
      fi
      ref_lines="$(wc -l < "$ref" | tr -d ' ')"
      if [[ "$ref_lines" -gt 100 ]] && ! sed -n '1,30p' "$ref" | grep -Eq '^## (Contents|Table of contents|目录)[[:space:]]*$'; then
        err "$base: long reference needs a Contents section in its first 30 lines: references/$ref_name ($ref_lines lines)"
      fi
    done
  fi

}

check_markdown_links() {
  local candidate md line_number raw target base
  while IFS=: read -r md line_number raw; do
    base="$ROOT/$(dirname "$md")"
    target="${raw#](}"
    target="${target%)}"
    target="${target%%#*}"
    target="${target#<}"
    target="${target%>}"
    [[ -n "$target" ]] || continue
    case "$target" in
      http://*|https://*|mailto:*|/*|\[*) continue ;;
    esac
    if [[ ! -e "$base/$target" ]]; then
      err "broken local Markdown link in $md:$line_number: $target"
    fi
  done < <(
    repository_candidates |
      while IFS= read -r -d '' candidate; do
        candidate="${candidate#./}"
        [[ "$candidate" == *.md ]] || continue
        [[ -f "$ROOT/$candidate" && ! -L "$ROOT/$candidate" ]] || continue
        printf '%s\0' "$candidate"
      done |
      (cd "$ROOT" && xargs -0 grep -HnoE '\]\(([^)#]+)(#[^)]+)?\)' 2>/dev/null || true)
  )
}

check_workflow_action_pins() {
  local workflow record line_number action_ref

  for workflow in "$ROOT"/.github/workflows/*.yml "$ROOT"/.github/workflows/*.yaml; do
    [[ -f "$workflow" ]] || continue
    while IFS='|' read -r line_number action_ref; do
      [[ -n "$action_ref" ]] || continue
      case "$action_ref" in
        ./*) continue ;;
      esac
      if [[ ! "$action_ref" =~ ^[^[:space:]#]+@[0-9a-f]{40}$ ]]; then
        err "workflow action must use a full immutable commit SHA in ${workflow#"$ROOT/"}:$line_number: $action_ref"
      fi
    done < <(
      awk '
        /^[[:space:]]*(-[[:space:]]+)?uses:[[:space:]]*/ {
          value = $0
          sub(/^[[:space:]]*(-[[:space:]]+)?uses:[[:space:]]*/, "", value)
          sub(/[[:space:]]+#.*/, "", value)
          gsub(/^[\047\"]|[\047\"]$/, "", value)
          print NR "|" value
        }
      ' "$workflow"
    )
  done
}

echo "zstack doctor (root=$ROOT)"
echo "── yaml ──"
if command -v ruby >/dev/null 2>&1; then
  if yaml_result="$(ruby "$ROOT/scripts/validate-yaml.rb" 2>&1)"; then
    ok "$yaml_result"
  else
    printf '%s\n' "$yaml_result" >&2
    err "strict YAML validation failed"
  fi
else
  warn "ruby is unavailable; skipped strict YAML syntax and duplicate-key checks"
fi

echo "── evidence ──"
if command -v ruby >/dev/null 2>&1; then
  if evidence_result="$(ruby "$ROOT/scripts/validate-evidence.rb" 2>&1)"; then
    ok "$evidence_result"
  else
    printf '%s\n' "$evidence_result" >&2
    err "evaluation evidence validation failed"
  fi
else
  warn "ruby is unavailable; skipped evaluation evidence integrity checks"
fi

echo "── workflows ──"
workflow_errors="$ERRORS"
check_workflow_action_pins
if [[ "$ERRORS" -eq "$workflow_errors" ]]; then
  ok "GitHub Actions use immutable commit references"
fi

echo "── catalog ──"
CATALOG_TMP="$(mktemp "${TMPDIR:-/tmp}/zstack-catalog.XXXXXX")"
EVAL_TMP=""
ROUTING_TMP=""
HAN_ROUTING_TMP=""
trap 'rm -f "${CATALOG_TMP:-}" "${EVAL_TMP:-}" "${ROUTING_TMP:-}" "${HAN_ROUTING_TMP:-}"' EXIT
if [[ ! -f "$CATALOG" ]]; then
  err "missing catalog.yaml"
else
  if grep -qE '^version:[[:space:]]*1[[:space:]]*$' "$CATALOG"; then
    ok "catalog version 1"
  else
    err "catalog.yaml must declare version: 1"
  fi

  zstack_catalog_entries "$CATALOG" > "$CATALOG_TMP"

  if [[ ! -s "$CATALOG_TMP" ]]; then
    err "catalog.yaml has no skill entries"
  fi

  while IFS= read -r duplicate; do
    [[ -n "$duplicate" ]] && err "catalog has duplicate id: $duplicate"
  done < <(cut -d'|' -f1 "$CATALOG_TMP" | sort | uniq -d)

  while IFS='|' read -r id path status hosts category tags summary_chars; do
    [[ -n "$id" ]] || { err "catalog entry missing id"; continue; }
    if [[ ! "$id" =~ ^z-[a-z0-9]([a-z0-9-]{0,60}[a-z0-9])?$ ]]; then
      err "catalog id '$id' violates z- naming policy"
    fi
    if [[ "$path" != "skills/$id" ]]; then
      err "$id: catalog path must be skills/$id (found '$path')"
    elif [[ ! -d "$ROOT/$path" ]]; then
      err "$id: catalog path does not exist: $path"
    fi
    case "$status" in
      active|draft|deprecated) ;;
      *) err "$id: invalid catalog status '$status'" ;;
    esac
    if [[ "$status" == "active" && -d "$ROOT/$path" ]]; then
      quality_bar="$ROOT/$path/references/quality-bar.md"
      if [[ ! -f "$quality_bar" ]]; then
        err "$id: active skill requires references/quality-bar.md"
      else
        if ! grep -Fq 'references/quality-bar.md' "$ROOT/$path/SKILL.md"; then
          err "$id: quality bar must be linked directly from SKILL.md"
        fi
        if ! grep -qi 'evidence handoff' "$quality_bar"; then
          err "$id: quality bar must check the evidence handoff"
        fi
      fi
      if ! grep -RqsE '^## ([0-9]+\.)?[[:space:]]*Evidence handoff[[:space:]]*$' "$ROOT/$path"; then
        err "$id: primary output template must include an Evidence handoff section"
      else
        handoff_heading_found=0
        handoff_complete=0
        handoff_missing=""
        handoff_classes_missing=""
        handoff_shape_invalid=0
        while IFS= read -r handoff_candidate; do
          if ! grep -qE '^## ([0-9]+\.)?[[:space:]]*Evidence handoff[[:space:]]*$' "$handoff_candidate"; then
            continue
          fi
          handoff_heading_found=1
          handoff_block="$(awk '
            /^## ([0-9]+\.)?[[:space:]]*Evidence handoff[[:space:]]*$/ {
              inside = 1
              next
            }
            inside && /^##[[:space:]]/ { exit }
            inside { print }
          ' "$handoff_candidate")"
          handoff_flat="$(printf '%s\n' "$handoff_block" | tr '\n' ' ' | tr -s '[:space:]' ' ')"
          candidate_missing=""
          for handoff_field in \
            "Current decision" \
            "Evidence classes" \
            "Supported claims" \
            "Still unproven" \
            "Contradictions / exclusions" \
            "Source anchors" \
            "Next validation"; do
            if ! printf '%s\n' "$handoff_flat" | grep -qiF "$handoff_field"; then
              candidate_missing="${candidate_missing}${candidate_missing:+, }$handoff_field"
            fi
          done
          candidate_classes_missing=""
          for evidence_class in \
            "primary behavior" \
            "observed experiment" \
            "secondary public" \
            "search signal" \
            "assumption"; do
            if ! printf '%s\n' "$handoff_flat" | grep -qiF "$evidence_class"; then
              candidate_classes_missing="${candidate_classes_missing}${candidate_classes_missing:+, }$evidence_class"
            fi
          done
          if [[ -z "$candidate_missing" && -z "$candidate_classes_missing" ]]; then
            if ruby -I "$ROOT/scripts/lib" -r evidence_handoff_contract -e '
              path = ARGV.fetch(0)
              result = Zstack::EvidenceHandoffContract.evaluate([{ name: path, path: path }])
              exit(result.fetch("passed") ? 0 : 1)
            ' "$handoff_candidate"; then
              handoff_complete=1
              break
            fi
            handoff_shape_invalid=1
          fi
          [[ -n "$handoff_missing" ]] || handoff_missing="$candidate_missing"
          [[ -n "$handoff_classes_missing" ]] || handoff_classes_missing="$candidate_classes_missing"
        done < <(find "$ROOT/$path" -type f -name '*.md' -print | sort)
        if [[ "$handoff_heading_found" -eq 1 && "$handoff_complete" -eq 0 ]]; then
          if [[ -n "$handoff_missing" ]]; then
            err "$id: Evidence handoff is missing required fields: $handoff_missing"
          fi
          if [[ -n "$handoff_classes_missing" ]]; then
            err "$id: Evidence handoff is missing evidence classes: $handoff_classes_missing"
          fi
          if [[ "$handoff_shape_invalid" -eq 1 ]]; then
            err "$id: Evidence handoff template must contain exactly one valid two-column Field | Value table"
          fi
        fi
      fi
      if ! grep -Fq 'Evidence does not upgrade on handoff' "$ROOT/$path/SKILL.md"; then
        err "$id: SKILL.md must preserve evidence class across handoffs"
      fi
      if ! grep -Fq 'The handoff is a fixed interface.' "$ROOT/$path/SKILL.md"; then
        err "$id: SKILL.md must define Evidence handoff as a fixed interface"
      fi
      if ! grep -Fq 'two-column' "$ROOT/$path/SKILL.md" || ! grep -Fq 'Field | Value' "$ROOT/$path/SKILL.md"; then
        err "$id: SKILL.md must require one two-column Field | Value Evidence handoff"
      fi
      if ! grep -Fq 'Never leave the class cell empty.' "$ROOT/$path/SKILL.md"; then
        err "$id: SKILL.md must require a non-empty Evidence classes cell"
      fi
      runtime_handoff_flat="$(tr '\n' ' ' < "$ROOT/$path/SKILL.md" | tr -s '[:space:]' ' ')"
      runtime_handoff_missing=""
      for runtime_handoff_field in \
        "Current decision" \
        "Evidence classes" \
        "Supported claims" \
        "Still unproven" \
        "Contradictions / exclusions" \
        "Source anchors" \
        "Next validation"; do
        if ! printf '%s\n' "$runtime_handoff_flat" | grep -qiF "$runtime_handoff_field"; then
          runtime_handoff_missing="${runtime_handoff_missing}${runtime_handoff_missing:+, }$runtime_handoff_field"
        fi
      done
      if [[ -n "$runtime_handoff_missing" ]]; then
        err "$id: SKILL.md fixed interface is missing runtime field labels: $runtime_handoff_missing"
      fi
    fi
    if [[ ! "$category" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
      err "$id: category must be non-empty kebab-case (found '$category')"
    elif [[ "$category" == "uncategorized" ]]; then
      err "$id: replace the scaffold category 'uncategorized'"
    fi
    if [[ -z "$tags" ]]; then
      err "$id: catalog entry needs at least one non-empty tag"
    else
      while IFS= read -r duplicate_tag; do
        [[ -n "$duplicate_tag" ]] && err "$id: duplicate catalog tag '$duplicate_tag'"
      done < <(printf '%s\n' "$tags" | tr ',' '\n' | sort | uniq -d)
      old_ifs="$IFS"
      IFS=','
      has_indie_tag=0
      for tag in $tags; do
        if [[ ! "$tag" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
          err "$id: catalog tag '$tag' must be kebab-case"
        fi
        [[ "$tag" == "indie" ]] && has_indie_tag=1
      done
      IFS="$old_ifs"
      [[ "$has_indie_tag" -eq 1 ]] || err "$id: catalog tags must include 'indie'"
    fi
    [[ "$summary_chars" -ge 20 ]] || err "$id: catalog summary must contain at least 20 characters"
    if [[ -z "$hosts" ]]; then
      err "$id: catalog hosts list is empty"
    else
      while IFS= read -r duplicate_host; do
        [[ -n "$duplicate_host" ]] && err "$id: duplicate host '$duplicate_host'"
      done < <(printf '%s\n' "$hosts" | tr ',' '\n' | sort | uniq -d)
      old_ifs="$IFS"
      IFS=','
      for host in $hosts; do
        if [[ ! -f "$ROOT/hosts/$host.yaml" ]]; then
          err "$id: unknown host '$host'"
        fi
      done
      IFS="$old_ifs"
    fi
  done < "$CATALOG_TMP"
  if grep -qE '(^|[^[:alnum:]_])TODO([^[:alnum:]_]|$)' "$CATALOG"; then
    err "catalog.yaml still contains TODO placeholder content"
  fi
fi

echo "── hosts ──"
for host_file in "$ROOT"/hosts/*.yaml; do
  [[ -f "$host_file" ]] || continue
  expected_host="$(basename "$host_file" .yaml)"
  profile="$(zstack_host_profile "$host_file")"
  IFS='|' read -r declared_host display_name skills_root link_mode enabled description_max required_name required_description <<< "$profile"
  profile_errors="$ERRORS"

  if [[ "$description_max" =~ ^[1-9][0-9]*$ ]] && [[ "$description_max" -lt "$DESCRIPTION_MAX" ]]; then
    DESCRIPTION_MAX="$description_max"
  fi

  if [[ "$declared_host" != "$expected_host" ]]; then
    err "$expected_host: host profile name '$declared_host' must match its filename"
  fi
  if [[ ! "$expected_host" =~ ^[a-z][a-z0-9-]*$ ]]; then
    err "$expected_host: host profile filename must be kebab-case"
  fi
  if [[ -z "${display_name//[[:space:]]/}" ]]; then
    err "$expected_host: display_name must be non-empty"
  fi
  if ! zstack_is_safe_home_relative_path "$skills_root"; then
    err "$expected_host: skills_root must stay inside HOME without '.' or '..' components"
  fi
  if [[ "$link_mode" != "symlink" ]]; then
    err "$expected_host: unsupported link_mode '$link_mode' (v1 supports symlink)"
  fi
  if [[ "$enabled" != "true" && "$enabled" != "false" ]]; then
    err "$expected_host: enabled must be true or false"
  fi
  if [[ "$required_name" -ne 1 || "$required_description" -ne 1 ]]; then
    err "$expected_host: frontmatter.required must include name and description"
  fi
  if [[ "$expected_host" == "codex" && ! "$description_max" =~ ^[1-9][0-9]*$ ]]; then
    err "$expected_host: description_max_chars must be a positive integer"
  elif [[ -n "$description_max" && ! "$description_max" =~ ^[1-9][0-9]*$ ]]; then
    err "$expected_host: description_max_chars, when set, must be a positive integer"
  fi
  if [[ "$ERRORS" -eq "$profile_errors" ]]; then
    ok "$expected_host: profile contract"
  fi
done

echo "── skills ──"
shopt -s nullglob
for dir in "$ROOT"/skills/*/; do
  dir="${dir%/}"
  base="$(basename "$dir")"
  if [[ "$base" == "_template" ]]; then
    check_skill "$dir" "z-skill-name"
    continue
  fi
  check_skill "$dir" "$base"
  if [[ -f "${CATALOG_TMP:-}" ]]; then
    count="$(awk -F'|' -v id="$base" '$1 == id {count++} END {print count + 0}' "$CATALOG_TMP")"
    if [[ "$count" -eq 0 ]]; then
      err "$base: missing from catalog.yaml"
    elif [[ "$count" -eq 1 ]]; then
      ok "$base: registered in catalog"
    fi
  fi
done

if [[ -f "${CATALOG_TMP:-}" ]]; then
  while IFS='|' read -r id path status hosts category tags summary_chars; do
    [[ -d "$ROOT/skills/$id" ]] || err "$id: catalog entry has no matching skill directory"
  done < "$CATALOG_TMP"
fi

echo "── evals ──"
EVAL_TMP="$(mktemp "${TMPDIR:-/tmp}/zstack-evals.XXXXXX")"
if [[ ! -f "$EVALS" ]]; then
  err "missing evals/cases.yaml"
else
  if ! grep -qE '^version:[[:space:]]*1[[:space:]]*$' "$EVALS"; then
    err "evals/cases.yaml must declare version: 1"
  fi
  contract_must_count="$(awk '
    /^contract_must:[[:space:]]*$/ { section = 1; next }
    section && /^[^[:space:]]/ { section = 0 }
    section && /^  -[[:space:]]*[^[:space:]]/ { count++ }
    END { print count + 0 }
  ' "$EVALS")"
  if [[ "$contract_must_count" -lt 1 ]]; then
    err "evals/cases.yaml needs at least one shared contract_must criterion"
  fi
  if ! grep -Fq 'Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names.' "$EVALS"; then
    err "evals/cases.yaml must test the fixed Evidence handoff contract for every case"
  fi
  if ! grep -Fq 'Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence.' "$EVALS"; then
    err "evals/cases.yaml must test Evidence class applicability for every case"
  fi
  awk '
    function clean(value) {
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      return value
    }
    function flush() {
      if (id != "") print id "|" skill "|" kind "|" execution "|" prompt_chars "|" must_count "|" must_not_count
    }
    /^  - id:[[:space:]]*/ {
      flush()
      id = $0
      sub(/^  - id:[[:space:]]*/, "", id)
      skill = ""
      kind = ""
      execution = "response"
      prompt_chars = 0
      must_count = 0
      must_not_count = 0
      section = ""
      next
    }
    id != "" && /^    skill:[[:space:]]*/ {
      skill = $0
      sub(/^    skill:[[:space:]]*/, "", skill)
      section = ""
      next
    }
    id != "" && /^    kind:[[:space:]]*/ {
      kind = $0
      sub(/^    kind:[[:space:]]*/, "", kind)
      section = ""
      next
    }
    id != "" && /^    execution:[[:space:]]*/ {
      execution = $0
      sub(/^    execution:[[:space:]]*/, "", execution)
      section = ""
      next
    }
    id != "" && /^    prompt:[[:space:]]*/ {
      value = $0
      sub(/^    prompt:[[:space:]]*/, "", value)
      value = clean(value)
      if (value == ">-" || value == ">" || value == "|-" || value == "|") {
        section = "prompt"
      } else {
        prompt_chars = length(value)
        section = ""
      }
      next
    }
    id != "" && /^    must:[[:space:]]*$/ { section = "must"; next }
    id != "" && /^    must_not:[[:space:]]*$/ { section = "must_not"; next }
    id != "" && section == "prompt" && /^      / {
      prompt_chars += length(clean($0))
      next
    }
    id != "" && section == "must" && /^      -[[:space:]]*/ {
      value = $0
      sub(/^      -[[:space:]]*/, "", value)
      if (clean(value) != "") must_count++
      next
    }
    id != "" && section == "must_not" && /^      -[[:space:]]*/ {
      value = $0
      sub(/^      -[[:space:]]*/, "", value)
      if (clean(value) != "") must_not_count++
      next
    }
    id != "" && /^    [a-zA-Z0-9_-]+:[[:space:]]*/ { section = "" }
    END { flush() }
  ' "$EVALS" > "$EVAL_TMP"

  if [[ ! -s "$EVAL_TMP" ]]; then
    err "evals/cases.yaml has no cases"
  fi
  while IFS= read -r duplicate; do
    [[ -n "$duplicate" ]] && err "eval manifest has duplicate id: $duplicate"
  done < <(cut -d'|' -f1 "$EVAL_TMP" | sort | uniq -d)

  while IFS='|' read -r case_id skill kind execution prompt_chars must_count must_not_count; do
    if [[ ! "$case_id" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
      err "eval id '$case_id' must be kebab-case"
    fi
    if [[ -s "$CATALOG_TMP" ]] && ! awk -F'|' -v id="$skill" '$1 == id {found=1} END {exit !found}' "$CATALOG_TMP"; then
      err "$case_id: eval references unregistered skill '$skill'"
    fi
    case "$kind" in
      happy-path|edge|adversarial) ;;
      *) err "$case_id: eval kind must be happy-path, edge, or adversarial (found '$kind')" ;;
    esac
    case "$execution" in
      response|artifact) ;;
      *) err "$case_id: eval execution must be response or artifact (found '$execution')" ;;
    esac
    [[ "$prompt_chars" -ge 20 ]] || err "$case_id: eval prompt must contain at least 20 characters"
    [[ "$must_count" -ge 1 ]] || err "$case_id: eval needs at least one non-empty must criterion"
    [[ "$must_not_count" -ge 1 ]] || err "$case_id: eval needs at least one non-empty must_not criterion"
  done < "$EVAL_TMP"

  while IFS='|' read -r id path status hosts category tags summary_chars; do
    [[ "$status" == "active" ]] || continue
    eval_count="$(awk -F'|' -v skill="$id" '$2 == skill {count++} END {print count + 0}' "$EVAL_TMP")"
    happy_count="$(awk -F'|' -v skill="$id" '$2 == skill && $3 == "happy-path" {count++} END {print count + 0}' "$EVAL_TMP")"
    resilience_count="$(awk -F'|' -v skill="$id" '$2 == skill && $3 != "happy-path" {count++} END {print count + 0}' "$EVAL_TMP")"
    if [[ "$eval_count" -lt 3 ]]; then
      err "$id: active skill needs at least 3 behavioral evals (found $eval_count)"
    fi
    if [[ "$happy_count" -lt 1 ]]; then
      err "$id: active skill needs at least 1 happy-path eval (found $happy_count)"
    fi
    if [[ "$resilience_count" -lt 1 ]]; then
      err "$id: active skill needs at least 1 edge or adversarial eval (found $resilience_count)"
    fi
    if [[ "$eval_count" -ge 3 && "$happy_count" -ge 1 && "$resilience_count" -ge 1 ]]; then
      ok "$id: $eval_count behavioral evals ($happy_count happy-path, $resilience_count resilience)"
    fi
  done < "$CATALOG_TMP"
fi

echo "── routing evals ──"
ROUTING_TMP="$(mktemp "${TMPDIR:-/tmp}/zstack-routing-evals.XXXXXX")"
if [[ ! -f "$ROUTING_EVALS" ]]; then
  err "missing evals/routing.yaml"
else
  if ! grep -qE '^version:[[:space:]]*1[[:space:]]*$' "$ROUTING_EVALS"; then
    err "evals/routing.yaml must declare version: 1"
  fi
  awk '
    function clean(value) {
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      return value
    }
    function inspect_prompt(value) {
      prompt_chars += length(value)
      if (value ~ /(^|[^[:alnum:]_])\/?z-[a-z0-9-]+/) leaked_skill_id = 1
    }
    function flush() {
      if (id != "") print id "|" expected_skill "|" prompt_chars "|" leaked_skill_id
    }
    /^  - id:[[:space:]]*/ {
      flush()
      id = $0
      sub(/^  - id:[[:space:]]*/, "", id)
      expected_skill = ""
      prompt_chars = 0
      leaked_skill_id = 0
      in_prompt = 0
      next
    }
    id != "" && /^    prompt:[[:space:]]*/ {
      value = $0
      sub(/^    prompt:[[:space:]]*/, "", value)
      value = clean(value)
      if (value == ">-" || value == ">" || value == "|-" || value == "|") {
        in_prompt = 1
      } else {
        inspect_prompt(value)
        in_prompt = 0
      }
      next
    }
    id != "" && in_prompt && /^      / {
      inspect_prompt(clean($0))
      next
    }
    id != "" && /^    expected_skill:[[:space:]]*/ {
      expected_skill = $0
      sub(/^    expected_skill:[[:space:]]*/, "", expected_skill)
      in_prompt = 0
      next
    }
    id != "" && /^    [a-zA-Z0-9_-]+:[[:space:]]*/ { in_prompt = 0 }
    END { flush() }
  ' "$ROUTING_EVALS" > "$ROUTING_TMP"
  HAN_ROUTING_TMP="$(mktemp "${TMPDIR:-/tmp}/zstack-routing-han.XXXXXX")"
  if command -v ruby >/dev/null 2>&1; then
    ruby -ryaml -e '
      data = YAML.safe_load(File.read(ARGV.fetch(0)), aliases: false)
      data.fetch("cases").each do |entry|
        if entry.fetch("prompt").match?(/\p{Han}/)
          puts "#{entry.fetch("id")}|#{entry.fetch("expected_skill")}"
        end
      end
    ' "$ROUTING_EVALS" > "$HAN_ROUTING_TMP" 2>/dev/null || true
  fi

  if [[ ! -s "$ROUTING_TMP" ]]; then
    err "evals/routing.yaml has no cases"
  fi
  while IFS= read -r duplicate; do
    [[ -n "$duplicate" ]] && err "routing manifest has duplicate id: $duplicate"
  done < <(cut -d'|' -f1 "$ROUTING_TMP" | sort | uniq -d)

  while IFS='|' read -r case_id expected_skill prompt_chars leaked_skill_id; do
    if [[ ! "$case_id" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
      err "routing eval id '$case_id' must be kebab-case"
    fi
    if [[ "$expected_skill" != "none" ]] && {
      [[ ! -s "$CATALOG_TMP" ]] ||
      ! awk -F'|' -v id="$expected_skill" '$1 == id && $3 == "active" {found=1} END {exit !found}' "$CATALOG_TMP"
    }; then
      err "$case_id: routing eval references unknown or inactive skill '$expected_skill'"
    fi
    [[ "$prompt_chars" -ge 20 ]] || err "$case_id: routing prompt must contain at least 20 characters"
    [[ "$leaked_skill_id" -eq 0 ]] || err "$case_id: routing prompt must not name a z-* skill or use a host-specific invocation"
  done < "$ROUTING_TMP"

  han_routing_required=0
  while IFS='|' read -r id path status hosts category tags summary_chars; do
    [[ "$status" == "active" ]] || continue
    routing_count="$(awk -F'|' -v skill="$id" '$2 == skill {count++} END {print count + 0}' "$ROUTING_TMP")"
    if [[ "$routing_count" -lt 2 ]]; then
      err "$id: active skill needs at least 2 routing evals (found $routing_count)"
    else
      ok "$id: $routing_count routing evals"
    fi
    skill_description=""
    while IFS=$'\034' read -r record field_a field_b field_c field_d field_e field_f field_g field_h; do
      if [[ "$record" == "META" ]]; then
        skill_description="$field_f"
        break
      fi
    done < <(inspect_skill_file "$ROOT/$path/SKILL.md")
    if command -v ruby >/dev/null 2>&1 && printf '%s\n' "$skill_description" | grep -q '[一-鿿]'; then
      han_routing_required=1
      han_routing_count="$(awk -F'|' -v skill="$id" '$2 == skill {count++} END {print count + 0}' "$HAN_ROUTING_TMP")"
      if [[ "$han_routing_count" -lt 1 ]]; then
        err "$id: description advertises Chinese triggers but has no Chinese routing eval"
      else
        han_routing_label="evals"
        [[ "$han_routing_count" -eq 1 ]] && han_routing_label="eval"
        ok "$id: $han_routing_count Chinese routing $han_routing_label"
      fi
    fi
  done < "$CATALOG_TMP"

  no_match_count="$(awk -F'|' '$2 == "none" {count++} END {print count + 0}' "$ROUTING_TMP")"
  if [[ "$no_match_count" -lt 2 ]]; then
    err "routing manifest needs at least 2 no-match cases (found $no_match_count)"
  else
    ok "$no_match_count no-match routing evals"
  fi
  if [[ "$han_routing_required" -eq 1 ]]; then
    han_no_match_count="$(awk -F'|' '$2 == "none" {count++} END {print count + 0}' "$HAN_ROUTING_TMP")"
    if [[ "$han_no_match_count" -lt 1 ]]; then
      err "routing manifest needs at least 1 Chinese no-match case (found $han_no_match_count)"
    else
      ok "$han_no_match_count Chinese no-match routing evals"
    fi
  fi
fi

echo "── portability ──"
check_markdown_links
if portability_hits="$(grep -RInE 'mcp__[a-zA-Z0-9_-]+|/Users/[a-zA-Z0-9._-]+/|~/\.(claude|codex|grok)/skills/' "$ROOT/skills" 2>/dev/null)" && [[ -n "$portability_hits" ]]; then
  err "skills contain host-specific tool ids or machine-local skill paths"
  printf '%s\n' "$portability_hits" | sed -n '1,5p' >&2
else
  ok "skill content is free of machine-local and host-specific paths"
fi

SECRET_PATTERN='(^|[^a-zA-Z0-9])(sk-[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{20,}|AKIA[A-Z0-9]{16}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----)'
secret_hit=0
if command -v git >/dev/null 2>&1 && git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  # Scan only content Git could publish. Ignored local state may legitimately
  # contain credentials and should neither be read nor slow down doctor. Batch
  # regular files through NUL-safe xargs; archives can contain thousands of
  # files, so spawning grep once per candidate is slow and one giant argv does
  # not scale safely.
  if git -C "$ROOT" grep -I -E -q "$SECRET_PATTERN" -- . 2>/dev/null; then
    secret_hit=1
  else
    while IFS= read -r -d '' candidate; do
      candidate_path="$ROOT/$candidate"
      if [[ -L "$candidate_path" ]]; then
        if readlink "$candidate_path" | grep -E -q "$SECRET_PATTERN"; then
          secret_hit=1
          break
        fi
      fi
    done < <(git -C "$ROOT" ls-files --others --exclude-standard -z)
    if [[ "$secret_hit" -eq 0 ]]; then
      untracked_secret_bytes="$({
        git -C "$ROOT" ls-files --others --exclude-standard -z |
          while IFS= read -r -d '' candidate; do
            candidate_path="$ROOT/$candidate"
            [[ -f "$candidate_path" && ! -L "$candidate_path" ]] || continue
            printf '%s\0' "$candidate_path"
          done |
          xargs -0 grep -I -E -l "$SECRET_PATTERN" 2>/dev/null || true
      } | wc -c | tr -d '[:space:]')"
      if [[ "$untracked_secret_bytes" =~ ^[0-9]+$ && "$untracked_secret_bytes" -gt 0 ]]; then
        secret_hit=1
      fi
    fi
  fi
elif grep -RInE --exclude-dir=.git --exclude-dir=.gstack --exclude-dir=node_modules "$SECRET_PATTERN" "$ROOT" >/dev/null 2>&1; then
  secret_hit=1
fi

if [[ "$secret_hit" -eq 1 ]]; then
  err "possible secret detected in tracked or unignored repository content"
else
  ok "no obvious secrets in tracked or unignored repository content"
fi

if [[ "$SOURCE_ONLY" -eq 0 ]]; then
  zstack_require_safe_home
  echo "── links ──"
  state_dir_safe=1
  if ! state_dir_error="$(zstack_require_safe_state_dir "$HOME/.zstack" 2>&1)"; then
    err "$state_dir_error"
    state_dir_safe=0
  fi

  if [[ "$state_dir_safe" -eq 1 ]]; then
    root_record="$HOME/.zstack/root"
    if ! state_file_error="$(zstack_require_safe_state_file "$root_record" "zstack root record" 2>&1)"; then
      err "$state_file_error"
    else
      if [[ -f "$root_record" ]]; then
        ZROOT="$(cat "$root_record")"
        if ! zstack_is_manifest_safe_path "$ZROOT"; then
          warn "recorded ZSTACK_ROOT is unsafe"
        elif [[ "$ZROOT" == "$ROOT" ]]; then
          ok "recorded ZSTACK_ROOT=$ZROOT"
        else
          warn "recorded ZSTACK_ROOT differs: $(zstack_quote_for_log "$ZROOT")"
        fi
      else
        warn "no ~/.zstack/root yet — run setup.sh"
      fi
    fi

    link_manifest="$HOME/.zstack/links"
    if ! state_file_error="$(zstack_require_safe_state_file "$link_manifest" "zstack install manifest" 2>&1)"; then
      err "$state_file_error"
    elif [[ -f "$link_manifest" ]]; then
      tracked_links=0
      valid_tracked_links=0
      duplicate_manifest="$(sort "$link_manifest" | uniq -d | sed -n '1p')"
      [[ -z "$duplicate_manifest" ]] || warn "install manifest has duplicate entries"
      manifest_line_number=0
      while IFS= read -r manifest_line || [[ -n "$manifest_line" ]]; do
        manifest_line_number=$((manifest_line_number + 1))
        if ! zstack_is_manifest_line_safe "$manifest_line"; then
          if [[ "$manifest_line" == *"|"* ]]; then
            warn "install manifest line $manifest_line_number has unsafe path fields"
          else
            warn "install manifest line $manifest_line_number is malformed"
          fi
          continue
        fi
        recorded_root="${manifest_line%%|*}"
        recorded_link="${manifest_line#*|}"
        [[ "$recorded_root" == "$ROOT" ]] || continue
        tracked_links=$((tracked_links + 1))
        if [[ ! -L "$recorded_link" ]]; then
          warn "tracked link is missing or no longer a symlink: $recorded_link"
          continue
        fi
        if ! resolved_link="$(zstack_resolve_link_target "$recorded_link")"; then
          warn "tracked link target cannot be resolved: $recorded_link"
          continue
        fi
        case "$resolved_link" in
          "$ROOT/skills"/*)
            if [[ ! -d "$resolved_link" || "$(basename "$recorded_link")" != "$(basename "$resolved_link")" ]]; then
              warn "tracked link does not match a live skill: $recorded_link"
            else
              valid_tracked_links=$((valid_tracked_links + 1))
            fi
            ;;
          *) warn "tracked link points outside this zstack root: $recorded_link" ;;
        esac
      done < "$link_manifest"
      if [[ "$tracked_links" -eq 0 ]]; then
        warn "install manifest has no links for the current zstack root"
      elif [[ "$valid_tracked_links" -eq "$tracked_links" ]]; then
        ok "install manifest: $valid_tracked_links tracked links for current root"
      fi
    else
      warn "no ~/.zstack/links manifest yet — rerun setup.sh"
    fi
  fi

  for host_file in "$ROOT"/hosts/*.yaml; do
    [[ -f "$host_file" ]] || continue
    profile="$(zstack_host_profile "$host_file")"
    IFS='|' read -r hname _ skills_root _ enabled _ <<< "$profile"
    [[ "$enabled" == "false" ]] && continue
    hroot="$(zstack_expand_path "$skills_root")"
    if [[ ! -d "$hroot" ]]; then
      warn "host $hname root missing: $hroot"
      continue
    fi

    while IFS= read -r dir; do
      base="$(basename "$dir")"
      dest="$hroot/$base"
      if [[ -L "$dest" ]]; then
        if [[ -d "$dest" ]] && [[ "$(cd "$dest" && pwd -P)" == "$(cd "$dir" && pwd -P)" ]]; then
          ok "link $hname:$base"
        else
          link_target="$(readlink "$dest")"
          warn "link $hname:$base points elsewhere: $(zstack_quote_for_log "$link_target")"
        fi
      elif [[ -e "$dest" ]]; then
        warn "host $hname has non-link $base (not managed by zstack)"
      else
        warn "link $hname:$base is missing"
      fi
    done < <(zstack_active_skill_dirs "$CATALOG" "$ROOT" "$hname")
  done
fi

echo "── summary ──"
echo "errors=$ERRORS warnings=$WARNINGS"
[[ "$ERRORS" -eq 0 ]] || exit 1
