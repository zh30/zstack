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
DOCTOR_OPERATION_LOCK=""
CAPTURED_YAML_ARGUMENTS=()
WORKFLOW_SOURCE_PATHS=()
WORKFLOW_SOURCE_IDENTITIES=()
WORKFLOW_SOURCE_SNAPSHOTS=()
WORKFLOW_SOURCE_COUNT=0
WORKFLOW_SOURCES_READY=1
SKILL_TREE_STATE_BEFORE=""
SKILL_TREE_STATE_ENABLED=0
SKILL_TREE_SOURCE_READY=1
SKILL_TREE_CONTENT_READABLE=0
SKILL_TREE_SNAPSHOT_ROOT=""
SKILL_TREE_SNAPSHOT_IDENTITY=""
SKILL_CONTENT_ROOT="$ROOT/skills"
REPOSITORY_CANDIDATE_STATE_BEFORE=""
REPOSITORY_CANDIDATE_STATE_ENABLED=0
REPOSITORY_CANDIDATES_READY=1

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

doctor_remove_skill_tree_snapshot() {
  local snapshot_root="${SKILL_TREE_SNAPSHOT_ROOT:-}"
  local snapshot_identity="${SKILL_TREE_SNAPSHOT_IDENTITY:-}"

  [[ -n "$snapshot_root" && -n "$snapshot_identity" ]] || return 0
  ruby -I "$ROOT/scripts/lib" -r eval_owned_directory -e '
    device, inode = ARGV.fetch(1).split(":", 2).map { |value| Integer(value, 10) }
    identity = Zstack::EvalOwnedDirectory::Identity.new(dev: device, ino: inode).freeze
    exit(Zstack::EvalOwnedDirectory.remove_if_same(ARGV.fetch(0), identity) ? 0 : 1)
  ' "$snapshot_root" "$snapshot_identity" || return 1
  SKILL_TREE_SNAPSHOT_ROOT=""
  SKILL_TREE_SNAPSHOT_IDENTITY=""
}

cleanup_doctor() {
  if ! doctor_remove_skill_tree_snapshot; then
    echo "Could not remove the doctor skill-tree snapshot safely: $SKILL_TREE_SNAPSHOT_ROOT" >&2
  fi
  zstack_cleanup_identity_temp_files || true
  if [[ -n "${DOCTOR_OPERATION_LOCK:-}" ]]; then
    zstack_release_pid_lock "$DOCTOR_OPERATION_LOCK"
  fi
  return 0
}
trap cleanup_doctor EXIT

warn_non_private_state_path() {
  local path="$1"
  local label="$2"
  local mode=""

  [[ -e "$path" ]] || return 0
  if ! mode="$(zstack_file_mode_bits "$path")"; then
    warn "$label permissions could not be determined: $path"
  elif ! zstack_mode_is_owner_only "$mode"; then
    warn "$label permissions are $mode; rerun setup.sh to restrict local path metadata"
  fi
}

repository_candidates() {
  local candidate candidate_bytes
  local candidate_count=0
  local inventory_bytes=0
  local LC_ALL=C

  if command -v git >/dev/null 2>&1 && git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$ROOT" ls-files --cached --others --exclude-standard -z |
      while IFS= read -r -d '' candidate; do
        if repository_candidate_is_safe "$candidate" &&
           [[ ! -e "$ROOT/$candidate" && ! -L "$ROOT/$candidate" ]]; then
          continue
        fi
        candidate_count=$((candidate_count + 1))
        candidate_bytes=${#candidate}
        inventory_bytes=$((inventory_bytes + candidate_bytes + 1))
        if [[ "$candidate_count" -gt "$ZSTACK_REPOSITORY_CANDIDATE_MAX_FILES" ||
              "$inventory_bytes" -gt "$ZSTACK_REPOSITORY_CANDIDATE_MAX_INVENTORY_BYTES" ]]; then
          return 75
        fi
        printf '%s\0' "$candidate"
      done
  else
    (
      cd "$ROOT"
      find . \
        \( -type d \( -name '.git' -o -path './.gstack' -o -path './logs' -o \
           -name '.wrangler' -o -name 'node_modules' \) \) -prune -o \
        \( -path './.zstack-new-skill.*' -o -name '.DS_Store' -o -name '*.log' -o \
           -name '*.pid' -o -name '*.pid.lock' -o -name '.env' -o \
           \( -name '.env.*' ! -name '.env.example' \) -o -name '.dev.vars' -o \
           \( -name '.dev.vars.*' ! -name '.dev.vars.example' \) \) -prune -o \
        ! -type d -print0 |
        while IFS= read -r -d '' candidate; do
          candidate="${candidate#./}"
          candidate_count=$((candidate_count + 1))
          candidate_bytes=${#candidate}
          inventory_bytes=$((inventory_bytes + candidate_bytes + 1))
          if [[ "$candidate_count" -gt "$ZSTACK_REPOSITORY_CANDIDATE_MAX_FILES" ||
                "$inventory_bytes" -gt "$ZSTACK_REPOSITORY_CANDIDATE_MAX_INVENTORY_BYTES" ]]; then
            return 75
          fi
          printf '%s\0' "$candidate"
        done
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
  local referenced_files skill_text skill_inspection package_skill package_error
  base="${dir##*/}"

  if [[ ! -f "$skill_md" ]]; then
    err "$base: missing SKILL.md"
    return
  fi

  if [[ -n "${SKILL_PACKAGE_TMP:-}" && -f "$SKILL_PACKAGE_TMP" ]]; then
    while IFS=$'\034' read -r package_skill package_error; do
      [[ "$package_skill" == "$base" && -n "$package_error" ]] || continue
      err "$base: $package_error"
    done < "$SKILL_PACKAGE_TMP"
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
  if ! skill_inspection="$(inspect_skill_file "$skill_md")"; then
    err "$base: SKILL.md inspection failed"
    return
  fi
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
  done <<< "$skill_inspection"

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

repository_candidate_is_safe() {
  local candidate="$1"
  case "$candidate" in
    ""|/*|.|..|./*|*/.|*/./*|../*|*/..|*/../*|*//*) return 1 ;;
  esac
  if [[ "$candidate" =~ [[:cntrl:]] ||
        "$candidate" == [[:space:]]* ||
        "$candidate" == *[[:space:]] ]]; then
    return 1
  fi
  return 0
}

repository_candidates_pass_bash_preflight() {
  local candidates_file="$1"
  local candidate candidate_path candidate_uid file_bytes link_count symlink_target
  local total_bytes=0
  local LC_ALL=C

  while IFS= read -r -d '' candidate; do
    repository_candidate_is_safe "$candidate" || return 1
    candidate_path="$ROOT/$candidate"
    candidate_uid="$(zstack_file_uid "$candidate_path")" || return 1
    [[ "$candidate_uid" == "$EUID" ]] || return 1
    if [[ -L "$candidate_path" ]]; then
      symlink_target="$(readlink "$candidate_path")" || return 1
      file_bytes=${#symlink_target}
    elif [[ -f "$candidate_path" ]]; then
      link_count="$(zstack_file_link_count "$candidate_path")" || return 1
      [[ "$link_count" == "1" ]] || return 1
      file_bytes="$(zstack_file_size_bytes "$candidate_path")" || return 1
    else
      return 1
    fi
    [[ "$file_bytes" =~ ^[0-9]+$ ]] || return 1
    if [[ "$file_bytes" -gt "$ZSTACK_REPOSITORY_CANDIDATE_MAX_FILE_BYTES" ]]; then
      return 1
    fi
    total_bytes=$((total_bytes + file_bytes))
    if [[ "$total_bytes" -gt "$ZSTACK_REPOSITORY_CANDIDATE_MAX_BYTES" ]]; then
      return 1
    fi
  done < "$candidates_file"
}

skill_tree_passes_bash_content_preflight() {
  local skill_root="$ROOT/skills"
  local entry relative entry_uid file_bytes link_count
  local entry_count=0
  local file_count=0
  local total_bytes=0
  local LC_ALL=C

  [[ -d "$skill_root" && ! -L "$skill_root" ]] || return 1
  entry_uid="$(zstack_file_uid "$skill_root")" || return 1
  [[ "$entry_uid" == "$EUID" ]] || return 1

  find "$skill_root" -print0 |
    while IFS= read -r -d '' entry; do
      [[ "$entry" == "$skill_root" ]] && continue
      relative="${entry#"$skill_root"/}"
      repository_candidate_is_safe "$relative" || return 1
      entry_count=$((entry_count + 1))
      if [[ "$entry_count" -gt "$ZSTACK_SKILL_TREE_MAX_ENTRIES" ]]; then
        return 1
      fi

      if [[ -L "$entry" ]]; then
        return 1
      fi
      entry_uid="$(zstack_file_uid "$entry")" || return 1
      [[ "$entry_uid" == "$EUID" ]] || return 1
      if [[ -d "$entry" ]]; then
        continue
      elif [[ -f "$entry" ]]; then
        link_count="$(zstack_file_link_count "$entry")" || return 1
        [[ "$link_count" == "1" ]] || return 1
        file_bytes="$(zstack_file_size_bytes "$entry")" || return 1
        [[ "$file_bytes" =~ ^[0-9]+$ ]] || return 1
        if [[ "$file_bytes" -gt "$ZSTACK_SKILL_TREE_MAX_FILE_BYTES" ]]; then
          return 1
        fi
        file_count=$((file_count + 1))
        total_bytes=$((total_bytes + file_bytes))
        if [[ "$file_count" -gt "$ZSTACK_SKILL_TREE_MAX_FILES" ||
              "$total_bytes" -gt "$ZSTACK_SKILL_TREE_MAX_BYTES" ]]; then
          return 1
        fi
      else
        return 1
      fi
    done
}

report_secret_error() {
  local matches_file="$1"
  local match_path relative_path
  local match_count=0

  echo "ERROR: possible secret detected in tracked or unignored repository content" >&2
  ERRORS=$((ERRORS + 1))
  while IFS= read -r match_path; do
    case "$match_path" in
      "$ROOT"/*) relative_path="${match_path#"$ROOT"/}" ;;
      *) continue ;;
    esac
    repository_candidate_is_safe "$relative_path" || continue
    if [[ "$match_count" -ge 5 ]]; then
      printf '  ...\n' >&2
      break
    fi
    printf '  %s\n' "$relative_path" >&2
    match_count=$((match_count + 1))
  done < "$matches_file"
  if [[ "$FAIL_FAST" -eq 1 ]]; then
    exit 1
  fi
}

check_markdown_links() {
  local candidates_file="$1"
  local candidate md line_number raw target base

  if ! {
    while IFS= read -r -d '' candidate; do
      if ! repository_candidate_is_safe "$candidate"; then
        exit 74
      fi
      [[ "$candidate" == *.md ]] || continue
      [[ -f "$ROOT/$candidate" && ! -L "$ROOT/$candidate" ]] || continue
      printf '%s\0' "$candidate"
    done < "$candidates_file"
  } | {
    cd "$ROOT"
    # The single-quoted program is evaluated by the child sh.
    # shellcheck disable=SC2016
    xargs -0 sh -c '
      pattern=$1
      shift
      [ "$#" -gt 0 ] || exit 0
      grep -HnoE "$pattern" -- "$@"
      status=$?
      [ "$status" -le 1 ] || exit "$status"
      exit 0
    ' sh '\]\(([^)#]+)(#[^)]+)?\)'
  } > "$MARKDOWN_LINKS_TMP"; then
    err "Markdown link scan failed"
    return
  fi

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
  done < "$MARKDOWN_LINKS_TMP"
}

check_workflow_action_pins() {
  local workflow workflow_snapshot workflow_identity workflow_label
  local workflow_records line_number action_ref

  for workflow in "$ROOT"/.github/workflows/*.yml "$ROOT"/.github/workflows/*.yaml; do
    [[ -f "$workflow" ]] || continue
    workflow_label="${workflow#"$ROOT/"}"
    workflow_snapshot=""
    workflow_identity=""
    if ! zstack_capture_regular_file_snapshot \
      "$workflow" workflow_snapshot workflow_identity \
      "${TMPDIR:-/tmp}/zstack-doctor-workflow.XXXXXX"; then
      err "workflow source changed while doctor snapshotted $workflow_label"
      WORKFLOW_SOURCES_READY=0
      continue
    fi
    WORKFLOW_SOURCE_PATHS+=("$workflow")
    WORKFLOW_SOURCE_IDENTITIES+=("$workflow_identity")
    WORKFLOW_SOURCE_SNAPSHOTS+=("$workflow_snapshot")
    WORKFLOW_SOURCE_COUNT=$((WORKFLOW_SOURCE_COUNT + 1))
    CAPTURED_YAML_ARGUMENTS+=("$workflow_label" "$workflow_snapshot")
    if ! workflow_records="$(
      awk '
        /^[[:space:]]*(-[[:space:]]+)?uses:[[:space:]]*/ {
          value = $0
          sub(/^[[:space:]]*(-[[:space:]]+)?uses:[[:space:]]*/, "", value)
          sub(/[[:space:]]+#.*/, "", value)
          gsub(/^[\047\"]|[\047\"]$/, "", value)
          print NR "|" value
        }
      ' "$workflow_snapshot"
    )"; then
      err "workflow inspection failed for $workflow_label"
      continue
    fi
    [[ -n "$workflow_records" ]] || continue
    while IFS='|' read -r line_number action_ref; do
      [[ -n "$action_ref" ]] || continue
      case "$action_ref" in
        ./*) continue ;;
      esac
      if [[ ! "$action_ref" =~ ^[^[:space:]#]+@[0-9a-f]{40}$ ]]; then
        err "workflow action must use a full immutable commit SHA in $workflow_label:$line_number: $action_ref"
      fi
    done <<< "$workflow_records"
  done
}

doctor_workflow_sources_are_unchanged() {
  local workflow_source_index=0

  for ((workflow_source_index = 0; workflow_source_index < WORKFLOW_SOURCE_COUNT; workflow_source_index++)); do
    zstack_regular_file_snapshot_is_unchanged \
      "${WORKFLOW_SOURCE_PATHS[$workflow_source_index]}" \
      "${WORKFLOW_SOURCE_IDENTITIES[$workflow_source_index]}" \
      "${WORKFLOW_SOURCE_SNAPSHOTS[$workflow_source_index]}" || return 1
  done
}

if command -v ruby >/dev/null 2>&1; then
  SKILL_TREE_STATE_ENABLED=1
  if ! SKILL_TREE_STATE_BEFORE="$(
    ruby "$ROOT/scripts/capture-skill-tree-state.rb" "$ROOT/skills" 2>&1
  )"; then
    printf '%s\n' "$SKILL_TREE_STATE_BEFORE" >&2
    err "skill tree baseline could not be captured"
    SKILL_TREE_SOURCE_READY=0
  else
    SKILL_TREE_CONTENT_READABLE=1
  fi
elif skill_tree_passes_bash_content_preflight; then
  SKILL_TREE_CONTENT_READABLE=1
else
  err "skill tree content preflight could not be validated"
  SKILL_TREE_SOURCE_READY=0
fi

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
if [[ "$WORKFLOW_SOURCES_READY" -eq 1 ]] && ! doctor_workflow_sources_are_unchanged; then
  err "workflow sources changed while doctor validated captured workflows"
  WORKFLOW_SOURCES_READY=0
fi
if [[ "$ERRORS" -eq "$workflow_errors" ]]; then
  ok "GitHub Actions use immutable commit references"
fi

echo "── catalog ──"
CATALOG_TMP=""
CATALOG_SOURCE_TMP=""
CATALOG_SOURCE_IDENTITY=""
CATALOG_SOURCE_READY=0
EVAL_TMP=""
EVAL_SOURCE_TMP=""
EVAL_SOURCE_IDENTITY=""
EVAL_SOURCE_READY=0
ROUTING_TMP=""
ROUTING_SOURCE_TMP=""
ROUTING_SOURCE_IDENTITY=""
ROUTING_SOURCE_READY=0
HAN_ROUTING_TMP=""
HAN_SKILL_TMP=""
SKILL_PACKAGE_TMP=""
HANDOFF_SHAPE_TMP=""
REPOSITORY_CANDIDATES_TMP=""
REPOSITORY_CANDIDATES_FINAL_TMP=""
MARKDOWN_LINKS_TMP=""
SECRET_REGULAR_TMP=""
SECRET_MATCHES_TMP=""
ROOT_RECORD_AUDIT_TMP=""
ROOT_RECORD_AUDIT_IDENTITY=""
ROOT_RECORD_AUDIT_PRESENT=0
ROOT_RECORD_AUDIT_TRACKED=0
LINK_MANIFEST_AUDIT_TMP=""
LINK_MANIFEST_AUDIT_IDENTITY=""
LINK_MANIFEST_AUDIT_PRESENT=0
LINK_MANIFEST_AUDIT_TRACKED=0
HOST_PROFILES_TMP=""
HOST_SOURCE_PATHS=()
HOST_SOURCE_IDENTITIES=()
HOST_SOURCE_SNAPSHOTS=()
HOST_SOURCE_COUNT=0
HOST_SOURCES_READY=1
host_source_identity=""
host_source_snapshot=""
CATALOG_REGISTERED_IDS=","
doctor_make_temp_file() {
  zstack_make_identity_temp_file "$1" "$2"
}
doctor_state_audit_source_is_unchanged() {
  local source_path="$1"
  local source_present="$2"
  local source_identity="$3"
  local snapshot_path="$4"

  if [[ "$source_present" -eq 0 ]]; then
    [[ ! -e "$source_path" && ! -L "$source_path" ]]
    return
  fi
  zstack_regular_file_snapshot_is_unchanged \
    "$source_path" "$source_identity" "$snapshot_path"
}
doctor_host_sources_are_unchanged() {
  local host_source_index=0

  for ((host_source_index = 0; host_source_index < HOST_SOURCE_COUNT; host_source_index++)); do
    zstack_regular_file_snapshot_is_unchanged \
      "${HOST_SOURCE_PATHS[$host_source_index]}" \
      "${HOST_SOURCE_IDENTITIES[$host_source_index]}" \
      "${HOST_SOURCE_SNAPSHOTS[$host_source_index]}" || return 1
  done
}

doctor_make_temp_file CATALOG_TMP "${TMPDIR:-/tmp}/zstack-catalog.XXXXXX"
doctor_make_temp_file HAN_SKILL_TMP "${TMPDIR:-/tmp}/zstack-skill-han.XXXXXX"
doctor_make_temp_file HOST_PROFILES_TMP "${TMPDIR:-/tmp}/zstack-doctor-hosts.XXXXXX"
if [[ "$SKILL_TREE_CONTENT_READABLE" -eq 1 ]]; then
  if [[ "$SKILL_TREE_STATE_ENABLED" -eq 1 ]]; then
    skill_tree_state_before_content=""
    if ! SKILL_TREE_SNAPSHOT_ROOT="$(
      mktemp -d "${TMPDIR:-/tmp}/zstack-doctor-skill-tree-snapshot.XXXXXX"
    )" || ! SKILL_TREE_SNAPSHOT_IDENTITY="$(zstack_file_identity "$SKILL_TREE_SNAPSHOT_ROOT")" ||
       ! chmod 700 "$SKILL_TREE_SNAPSHOT_ROOT"; then
      err "skill tree content snapshot could not be allocated; skill content checks were skipped"
      SKILL_TREE_CONTENT_READABLE=0
      SKILL_TREE_SOURCE_READY=0
    elif ! skill_tree_state_before_content="$(
      ruby "$ROOT/scripts/capture-skill-tree-state.rb" \
        --snapshot "$SKILL_TREE_SNAPSHOT_ROOT" "$ROOT/skills" 2>&1
    )"; then
      printf '%s\n' "$skill_tree_state_before_content" >&2
      err "skill tree changed before content validation; skill content checks were skipped"
      SKILL_TREE_CONTENT_READABLE=0
      SKILL_TREE_SOURCE_READY=0
    elif [[ "$skill_tree_state_before_content" != "$SKILL_TREE_STATE_BEFORE" ]]; then
      err "skill tree changed before content validation; skill content checks were skipped"
      SKILL_TREE_CONTENT_READABLE=0
      SKILL_TREE_SOURCE_READY=0
    else
      SKILL_CONTENT_ROOT="$SKILL_TREE_SNAPSHOT_ROOT"
    fi
  elif ! skill_tree_passes_bash_content_preflight; then
    err "skill tree content preflight changed before validation; skill content checks were skipped"
    SKILL_TREE_CONTENT_READABLE=0
    SKILL_TREE_SOURCE_READY=0
  fi
fi

if [[ "$SKILL_TREE_CONTENT_READABLE" -eq 1 ]] && command -v ruby >/dev/null 2>&1; then
  doctor_make_temp_file SKILL_PACKAGE_TMP "${TMPDIR:-/tmp}/zstack-skill-packages.XXXXXX"
  if ! ruby -I "$ROOT/scripts/lib" -r eval_limits -e '
    separator = "\x1c"
    Dir.glob(File.join(ARGV.fetch(0), "*/")).sort.each do |directory|
      skill = File.basename(directory)
      begin
        Zstack::EvalLimits.skill_package_errors(directory).each do |error|
          puts [skill, error].join(separator)
        end
      rescue StandardError => e
        puts [skill, "skill package limits could not be checked: #{e.class}: #{e.message}"].join(separator)
      end
    end
  ' "$SKILL_CONTENT_ROOT" > "$SKILL_PACKAGE_TMP"; then
    err "skill package limit checks could not be prepared"
  fi

  doctor_make_temp_file HANDOFF_SHAPE_TMP "${TMPDIR:-/tmp}/zstack-handoff-shapes.XXXXXX"
  if ! ruby -I "$ROOT/scripts/lib" -ryaml -r evidence_handoff_contract -e '
    root = ARGV.fetch(0)
    han_path = ARGV.fetch(1)
    File.open(han_path, "w", 0o600) do |han_file|
      Dir.glob(File.join(root, "*", "SKILL.md")).sort.each do |path|
        next unless File.file?(path) && !File.symlink?(path)

        content = File.read(path)
        match = content.match(/\A---[ \t]*\r?\n(.*?)\r?\n---[ \t]*(?:\r?\n|\z)/m)
        next unless match

        begin
          metadata = YAML.safe_load(match[1], aliases: false)
          description = metadata.is_a?(Hash) ? metadata["description"].to_s : ""
          han_file.puts(File.basename(File.dirname(path))) if description.match?(/\p{Han}/)
        rescue Psych::Exception
          # The dedicated YAML validator reports malformed frontmatter.
        end
      end
    end

    Dir.glob(File.join(root, "**", "*.md")).sort.each do |path|
      next unless File.file?(path) && !File.symlink?(path)

      result = Zstack::EvidenceHandoffContract.evaluate([{ name: path, path: path }])
      puts path if result.fetch("passed")
    end
  ' "$SKILL_CONTENT_ROOT" "$HAN_SKILL_TMP" > "$HANDOFF_SHAPE_TMP"; then
    err "Evidence handoff table-shape checks could not be prepared"
  fi
fi
if [[ ! -f "$CATALOG" || -L "$CATALOG" ]]; then
  err "missing catalog.yaml"
else
  if ! zstack_capture_regular_file_snapshot \
    "$CATALOG" CATALOG_SOURCE_TMP CATALOG_SOURCE_IDENTITY \
    "${TMPDIR:-/tmp}/zstack-doctor-catalog-source.XXXXXX"; then
    err "catalog.yaml changed while doctor snapshotted it"
  else
    CATALOG_SOURCE_READY=1
    CAPTURED_YAML_ARGUMENTS+=("catalog.yaml" "$CATALOG_SOURCE_TMP")
  fi
fi

if [[ "$CATALOG_SOURCE_READY" -eq 1 ]]; then
  if grep -qE '^version:[[:space:]]*1[[:space:]]*$' "$CATALOG_SOURCE_TMP"; then
    ok "catalog version 1"
  else
    err "catalog.yaml must declare version: 1"
  fi

  if ! zstack_catalog_entries "$CATALOG_SOURCE_TMP" > "$CATALOG_TMP"; then
    err "catalog.yaml entry parsing failed"
    CATALOG_SOURCE_READY=0
  fi

  if [[ ! -s "$CATALOG_TMP" ]]; then
    err "catalog.yaml has no skill entries"
  fi

  while IFS='|' read -r id path status hosts category tags summary_chars; do
    [[ -n "$id" ]] || { err "catalog entry missing id"; continue; }
    if [[ "$CATALOG_REGISTERED_IDS" == *",$id,"* ]]; then
      err "catalog has duplicate id: $id"
    else
      CATALOG_REGISTERED_IDS="${CATALOG_REGISTERED_IDS}${id},"
    fi
    if [[ ! "$id" =~ ^z-[a-z0-9]([a-z0-9-]{0,60}[a-z0-9])?$ ]]; then
      err "catalog id '$id' violates z- naming policy"
    fi
    skill_content_dir="$SKILL_CONTENT_ROOT/$id"
    if [[ "$path" != "skills/$id" ]]; then
      err "$id: catalog path must be skills/$id (found '$path')"
    elif [[ ! -d "$skill_content_dir" ]]; then
      err "$id: catalog path does not exist: $path"
    fi
    case "$status" in
      active|draft|deprecated) ;;
      *) err "$id: invalid catalog status '$status'" ;;
    esac
    if [[ "$status" == "active" && -d "$skill_content_dir" &&
          "$SKILL_TREE_CONTENT_READABLE" -eq 1 ]]; then
      quality_bar="$skill_content_dir/references/quality-bar.md"
      if [[ ! -f "$quality_bar" ]]; then
        err "$id: active skill requires references/quality-bar.md"
      else
        if ! grep -Fq 'references/quality-bar.md' "$skill_content_dir/SKILL.md"; then
          err "$id: quality bar must be linked directly from SKILL.md"
        fi
        if ! grep -qi 'evidence handoff' "$quality_bar"; then
          err "$id: quality bar must check the evidence handoff"
        fi
      fi
      if ! grep -rqsE '^## ([0-9]+\.)?[[:space:]]*Evidence handoff[[:space:]]*$' "$skill_content_dir"; then
        err "$id: primary output template must include an Evidence handoff section"
      else
        handoff_heading_found=0
        handoff_complete=0
        handoff_missing=""
        handoff_classes_missing=""
        handoff_shape_invalid=0
        if handoff_candidates="$(find "$skill_content_dir" -type f -name '*.md' -print | sort)"; then
          if [[ -n "$handoff_candidates" ]]; then
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
                if ! command -v ruby >/dev/null 2>&1; then
                  handoff_complete=1
                  break
                elif grep -Fqx -- "$handoff_candidate" "$HANDOFF_SHAPE_TMP"; then
                  handoff_complete=1
                  break
                fi
                handoff_shape_invalid=1
              fi
              [[ -n "$handoff_missing" ]] || handoff_missing="$candidate_missing"
              [[ -n "$handoff_classes_missing" ]] || handoff_classes_missing="$candidate_classes_missing"
            done <<< "$handoff_candidates"
          fi
        else
          err "$id: Evidence handoff file enumeration failed"
        fi
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
      if ! grep -Fq 'Evidence does not upgrade on handoff' "$skill_content_dir/SKILL.md"; then
        err "$id: SKILL.md must preserve evidence class across handoffs"
      fi
      if ! grep -Fq 'The handoff is a fixed interface.' "$skill_content_dir/SKILL.md"; then
        err "$id: SKILL.md must define Evidence handoff as a fixed interface"
      fi
      if ! grep -Fq 'two-column' "$skill_content_dir/SKILL.md" || ! grep -Fq 'Field | Value' "$skill_content_dir/SKILL.md"; then
        err "$id: SKILL.md must require one two-column Field | Value Evidence handoff"
      fi
      if ! grep -Fq 'Never leave the class cell empty.' "$skill_content_dir/SKILL.md"; then
        err "$id: SKILL.md must require a non-empty Evidence classes cell"
      fi
      runtime_handoff_flat="$(tr '\n' ' ' < "$skill_content_dir/SKILL.md" | tr -s '[:space:]' ' ')"
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
      old_ifs="$IFS"
      IFS=','
      has_indie_tag=0
      seen_tags=","
      for tag in $tags; do
        if [[ "$seen_tags" == *",$tag,"* ]]; then
          err "$id: duplicate catalog tag '$tag'"
        else
          seen_tags="${seen_tags}${tag},"
        fi
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
      old_ifs="$IFS"
      IFS=','
      seen_hosts=","
      for host in $hosts; do
        if [[ "$seen_hosts" == *",$host,"* ]]; then
          err "$id: duplicate host '$host'"
        else
          seen_hosts="${seen_hosts}${host},"
        fi
        if [[ ! -f "$ROOT/hosts/$host.yaml" ]]; then
          err "$id: unknown host '$host'"
        fi
      done
      IFS="$old_ifs"
    fi
  done < "$CATALOG_TMP"
  if grep -qE '(^|[^[:alnum:]_])TODO([^[:alnum:]_]|$)' "$CATALOG_SOURCE_TMP"; then
    err "catalog.yaml still contains TODO placeholder content"
  fi
  if [[ "$CATALOG_SOURCE_READY" -eq 1 ]] &&
     ! zstack_regular_file_snapshot_is_unchanged \
       "$CATALOG" "$CATALOG_SOURCE_IDENTITY" "$CATALOG_SOURCE_TMP"; then
    err "catalog.yaml changed while doctor validated the captured catalog"
    CATALOG_SOURCE_READY=0
  fi
fi

echo "── hosts ──"
for host_file in "$ROOT"/hosts/*.yaml; do
  [[ -f "$host_file" ]] || continue
  expected_host="$(basename "$host_file" .yaml)"
  profile_errors="$ERRORS"
  if [[ -L "$host_file" ]]; then
    err "$expected_host: host profile source must be a real regular file"
    HOST_SOURCES_READY=0
    continue
  fi
  if ! zstack_capture_regular_file_snapshot \
    "$host_file" host_source_snapshot host_source_identity \
    "${TMPDIR:-/tmp}/zstack-doctor-host.XXXXXX"; then
    err "$expected_host: host profile source changed while it was snapshotted"
    HOST_SOURCES_READY=0
    continue
  fi
  HOST_SOURCE_PATHS+=("$host_file")
  HOST_SOURCE_IDENTITIES+=("$host_source_identity")
  HOST_SOURCE_SNAPSHOTS+=("$host_source_snapshot")
  HOST_SOURCE_COUNT=$((HOST_SOURCE_COUNT + 1))
  CAPTURED_YAML_ARGUMENTS+=("hosts/$(basename "$host_file")" "$host_source_snapshot")
  if ! profile="$(zstack_host_profile "$host_source_snapshot")"; then
    err "$expected_host: host profile parsing failed"
    HOST_SOURCES_READY=0
    continue
  fi
  printf '%s|%s\n' "$expected_host" "$profile" >> "$HOST_PROFILES_TMP"
  IFS='|' read -r declared_host display_name skills_root link_mode enabled description_max required_name required_description <<< "$profile"

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
if [[ "$HOST_SOURCES_READY" -eq 1 ]] && ! doctor_host_sources_are_unchanged; then
  err "host profile sources changed while doctor validated the captured profiles"
  HOST_SOURCES_READY=0
fi

echo "── skills ──"
if ! command -v ruby >/dev/null 2>&1; then
  warn "ruby is unavailable; skipped skill package limits, cross-phase skill-tree stability, and strict Evidence handoff table-shape checks"
fi
if [[ "$SKILL_TREE_CONTENT_READABLE" -eq 1 ]]; then
  shopt -s nullglob
  for dir in "$SKILL_CONTENT_ROOT"/*/; do
    dir="${dir%/}"
    base="$(basename "$dir")"
    if [[ "$base" == "_template" ]]; then
      check_skill "$dir" "z-skill-name"
      continue
    fi
    check_skill "$dir" "$base"
    if [[ -f "${CATALOG_TMP:-}" ]]; then
      if [[ "$CATALOG_REGISTERED_IDS" != *",$base,"* ]]; then
        err "$base: missing from catalog.yaml"
      else
        ok "$base: registered in catalog"
      fi
    fi
  done
fi

if [[ -f "${CATALOG_TMP:-}" ]]; then
  while IFS='|' read -r id path status hosts category tags summary_chars; do
    [[ -d "$SKILL_CONTENT_ROOT/$id" ]] || err "$id: catalog entry has no matching skill directory"
  done < "$CATALOG_TMP"
fi

echo "── evals ──"
doctor_make_temp_file EVAL_TMP "${TMPDIR:-/tmp}/zstack-evals.XXXXXX"
if [[ ! -f "$EVALS" || -L "$EVALS" ]]; then
  err "missing evals/cases.yaml"
else
  if ! zstack_capture_regular_file_snapshot \
    "$EVALS" EVAL_SOURCE_TMP EVAL_SOURCE_IDENTITY \
    "${TMPDIR:-/tmp}/zstack-doctor-evals-source.XXXXXX"; then
    err "evals/cases.yaml changed while doctor snapshotted it"
  else
    EVAL_SOURCE_READY=1
    CAPTURED_YAML_ARGUMENTS+=("evals/cases.yaml" "$EVAL_SOURCE_TMP")
  fi
fi

if [[ "$EVAL_SOURCE_READY" -eq 1 ]]; then
  if ! grep -qE '^version:[[:space:]]*1[[:space:]]*$' "$EVAL_SOURCE_TMP"; then
    err "evals/cases.yaml must declare version: 1"
  fi
  contract_must_count="$(awk '
    /^contract_must:[[:space:]]*$/ { section = 1; next }
    section && /^[^[:space:]]/ { section = 0 }
    section && /^  -[[:space:]]*[^[:space:]]/ { count++ }
    END { print count + 0 }
  ' "$EVAL_SOURCE_TMP")"
  if [[ "$contract_must_count" -lt 1 ]]; then
    err "evals/cases.yaml needs at least one shared contract_must criterion"
  fi
  if ! grep -Fq 'Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names.' "$EVAL_SOURCE_TMP"; then
    err "evals/cases.yaml must test the fixed Evidence handoff contract for every case"
  fi
  if ! grep -Fq 'Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence.' "$EVAL_SOURCE_TMP"; then
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
  ' "$EVAL_SOURCE_TMP" > "$EVAL_TMP"

  if [[ ! -s "$EVAL_TMP" ]]; then
    err "evals/cases.yaml has no cases"
  fi
  if unregistered_eval_refs="$(
    awk -F'|' -v catalog="$CATALOG_TMP" '
      FILENAME == catalog { registered[$1] = 1; catalog_count++; next }
      catalog_count > 0 && !($2 in registered) { print $1 "|" $2 }
    ' "$CATALOG_TMP" "$EVAL_TMP"
  )"; then
    if [[ -n "$unregistered_eval_refs" ]]; then
      while IFS='|' read -r case_id skill; do
        err "$case_id: eval references unregistered skill '$skill'"
      done <<< "$unregistered_eval_refs"
    fi
  else
    err "eval registration checks could not be prepared"
  fi

  EVAL_SEEN_IDS=","
  while IFS='|' read -r case_id skill kind execution prompt_chars must_count must_not_count; do
    if [[ "$EVAL_SEEN_IDS" == *",$case_id,"* ]]; then
      err "eval manifest has duplicate id: $case_id"
    else
      EVAL_SEEN_IDS="${EVAL_SEEN_IDS}${case_id},"
    fi
    if [[ ! "$case_id" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
      err "eval id '$case_id' must be kebab-case"
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

  if behavioral_stats="$(
    awk -F'|' -v catalog="$CATALOG_TMP" '
      FILENAME == catalog {
        if ($3 == "active") order[++skill_count] = $1
        next
      }
      {
        eval_count[$2]++
        if ($3 == "happy-path") happy_count[$2]++
        else resilience_count[$2]++
      }
      END {
        for (i = 1; i <= skill_count; i++) {
          skill = order[i]
          print skill "|" (eval_count[skill] + 0) "|" (happy_count[skill] + 0) "|" (resilience_count[skill] + 0)
        }
      }
    ' "$CATALOG_TMP" "$EVAL_TMP"
  )"; then
    if [[ -n "$behavioral_stats" ]]; then
      while IFS='|' read -r id eval_count happy_count resilience_count; do
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
      done <<< "$behavioral_stats"
    fi
  else
    err "behavioral eval coverage checks could not be prepared"
  fi
  if ! zstack_regular_file_snapshot_is_unchanged \
    "$EVALS" "$EVAL_SOURCE_IDENTITY" "$EVAL_SOURCE_TMP"; then
    err "evals/cases.yaml changed while doctor validated the captured behavioral manifest"
    EVAL_SOURCE_READY=0
  fi
fi

echo "── routing evals ──"
doctor_make_temp_file ROUTING_TMP "${TMPDIR:-/tmp}/zstack-routing-evals.XXXXXX"
if [[ ! -f "$ROUTING_EVALS" || -L "$ROUTING_EVALS" ]]; then
  err "missing evals/routing.yaml"
else
  if ! zstack_capture_regular_file_snapshot \
    "$ROUTING_EVALS" ROUTING_SOURCE_TMP ROUTING_SOURCE_IDENTITY \
    "${TMPDIR:-/tmp}/zstack-doctor-routing-source.XXXXXX"; then
    err "evals/routing.yaml changed while doctor snapshotted it"
  else
    ROUTING_SOURCE_READY=1
    CAPTURED_YAML_ARGUMENTS+=("evals/routing.yaml" "$ROUTING_SOURCE_TMP")
  fi
fi

if [[ "$ROUTING_SOURCE_READY" -eq 1 ]]; then
  if ! grep -qE '^version:[[:space:]]*1[[:space:]]*$' "$ROUTING_SOURCE_TMP"; then
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
  ' "$ROUTING_SOURCE_TMP" > "$ROUTING_TMP"
  doctor_make_temp_file HAN_ROUTING_TMP "${TMPDIR:-/tmp}/zstack-routing-han.XXXXXX"
  if command -v ruby >/dev/null 2>&1; then
    if ! ruby -ryaml -e '
      data = YAML.safe_load(File.read(ARGV.fetch(0)), aliases: false)
      data.fetch("cases").each do |entry|
        if entry.fetch("prompt").match?(/\p{Han}/)
          puts "#{entry.fetch("id")}|#{entry.fetch("expected_skill")}"
        end
      end
    ' "$ROUTING_SOURCE_TMP" > "$HAN_ROUTING_TMP" 2>/dev/null; then
      err "Chinese routing checks could not be prepared"
    fi
  fi

  if [[ ! -s "$ROUTING_TMP" ]]; then
    err "evals/routing.yaml has no cases"
  fi
  if invalid_routing_refs="$(
    awk -F'|' -v catalog="$CATALOG_TMP" '
      FILENAME == catalog { if ($3 == "active") active[$1] = 1; next }
      $2 != "none" && !($2 in active) { print $1 "|" $2 }
    ' "$CATALOG_TMP" "$ROUTING_TMP"
  )"; then
    if [[ -n "$invalid_routing_refs" ]]; then
      while IFS='|' read -r case_id expected_skill; do
        err "$case_id: routing eval references unknown or inactive skill '$expected_skill'"
      done <<< "$invalid_routing_refs"
    fi
  else
    err "routing registration checks could not be prepared"
  fi

  ROUTING_SEEN_IDS=","
  while IFS='|' read -r case_id expected_skill prompt_chars leaked_skill_id; do
    if [[ "$ROUTING_SEEN_IDS" == *",$case_id,"* ]]; then
      err "routing manifest has duplicate id: $case_id"
    else
      ROUTING_SEEN_IDS="${ROUTING_SEEN_IDS}${case_id},"
    fi
    if [[ ! "$case_id" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
      err "routing eval id '$case_id' must be kebab-case"
    fi
    [[ "$prompt_chars" -ge 20 ]] || err "$case_id: routing prompt must contain at least 20 characters"
    [[ "$leaked_skill_id" -eq 0 ]] || err "$case_id: routing prompt must not name a z-* skill or use a host-specific invocation"
  done < "$ROUTING_TMP"

  han_routing_required=0
  no_match_count=0
  han_no_match_count=0
  if routing_stats="$(
    awk -F'|' \
      -v catalog="$CATALOG_TMP" \
      -v routing="$ROUTING_TMP" \
      -v han_routing="$HAN_ROUTING_TMP" \
      -v han_skills="$HAN_SKILL_TMP" '
      FILENAME == catalog {
        if ($3 == "active") order[++skill_count] = $1
        next
      }
      FILENAME == routing { routing_count[$2]++; next }
      FILENAME == han_routing { han_routing_count[$2]++; next }
      FILENAME == han_skills { han_required[$1] = 1; next }
      END {
        for (i = 1; i <= skill_count; i++) {
          skill = order[i]
          print "SKILL|" skill "|" (routing_count[skill] + 0) "|" (han_routing_count[skill] + 0) "|" (han_required[skill] + 0)
        }
        print "NONE|none|" (routing_count["none"] + 0) "|" (han_routing_count["none"] + 0) "|0"
      }
    ' "$CATALOG_TMP" "$ROUTING_TMP" "$HAN_ROUTING_TMP" "$HAN_SKILL_TMP"
  )"; then
    while IFS='|' read -r record id routing_count han_routing_count han_required; do
      if [[ "$record" == "NONE" ]]; then
        no_match_count="$routing_count"
        han_no_match_count="$han_routing_count"
        continue
      fi
      if [[ "$routing_count" -lt 2 ]]; then
        err "$id: active skill needs at least 2 routing evals (found $routing_count)"
      else
        ok "$id: $routing_count routing evals"
      fi
      if [[ "$han_required" -eq 1 ]]; then
        han_routing_required=1
        if [[ "$han_routing_count" -lt 1 ]]; then
          err "$id: description advertises Chinese triggers but has no Chinese routing eval"
        else
          han_routing_label="evals"
          [[ "$han_routing_count" -eq 1 ]] && han_routing_label="eval"
          ok "$id: $han_routing_count Chinese routing $han_routing_label"
        fi
      fi
    done <<< "$routing_stats"
  else
    err "routing eval coverage checks could not be prepared"
  fi

  if [[ "$no_match_count" -lt 2 ]]; then
    err "routing manifest needs at least 2 no-match cases (found $no_match_count)"
  else
    ok "$no_match_count no-match routing evals"
  fi
  if [[ "$han_routing_required" -eq 1 ]]; then
    if [[ "$han_no_match_count" -lt 1 ]]; then
      err "routing manifest needs at least 1 Chinese no-match case (found $han_no_match_count)"
    else
      ok "$han_no_match_count Chinese no-match routing evals"
    fi
  fi
  if ! zstack_regular_file_snapshot_is_unchanged \
    "$ROUTING_EVALS" "$ROUTING_SOURCE_IDENTITY" "$ROUTING_SOURCE_TMP"; then
    err "evals/routing.yaml changed while doctor validated the captured routing manifest"
    ROUTING_SOURCE_READY=0
  fi
fi

if command -v ruby >/dev/null 2>&1 && [[ "${#CAPTURED_YAML_ARGUMENTS[@]}" -gt 0 ]]; then
  echo "── captured yaml ──"
  if captured_yaml_result="$(
    ruby "$ROOT/scripts/validate-yaml.rb" \
      --documents "${CAPTURED_YAML_ARGUMENTS[@]}" 2>&1
  )"; then
    ok "$captured_yaml_result"
  else
    printf '%s\n' "$captured_yaml_result" >&2
    err "captured source strict YAML validation failed"
  fi
fi

echo "── portability ──"
doctor_make_temp_file REPOSITORY_CANDIDATES_TMP "${TMPDIR:-/tmp}/zstack-repository-candidates.XXXXXX"
doctor_make_temp_file MARKDOWN_LINKS_TMP "${TMPDIR:-/tmp}/zstack-markdown-links.XXXXXX"
candidate_inventory_ready=0
if repository_candidates > "$REPOSITORY_CANDIDATES_TMP"; then
  candidate_inventory_ready=1
  if command -v ruby >/dev/null 2>&1; then
    REPOSITORY_CANDIDATE_STATE_ENABLED=1
    if ! REPOSITORY_CANDIDATE_STATE_BEFORE="$(
      ruby "$ROOT/scripts/capture-repository-candidate-state.rb" \
        "$ROOT" "$REPOSITORY_CANDIDATES_TMP" 2>&1
    )"; then
      printf '%s\n' "$REPOSITORY_CANDIDATE_STATE_BEFORE" >&2
      err "repository candidate baseline could not be captured"
      REPOSITORY_CANDIDATES_READY=0
    fi
  else
    if repository_candidates_pass_bash_preflight "$REPOSITORY_CANDIDATES_TMP"; then
      warn "ruby is unavailable; skipped cross-phase repository candidate stability checks"
    else
      err "repository candidate preflight could not be validated"
      candidate_inventory_ready=0
      REPOSITORY_CANDIDATES_READY=0
    fi
  fi
  if [[ "$candidate_inventory_ready" -eq 1 ]]; then
    check_markdown_links "$REPOSITORY_CANDIDATES_TMP"
  fi
else
  err "repository candidate inventory failed"
  REPOSITORY_CANDIDATES_READY=0
fi
if [[ "$SKILL_TREE_CONTENT_READABLE" -eq 1 ]]; then
  if portability_hits="$(grep -rInE 'mcp__[a-zA-Z0-9_-]+|/Users/[a-zA-Z0-9._-]+/|~/\.(claude|codex|grok)/skills/' "$SKILL_CONTENT_ROOT" 2>/dev/null)"; then
    if [[ -n "$portability_hits" ]]; then
      err "skills contain host-specific tool ids or machine-local skill paths"
      printf '%s\n' "$portability_hits" | sed -n '1,5p' >&2
    else
      ok "skill content is free of machine-local and host-specific paths"
    fi
  else
    portability_status=$?
    if [[ "$portability_status" -eq 1 ]]; then
      ok "skill content is free of machine-local and host-specific paths"
    else
      err "skill portability scan failed"
    fi
  fi
fi

SECRET_PATTERN="$ZSTACK_SECRET_PATTERN"
secret_hit=0
secret_scan_failed=0
if [[ "$candidate_inventory_ready" -eq 1 ]]; then
  doctor_make_temp_file SECRET_REGULAR_TMP "${TMPDIR:-/tmp}/zstack-secret-files.XXXXXX"
  doctor_make_temp_file SECRET_MATCHES_TMP "${TMPDIR:-/tmp}/zstack-secret-matches.XXXXXX"
  if [[ "$secret_scan_failed" -eq 0 ]]; then
    while IFS= read -r -d '' candidate; do
      if ! repository_candidate_is_safe "$candidate"; then
        secret_scan_failed=1
        continue
      fi
      candidate_path="$ROOT/$candidate"
      if [[ -L "$candidate_path" ]]; then
        if ! symlink_target="$(readlink "$candidate_path")"; then
          secret_scan_failed=1
        elif [[ "$symlink_target" =~ $SECRET_PATTERN ]]; then
          secret_hit=1
          if ! printf '%s\n' "$candidate_path" >> "$SECRET_MATCHES_TMP"; then
            secret_scan_failed=1
          fi
        fi
      elif [[ -f "$candidate_path" ]]; then
        printf '%s\0' "$candidate_path" >> "$SECRET_REGULAR_TMP"
      fi
    done < "$REPOSITORY_CANDIDATES_TMP"
  fi

  # Batch regular files so archives remain fast, but normalize grep's ordinary
  # "no matches" status while preserving real read or execution failures.
  if [[ "$secret_scan_failed" -eq 0 && -s "$SECRET_REGULAR_TMP" ]]; then
    # The single-quoted program is evaluated by the child sh.
    # shellcheck disable=SC2016
    if ! xargs -0 sh -c '
      pattern=$1
      shift
      [ "$#" -gt 0 ] || exit 0
      grep -I -E -l "$pattern" -- "$@"
      status=$?
      [ "$status" -le 1 ] || exit "$status"
      exit 0
    ' sh "$SECRET_PATTERN" < "$SECRET_REGULAR_TMP" >> "$SECRET_MATCHES_TMP"; then
      secret_scan_failed=1
    elif [[ -s "$SECRET_MATCHES_TMP" ]]; then
      secret_hit=1
    fi
  fi

  if [[ "$secret_scan_failed" -eq 1 ]]; then
    err "repository secret scan failed"
  elif [[ "$secret_hit" -eq 1 ]]; then
    report_secret_error "$SECRET_MATCHES_TMP"
  else
    ok "no obvious secrets in tracked or unignored repository content"
  fi
fi

if [[ "$REPOSITORY_CANDIDATE_STATE_ENABLED" -eq 1 && "$REPOSITORY_CANDIDATES_READY" -eq 1 ]]; then
  doctor_make_temp_file REPOSITORY_CANDIDATES_FINAL_TMP \
    "${TMPDIR:-/tmp}/zstack-repository-candidates-final.XXXXXX"
  if ! repository_candidates > "$REPOSITORY_CANDIDATES_FINAL_TMP"; then
    err "repository candidate final inventory failed"
    REPOSITORY_CANDIDATES_READY=0
  elif ! repository_candidate_state_after="$(
    ruby "$ROOT/scripts/capture-repository-candidate-state.rb" \
      "$ROOT" "$REPOSITORY_CANDIDATES_FINAL_TMP" 2>&1
  )"; then
    printf '%s\n' "$repository_candidate_state_after" >&2
    err "repository candidate final state could not be captured"
    REPOSITORY_CANDIDATES_READY=0
  elif [[ "$repository_candidate_state_after" != "$REPOSITORY_CANDIDATE_STATE_BEFORE" ]]; then
    err "repository candidates changed during portability validation"
    REPOSITORY_CANDIDATES_READY=0
  else
    ok "repository candidates remained stable across portability validation"
  fi
fi

if [[ "$SKILL_TREE_STATE_ENABLED" -eq 1 && "$SKILL_TREE_SOURCE_READY" -eq 1 ]]; then
  if ! skill_tree_state_after="$(
    ruby "$ROOT/scripts/capture-skill-tree-state.rb" "$ROOT/skills" 2>&1
  )"; then
    printf '%s\n' "$skill_tree_state_after" >&2
    err "skill tree final state could not be captured; skill link checks were skipped"
    SKILL_TREE_SOURCE_READY=0
  elif [[ "$skill_tree_state_after" != "$SKILL_TREE_STATE_BEFORE" ]]; then
    err "skill tree changed during source validation; skill link checks were skipped"
    SKILL_TREE_SOURCE_READY=0
  else
    ok "skill tree remained stable across source validation"
  fi
fi

if [[ "$HOST_SOURCES_READY" -eq 1 ]] && ! doctor_host_sources_are_unchanged; then
  err "host profile sources changed during source validation; installed-link audit was skipped"
  HOST_SOURCES_READY=0
fi
if [[ "$WORKFLOW_SOURCES_READY" -eq 1 ]] && ! doctor_workflow_sources_are_unchanged; then
  err "workflow sources changed during source validation"
  WORKFLOW_SOURCES_READY=0
fi
if [[ "$CATALOG_SOURCE_READY" -eq 1 ]] &&
   ! zstack_regular_file_snapshot_is_unchanged \
     "$CATALOG" "$CATALOG_SOURCE_IDENTITY" "$CATALOG_SOURCE_TMP"; then
  err "catalog.yaml changed during source validation; installed-link audit was skipped"
  CATALOG_SOURCE_READY=0
fi
if [[ "$EVAL_SOURCE_READY" -eq 1 ]] &&
   ! zstack_regular_file_snapshot_is_unchanged \
     "$EVALS" "$EVAL_SOURCE_IDENTITY" "$EVAL_SOURCE_TMP"; then
  err "evals/cases.yaml changed during source validation"
  EVAL_SOURCE_READY=0
fi
if [[ "$ROUTING_SOURCE_READY" -eq 1 ]] &&
   ! zstack_regular_file_snapshot_is_unchanged \
     "$ROUTING_EVALS" "$ROUTING_SOURCE_IDENTITY" "$ROUTING_SOURCE_TMP"; then
  err "evals/routing.yaml changed during source validation"
  ROUTING_SOURCE_READY=0
fi

if [[ "$SOURCE_ONLY" -eq 0 ]]; then
  zstack_require_safe_home
  echo "── links ──"
  state_dir_safe=1
  link_audit_ready=1
  if ! state_dir_error="$(zstack_require_safe_state_dir "$HOME/.zstack" 2>&1)"; then
    err "$state_dir_error"
    state_dir_safe=0
  fi

  if [[ "$state_dir_safe" -eq 1 && -d "$HOME/.zstack" ]]; then
    requested_operation_lock="$HOME/.zstack/operations.lock"
    if lock_result="$(zstack_acquire_pid_lock "$requested_operation_lock" "zstack setup/unlink" 2>&1)"; then
      DOCTOR_OPERATION_LOCK="$requested_operation_lock"
      [[ -z "$lock_result" ]] || warn "$lock_result"
    else
      err "installed-link audit could not acquire the mutation lock: $lock_result"
      link_audit_ready=0
    fi
  fi

  if [[ "$state_dir_safe" -eq 1 && "$link_audit_ready" -eq 1 ]]; then
    warn_non_private_state_path "$HOME/.zstack" "zstack state directory"
    root_record="$HOME/.zstack/root"
    if ! state_file_error="$(zstack_require_safe_root_record "$root_record" 2>&1)"; then
      err "$state_file_error"
    else
      if [[ -f "$root_record" ]]; then
        ROOT_RECORD_AUDIT_PRESENT=1
        if ! zstack_capture_regular_file_snapshot \
          "$root_record" ROOT_RECORD_AUDIT_TMP ROOT_RECORD_AUDIT_IDENTITY \
          "${TMPDIR:-/tmp}/zstack-doctor-root.XXXXXX"; then
          err "zstack root record changed while the installed-link audit snapshotted it"
          link_audit_ready=0
        else
          ROOT_RECORD_AUDIT_TRACKED=1
          warn_non_private_state_path "$root_record" "zstack root record"
          ZROOT="$(zstack_read_root_record "$ROOT_RECORD_AUDIT_TMP")"
          if [[ "$ZROOT" == "$ROOT" ]]; then
            ok "recorded ZSTACK_ROOT=$ZROOT"
          else
            warn "recorded ZSTACK_ROOT differs: $(zstack_quote_for_log "$ZROOT")"
          fi
        fi
      else
        ROOT_RECORD_AUDIT_TRACKED=1
        warn "no ~/.zstack/root yet — run setup.sh"
      fi
    fi

    link_manifest="$HOME/.zstack/links"
    if ! state_file_error="$(zstack_require_bounded_state_file "$link_manifest" "zstack install manifest" "$ZSTACK_LINK_MANIFEST_MAX_BYTES" 2>&1)"; then
      err "$state_file_error"
    elif [[ -f "$link_manifest" ]]; then
      LINK_MANIFEST_AUDIT_PRESENT=1
      if ! zstack_capture_regular_file_snapshot \
        "$link_manifest" LINK_MANIFEST_AUDIT_TMP LINK_MANIFEST_AUDIT_IDENTITY \
        "${TMPDIR:-/tmp}/zstack-doctor-links.XXXXXX"; then
        err "zstack install manifest changed while the installed-link audit snapshotted it"
        link_audit_ready=0
      else
        LINK_MANIFEST_AUDIT_TRACKED=1
        warn_non_private_state_path "$link_manifest" "zstack install manifest"
        tracked_links=0
        valid_tracked_links=0
        duplicate_manifest="$(sort "$LINK_MANIFEST_AUDIT_TMP" | uniq -d | sed -n '1p')"
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
        done < "$LINK_MANIFEST_AUDIT_TMP"
        if [[ "$tracked_links" -eq 0 ]]; then
          warn "install manifest has no links for the current zstack root"
        elif [[ "$valid_tracked_links" -eq "$tracked_links" ]]; then
          ok "install manifest: $valid_tracked_links tracked links for current root"
        fi
      fi
    else
      LINK_MANIFEST_AUDIT_TRACKED=1
      warn "no ~/.zstack/links manifest yet — rerun setup.sh"
    fi

    if [[ "$ROOT_RECORD_AUDIT_TRACKED" -eq 1 ]] &&
       ! doctor_state_audit_source_is_unchanged \
         "$root_record" "$ROOT_RECORD_AUDIT_PRESENT" \
         "$ROOT_RECORD_AUDIT_IDENTITY" "$ROOT_RECORD_AUDIT_TMP"; then
      err "zstack root record changed during the installed-link audit; results use the captured snapshot"
      link_audit_ready=0
    fi
    if [[ "$LINK_MANIFEST_AUDIT_TRACKED" -eq 1 ]] &&
       ! doctor_state_audit_source_is_unchanged \
         "$link_manifest" "$LINK_MANIFEST_AUDIT_PRESENT" \
         "$LINK_MANIFEST_AUDIT_IDENTITY" "$LINK_MANIFEST_AUDIT_TMP"; then
      err "zstack install manifest changed during the installed-link audit; results use the captured snapshot"
      link_audit_ready=0
    fi
  fi

  if [[ "$HOST_SOURCES_READY" -eq 1 ]] && ! doctor_host_sources_are_unchanged; then
    err "host profile sources changed during the installed-link audit; link results use captured snapshots"
    HOST_SOURCES_READY=0
  fi
  if [[ "$CATALOG_SOURCE_READY" -eq 1 ]] &&
     ! zstack_regular_file_snapshot_is_unchanged \
       "$CATALOG" "$CATALOG_SOURCE_IDENTITY" "$CATALOG_SOURCE_TMP"; then
    err "catalog.yaml changed during the installed-link audit; link results use captured snapshots"
    CATALOG_SOURCE_READY=0
  fi

  if [[ "$link_audit_ready" -eq 1 && "$HOST_SOURCES_READY" -eq 1 &&
        "$CATALOG_SOURCE_READY" -eq 1 && "$SKILL_TREE_SOURCE_READY" -eq 1 ]]; then
    while IFS='|' read -r _ hname _ skills_root _ enabled _ _ _; do
      [[ "$enabled" == "false" ]] && continue
      zstack_is_safe_home_relative_path "$skills_root" || continue
      hroot="$(zstack_expand_path "$skills_root")"
      if [[ ! -d "$hroot" ]]; then
        warn "host $hname root missing: $hroot"
        continue
      fi

      while IFS='|' read -r id path status hosts _ _ _; do
        [[ "$status" == "active" ]] || continue
        [[ ",$hosts," == *",$hname,"* ]] || continue
        dir="$ROOT/$path"
        base="$id"
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
      done < "$CATALOG_TMP"
    done < "$HOST_PROFILES_TMP"
  fi

  if [[ "$SKILL_TREE_STATE_ENABLED" -eq 1 && "$SKILL_TREE_SOURCE_READY" -eq 1 ]]; then
    if ! skill_tree_state_post_audit="$(
      ruby "$ROOT/scripts/capture-skill-tree-state.rb" "$ROOT/skills" 2>&1
    )"; then
      printf '%s\n' "$skill_tree_state_post_audit" >&2
      err "skill tree final link-audit state could not be captured; skill link results are invalid"
      SKILL_TREE_SOURCE_READY=0
    elif [[ "$skill_tree_state_post_audit" != "$SKILL_TREE_STATE_BEFORE" ]]; then
      err "skill tree changed during the installed-link audit; skill link results are invalid"
      SKILL_TREE_SOURCE_READY=0
    fi
  fi

  if [[ -n "$DOCTOR_OPERATION_LOCK" ]]; then
    zstack_release_pid_lock "$DOCTOR_OPERATION_LOCK"
    DOCTOR_OPERATION_LOCK=""
  fi
fi

echo "── summary ──"
echo "errors=$ERRORS warnings=$WARNINGS"
[[ "$ERRORS" -eq 0 ]] || exit 1
