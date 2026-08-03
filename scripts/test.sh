#!/usr/bin/env bash
# Integration tests for validation and install safety.
# Single-quoted fixture lines intentionally defer expansion to generated fake CLIs.
# shellcheck disable=SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
TEST_SCOPE="full"

usage() {
  cat <<'EOF'
Usage: ./scripts/test.sh [--smoke]

  --smoke    Run source, shared-helper, Ruby warning, and CLI contract checks.
             This is an inner-loop check, not the full integration gate.
  -h, --help Show help.
EOF
}

case "$#" in
  0) ;;
  1)
    case "$1" in
      --smoke) TEST_SCOPE="smoke" ;;
      -h|--help) usage; exit 0 ;;
      *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
    ;;
  *) usage >&2; exit 2 ;;
esac

TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/zstack-tests.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

pass() {
  if [[ "${ZSTACK_TEST_TIMING:-0}" == "1" ]]; then
    printf 'T+%ss ' "$SECONDS"
  fi
  echo "PASS: $*"
}
fail() { echo "FAIL: $*" >&2; exit 1; }

copy_fixture_from() {
  local source_root="$1"
  local name="$2"
  local scope="${3:-full}"
  local target_root="$TEST_ROOT/$name"

  git -C "$source_root" rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
    fail "fixture source is not a Git worktree: $source_root"

  mkdir -p "$target_root"
  (
    cd "$source_root"
    git ls-files --cached --others --exclude-standard -z |
      while IFS= read -r -d '' candidate; do
        # The authoritative repository (including docs and archived model
        # artifacts) is validated once against ROOT above. Mutation fixtures
        # need only the installer/validator contract they edit; a narrow copy
        # keeps the suite independent of append-only evidence growth and also
        # avoids retaining docs whose links intentionally point into archives.
        if [[ "$scope" == "source-contract" ]]; then
          case "$candidate" in
            .gitignore|.github/workflows/*|catalog.yaml|evals/cases.yaml|evals/routing.yaml|hosts/*|scripts/*|skills/*) ;;
            *) continue ;;
          esac
        fi
        printf '%s\0' "$candidate"
      done |
      tar --null -T - -cf -
  ) | tar -xf - -C "$target_root"

  (cd "$target_root" && pwd -P)
}

copy_fixture() {
  copy_fixture_from "$ROOT" "$1" source-contract
}

route_fixture_skill_to_none() {
  local fixture_root="$1"
  local skill_id="$2"
  awk -v skill_id="$skill_id" '
    $0 == "    expected_skill: " skill_id { $0 = "    expected_skill: none" }
    { print }
  ' "$fixture_root/evals/routing.yaml" > "$fixture_root/evals/routing.yaml.next"
  mv "$fixture_root/evals/routing.yaml.next" "$fixture_root/evals/routing.yaml"
}

refresh_raw_manifest_entry() {
  local artifact="$1"
  local manifest="$2"
  local relative_path="$3"
  ruby -rdigest -e '
    artifact, manifest, relative_path = ARGV
    content = File.binread(artifact)
    replacement = "#{Digest::SHA256.hexdigest(content)}  #{content.bytesize}  #{relative_path}"
    matches = 0
    lines = File.readlines(manifest, chomp: true).map do |line|
      if line.match?(/\A[0-9a-f]{64}\s+\d+\s+#{Regexp.escape(relative_path)}\z/)
        matches += 1
        replacement
      else
        line
      end
    end
    abort "raw manifest entry count was #{matches}, expected 1" unless matches == 1
    File.write(manifest, lines.join("\n") + "\n")
  ' "$artifact" "$manifest" "$relative_path"
}

echo "zstack tests"

FIXTURE_SOURCE="$TEST_ROOT/fixture-source"
mkdir -p "$FIXTURE_SOURCE"
git -C "$FIXTURE_SOURCE" init -q
printf '%s\n' '*.private' > "$FIXTURE_SOURCE/.gitignore"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$FIXTURE_SOURCE/tracked.sh"
printf '%s\n' 'pending source' > "$FIXTURE_SOURCE/pending.md"
printf '%s\n' 'local credential' > "$FIXTURE_SOURCE/token.private"
chmod +x "$FIXTURE_SOURCE/tracked.sh"
git -C "$FIXTURE_SOURCE" add .gitignore tracked.sh

BOUNDARY_FIXTURE="$(copy_fixture_from "$FIXTURE_SOURCE" fixture-boundary)"
[[ -x "$BOUNDARY_FIXTURE/tracked.sh" ]] || fail "fixture copy lost an executable bit"
[[ -f "$BOUNDARY_FIXTURE/pending.md" ]] || fail "fixture copy omitted untracked source content"
[[ ! -e "$BOUNDARY_FIXTURE/token.private" ]] || fail "fixture copy included Git-ignored local content"
pass "fixtures include commit candidates without copying ignored local state"

for skill_resource in \
  "skills/_template/assets/dist/example.txt" \
  "skills/_template/assets/out/example.txt" \
  "skills/_template/assets/coverage/example.txt" \
  "skills/_template/assets/logs/example.txt"; do
  if git -C "$ROOT" check-ignore -q --no-index "$skill_resource"; then
    fail ".gitignore hides valid skill resource paths such as $skill_resource"
  fi
done
pass "repository ignores do not hide generic skill resource directories"

for private_local_path in \
  ".zstack-new-skill.fixture/state" \
  ".gstack/state" \
  "logs/local.log" \
  "debug.log" \
  "worker.pid" \
  "worker.pid.lock" \
  ".DS_Store" \
  "node_modules/private-package/token.txt" \
  ".env" \
  ".env.local" \
  ".dev.vars" \
  ".dev.vars.local" \
  ".wrangler/state/local.json"; do
  git -C "$ROOT" check-ignore -q --no-index "$private_local_path" ||
    fail ".gitignore exposes local private state: $private_local_path"
done
for public_env_example in ".env.example" ".dev.vars.example"; do
  if git -C "$ROOT" check-ignore -q --no-index "$public_env_example"; then
    fail ".gitignore hides the public $public_env_example contract"
  fi
done
pass "repository ignores local private state while retaining public examples"

ci_timeout_minutes="$(
  awk '$1 == "timeout-minutes:" { print $2 }' "$ROOT/.github/workflows/validate.yml"
)"
[[ "$ci_timeout_minutes" =~ ^[0-9]+$ ]] ||
  fail "CI validation must define exactly one numeric timeout-minutes value"
[[ "$ci_timeout_minutes" -ge 25 ]] ||
  fail "CI validation timeout leaves too little headroom for the fault-injection suite"
pass "CI timeout retains headroom for the complete fault-injection suite"

"$ROOT/scripts/doctor.sh" --source-only >/dev/null
pass "repository passes source validation"

ruby -I "$ROOT/scripts/lib" -r eval_strict_yaml -e '
  parser = Zstack::EvalStrictYaml
  valid = parser.parse("root:\n  nested: value\n", "valid.yaml")
  abort "strict YAML parser changed a valid mapping" unless valid == { "root" => { "nested" => "value" } }
  invalid = {
    "duplicate.yaml" => "root:\n  key: safe\n  key: unsafe\n",
    "multiple.yaml" => "---\nroot: safe\n---\nroot: unsafe\n",
    "complex.yaml" => "? [root, key]\n: unsafe\n"
  }
  invalid.each do |source, content|
    begin
      parser.parse(content, source)
      abort "strict YAML parser accepted #{source}"
    rescue Psych::Exception
      nil
    end
  end
'
if grep -Eq 'YAML\.safe_load' \
  "$ROOT/scripts/run-routing-evals.rb" \
  "$ROOT/scripts/run-behavioral-evals.rb" \
  "$ROOT/scripts/archive-routing-run.rb" \
  "$ROOT/scripts/archive-behavioral-run.rb" \
  "$ROOT/scripts/report-evidence-coverage.rb" \
  "$ROOT/scripts/validate-evidence.rb"; then
  fail "an evaluation boundary bypasses the shared strict YAML parser"
fi
pass "evaluation YAML inputs reject duplicate keys, multiple documents, and complex mapping keys"

ruby -I "$ROOT/scripts/lib" -r json -r skill_tree_state -r tmpdir -r fileutils -e '
  Dir.mktmpdir("zstack-skill-tree-state.") do |root|
    skill = File.join(root, "z-example")
    FileUtils.mkdir_p(File.join(skill, "references"))
    skill_path = File.join(skill, "SKILL.md")
    File.binwrite(skill_path, "---\nname: z-example\ndescription: stable\n---\n# Example\n\xFF")
    File.binwrite(File.join(skill, "references", "quality-bar.md"), "# Quality bar\n")

    first = Zstack::SkillTreeState.capture(root)
    second = Zstack::SkillTreeState.capture(root)
    abort "stable skill tree state changed" unless first == second
    parsed = JSON.parse(first)
    abort "skill tree state omitted entries" unless parsed.fetch("entries").length == 4

    Dir.mktmpdir("zstack-skill-tree-content.") do |snapshot|
      snapshotted = Zstack::SkillTreeState.capture(root, snapshot_root: snapshot)
      abort "skill tree content snapshot changed the captured source state" unless snapshotted == first
      copied_skill = File.join(snapshot, "z-example", "SKILL.md")
      abort "skill tree content snapshot lost binary bytes" unless File.binread(copied_skill) == File.binread(skill_path)
      File.binwrite(skill_path, File.binread(skill_path) + "\nchanged after snapshot\n")
      abort "skill tree content snapshot followed a later source edit" if File.binread(copied_skill) == File.binread(skill_path)
    end

    changed = Zstack::SkillTreeState.capture(root)
    abort "skill tree state ignored changed bytes" if changed == first

    linked = File.join(skill, "linked.md")
    File.link(skill_path, linked)
    begin
      Zstack::SkillTreeState.capture(root)
      abort "skill tree state accepted a hardlinked file"
    rescue Zstack::SkillTreeState::CaptureError => e
      abort "wrong hardlink rejection" unless e.message.include?("multiple hard links")
    ensure
      File.unlink(linked)
    end

    linked = File.join(skill, "linked.md")
    File.symlink("SKILL.md", linked)
    begin
      Zstack::SkillTreeState.capture(root)
      abort "skill tree state accepted a symbolic link"
    rescue Zstack::SkillTreeState::CaptureError => e
      abort "wrong symlink rejection" unless e.message.include?("symbolic link")
    end
  end
'
pass "skill tree states are stable, binary-safe, bounded, and reject linked entries"

PORTABILITY_LINK_FIXTURE="$(copy_fixture portability-link-boundary)"
PORTABILITY_LINK_OUTSIDE="$TEST_ROOT/portability-link-outside.md"
printf '%s\n' 'mcp__outside_content_must_not_be_read' > "$PORTABILITY_LINK_OUTSIDE"
ln -s "$PORTABILITY_LINK_OUTSIDE" \
  "$PORTABILITY_LINK_FIXTURE/skills/z-market-validate/portability-link.md"
mkdir -p "$TEST_ROOT/gnu-recursive-grep-bin"
# GNU grep follows discovered symlinks for -R, unlike the BSD grep default.
# This shim makes that behavior reproducible without host-specific grep flags.
# These single-quoted lines are the source of the generated fault-injection shim.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'if [[ "${1:-}" == "-RInE" || "${1:-}" == "-RqsE" ]]; then' \
  '  recursive_flags=$1' \
  '  pattern=$2' \
  '  search_root=$3' \
  '  matched=1' \
  '  while IFS= read -r -d "" candidate; do' \
  '    if [[ -L "$candidate" ]]; then' \
  '      printf "%s\n" "$candidate" >> "$ZSTACK_DEREFERENCE_LOG"' \
  '    fi' \
  '    if [[ "$recursive_flags" == "-RqsE" ]]; then' \
  '      if "$ZSTACK_REAL_GREP" -qsE "$pattern" "$candidate"; then' \
  '        matched=0' \
  '      elif [[ "$?" -gt 1 ]]; then' \
  '        exit 2' \
  '      fi' \
  '    elif "$ZSTACK_REAL_GREP" -HnE "$pattern" "$candidate"; then' \
  '      matched=0' \
  '    elif [[ "$?" -gt 1 ]]; then' \
  '      exit 2' \
  '    fi' \
  '  done < <("$ZSTACK_REAL_FIND" -L "$search_root" -type f -print0)' \
  '  exit "$matched"' \
  'fi' \
  'exec "$ZSTACK_REAL_GREP" "$@"' > "$TEST_ROOT/gnu-recursive-grep-bin/grep"
chmod +x "$TEST_ROOT/gnu-recursive-grep-bin/grep"
if PATH="$TEST_ROOT/gnu-recursive-grep-bin:$PATH" \
  ZSTACK_REAL_GREP="$(command -v grep)" \
  ZSTACK_REAL_FIND="$(command -v find)" \
  ZSTACK_DEREFERENCE_LOG="$TEST_ROOT/skill-tree-dereferences.log" \
  "$PORTABILITY_LINK_FIXTURE/scripts/doctor.sh" --source-only \
  > "$TEST_ROOT/portability-link-boundary.log" 2>&1; then
  fail "doctor accepted a symbolic link in the skill tree"
fi
grep -q "skill tree baseline could not be captured" \
  "$TEST_ROOT/portability-link-boundary.log" ||
  fail "doctor reported the wrong skill-tree link failure"
if grep -q "skills contain host-specific tool ids or machine-local skill paths" \
  "$TEST_ROOT/portability-link-boundary.log"; then
  fail "skill portability scan followed a symbolic link outside the skill tree"
fi
if [[ -s "$TEST_ROOT/skill-tree-dereferences.log" ]]; then
  fail "recursive skill validation followed a symbolic link outside the skill tree"
fi
pass "recursive skill validation does not follow rejected skill-tree links"

FIXED_SKILL_LINK_FIXTURE="$(copy_fixture fixed-skill-link-boundary)"
FIXED_SKILL_LINK_SOURCE="$TEST_ROOT/fixed-skill-link-source.md"
printf '%s\n' \
  '---' \
  'name: z-outside-read-marker' \
  'description: This external marker is intentionally long enough to look like valid routing metadata during the boundary test.' \
  '---' \
  '# External marker' > "$FIXED_SKILL_LINK_SOURCE"
unlink "$FIXED_SKILL_LINK_FIXTURE/skills/z-market-validate/SKILL.md"
ln -s "$FIXED_SKILL_LINK_SOURCE" \
  "$FIXED_SKILL_LINK_FIXTURE/skills/z-market-validate/SKILL.md"
if "$FIXED_SKILL_LINK_FIXTURE/scripts/doctor.sh" --source-only \
  > "$TEST_ROOT/fixed-skill-link-boundary.log" 2>&1; then
  fail "doctor accepted a fixed SKILL.md symbolic link"
fi
grep -q "skill tree baseline could not be captured" \
  "$TEST_ROOT/fixed-skill-link-boundary.log" ||
  fail "doctor reported the wrong fixed skill-tree link failure"
if grep -q "z-outside-read-marker" "$TEST_ROOT/fixed-skill-link-boundary.log"; then
  fail "doctor read a fixed SKILL.md symbolic link after rejecting the skill tree"
fi
pass "doctor skips fixed skill content after rejecting the skill tree"

RACED_SKILL_LINK_FIXTURE="$(copy_fixture raced-skill-link-boundary)"
RACED_SKILL_LINK_SOURCE="$TEST_ROOT/raced-skill-link-source.md"
RACED_SKILL_LINK_PATH="$RACED_SKILL_LINK_FIXTURE/skills/z-market-validate/SKILL.md"
RACED_SKILL_LINK_DISPLACED="$TEST_ROOT/raced-skill-link-original.md"
RACED_SKILL_LINK_MARKER="$TEST_ROOT/raced-skill-link-marker"
printf '%s\n' \
  '---' \
  'name: z-raced-outside-read-marker' \
  'description: This raced external marker is intentionally long enough to look like valid routing metadata during the boundary test.' \
  '---' \
  '# Raced external marker' > "$RACED_SKILL_LINK_SOURCE"
mkdir -p "$TEST_ROOT/raced-skill-ruby-bin"
# These single-quoted lines are the source of the generated fault-injection shim.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'status=0' \
  'is_initial_validator=0' \
  'for argument in "$@"; do' \
  '  [[ "$argument" != "$VALIDATOR_PATH" ]] || is_initial_validator=1' \
  '  [[ "$argument" != "--documents" ]] || is_initial_validator=0' \
  'done' \
  '"$REAL_RUBY_BIN" "$@" || status=$?' \
  'if [[ "$status" -eq 0 && "$is_initial_validator" -eq 1 && ! -e "$STATE_MARKER" ]]; then' \
  '  mv "$SKILL_PATH" "$DISPLACED_PATH"' \
  '  ln -s "$OUTSIDE_PATH" "$SKILL_PATH"' \
  '  : > "$STATE_MARKER"' \
  'fi' \
  'exit "$status"' > "$TEST_ROOT/raced-skill-ruby-bin/ruby"
chmod +x "$TEST_ROOT/raced-skill-ruby-bin/ruby"
if PATH="$TEST_ROOT/raced-skill-ruby-bin:$PATH" \
  REAL_RUBY_BIN="$(command -v ruby)" \
  VALIDATOR_PATH="$RACED_SKILL_LINK_FIXTURE/scripts/validate-yaml.rb" \
  SKILL_PATH="$RACED_SKILL_LINK_PATH" \
  DISPLACED_PATH="$RACED_SKILL_LINK_DISPLACED" \
  OUTSIDE_PATH="$RACED_SKILL_LINK_SOURCE" \
  STATE_MARKER="$RACED_SKILL_LINK_MARKER" \
  "$RACED_SKILL_LINK_FIXTURE/scripts/doctor.sh" --source-only \
  > "$TEST_ROOT/raced-skill-link-boundary.log" 2>&1; then
  fail "doctor accepted a SKILL.md replaced after its baseline capture"
fi
[[ -f "$RACED_SKILL_LINK_MARKER" ]] ||
  fail "raced fixed-skill fixture did not replace SKILL.md after YAML validation"
if grep -q "z-raced-outside-read-marker" "$TEST_ROOT/raced-skill-link-boundary.log"; then
  fail "doctor read a SKILL.md symlink introduced after its baseline capture"
fi
grep -q "skill tree changed before content validation; skill content checks were skipped" \
  "$TEST_ROOT/raced-skill-link-boundary.log" ||
  fail "doctor reported the wrong pre-content skill-tree drift failure"
pass "doctor revalidates the skill tree before fixed content reads"

POST_SNAPSHOT_SKILL_LINK_FIXTURE="$(copy_fixture post-snapshot-skill-link-boundary)"
POST_SNAPSHOT_SKILL_LINK_PATH="$POST_SNAPSHOT_SKILL_LINK_FIXTURE/skills/z-market-validate/SKILL.md"
POST_SNAPSHOT_SKILL_LINK_SOURCE="$TEST_ROOT/post-snapshot-skill-link-outside.md"
POST_SNAPSHOT_SKILL_LINK_DISPLACED="$TEST_ROOT/post-snapshot-skill-link-original.md"
POST_SNAPSHOT_SKILL_LINK_MARKER="$TEST_ROOT/post-snapshot-skill-link-marker"
POST_SNAPSHOT_SKILL_CAPTURE_COUNT="$TEST_ROOT/post-snapshot-skill-capture-count"
POST_SNAPSHOT_SKILL_TMP="$TEST_ROOT/post-snapshot-skill-tmp"
printf '%s\n' \
  '---' \
  'name: z-post-snapshot-outside-read-marker' \
  'description: This external marker must never be read after the doctor captures its private skill content snapshot.' \
  '---' \
  '# Post-snapshot external read marker' > "$POST_SNAPSHOT_SKILL_LINK_SOURCE"
mkdir -p "$TEST_ROOT/post-snapshot-skill-ruby-bin" "$POST_SNAPSHOT_SKILL_TMP"
chmod 700 "$POST_SNAPSHOT_SKILL_TMP"
# These single-quoted lines are the source of the generated fault-injection shim.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'status=0' \
  'is_skill_capture=0' \
  'for argument in "$@"; do' \
  '  [[ "$argument" != "$SKILL_CAPTURE_PATH" ]] || is_skill_capture=1' \
  'done' \
  '"$REAL_RUBY_BIN" "$@" || status=$?' \
  'if [[ "$status" -eq 0 && "$is_skill_capture" -eq 1 ]]; then' \
  '  capture_count=0' \
  '  [[ ! -f "$CAPTURE_COUNT_PATH" ]] || capture_count="$(sed -n "1p" "$CAPTURE_COUNT_PATH")"' \
  '  capture_count=$((capture_count + 1))' \
  '  printf "%s\n" "$capture_count" > "$CAPTURE_COUNT_PATH"' \
  '  if [[ "$capture_count" -eq 2 && ! -e "$STATE_MARKER" ]]; then' \
  '    mv "$SKILL_PATH" "$DISPLACED_PATH"' \
  '    ln -s "$OUTSIDE_PATH" "$SKILL_PATH"' \
  '    : > "$STATE_MARKER"' \
  '  fi' \
  'fi' \
  'exit "$status"' > "$TEST_ROOT/post-snapshot-skill-ruby-bin/ruby"
chmod +x "$TEST_ROOT/post-snapshot-skill-ruby-bin/ruby"
if PATH="$TEST_ROOT/post-snapshot-skill-ruby-bin:$PATH" \
  REAL_RUBY_BIN="$(command -v ruby)" \
  SKILL_CAPTURE_PATH="$POST_SNAPSHOT_SKILL_LINK_FIXTURE/scripts/capture-skill-tree-state.rb" \
  SKILL_PATH="$POST_SNAPSHOT_SKILL_LINK_PATH" \
  DISPLACED_PATH="$POST_SNAPSHOT_SKILL_LINK_DISPLACED" \
  OUTSIDE_PATH="$POST_SNAPSHOT_SKILL_LINK_SOURCE" \
  STATE_MARKER="$POST_SNAPSHOT_SKILL_LINK_MARKER" \
  CAPTURE_COUNT_PATH="$POST_SNAPSHOT_SKILL_CAPTURE_COUNT" \
  TMPDIR="$POST_SNAPSHOT_SKILL_TMP" \
  "$POST_SNAPSHOT_SKILL_LINK_FIXTURE/scripts/doctor.sh" --source-only \
  > "$TEST_ROOT/post-snapshot-skill-link-boundary.log" 2>&1; then
  fail "doctor accepted a SKILL.md replaced after its content snapshot"
fi
[[ -f "$POST_SNAPSHOT_SKILL_LINK_MARKER" ]] ||
  fail "post-snapshot skill fixture did not replace SKILL.md after the second capture"
if grep -q "z-post-snapshot-outside-read-marker" \
  "$TEST_ROOT/post-snapshot-skill-link-boundary.log"; then
  fail "doctor read a SKILL.md symlink introduced after its content snapshot"
fi
grep -q "skill tree final state could not be captured; skill link checks were skipped" \
  "$TEST_ROOT/post-snapshot-skill-link-boundary.log" ||
  fail "doctor reported the wrong post-snapshot skill-tree drift failure"
post_snapshot_skill_temps="$(find "$POST_SNAPSHOT_SKILL_TMP" \
  -mindepth 1 -maxdepth 1 -print | wc -l | tr -d ' ')"
[[ "$post_snapshot_skill_temps" -eq 0 ]] ||
  fail "post-snapshot skill-tree drift left temporary files"
pass "doctor validates skill content from one private snapshot after the live tree changes"

ruby -I "$ROOT/scripts/lib" -r json -r repository_candidate_state -r tmpdir -r fileutils -e '
  Dir.mktmpdir("zstack-repository-state.") do |container|
    root = File.join(container, "repository")
    inventory = File.join(container, "inventory")
    FileUtils.mkdir_p(File.join(root, "docs"))
    source = File.join(root, "docs", "note.md")
    link = File.join(root, "latest.md")
    File.binwrite(source, "binary:\xFF\n")
    File.symlink("docs/note.md", link)
    File.binwrite(inventory, "docs/note.md\0latest.md\0")

    first = Zstack::RepositoryCandidateState.capture(root, inventory)
    second_inventory = File.join(container, "second-inventory")
    File.binwrite(second_inventory, "latest.md\0docs/note.md\0")
    second = Zstack::RepositoryCandidateState.capture(root, second_inventory)
    abort "stable repository candidate state changed" unless first == second
    parsed = JSON.parse(first)
    abort "repository candidate state omitted entries" unless parsed.fetch("entries").length == 2

    File.binwrite(source, File.binread(source) + "changed\n")
    changed = Zstack::RepositoryCandidateState.capture(root, inventory)
    abort "repository candidate state ignored changed bytes" if changed == first

    alias_path = File.join(root, "alias.md")
    File.link(source, alias_path)
    File.binwrite(inventory, "alias.md\0")
    begin
      Zstack::RepositoryCandidateState.capture(root, inventory)
      abort "repository candidate state accepted a hardlinked file"
    rescue Zstack::RepositoryCandidateState::CaptureError => e
      abort "wrong repository hardlink rejection" unless e.message.include?("one hard link")
    ensure
      File.unlink(alias_path)
    end

    File.binwrite(inventory, "../outside\0")
    begin
      Zstack::RepositoryCandidateState.capture(root, inventory)
      abort "repository candidate state accepted an escaping path"
    rescue Zstack::RepositoryCandidateState::CaptureError => e
      abort "wrong repository path rejection" unless e.message.include?("not canonical portable UTF-8")
    end
  end
'
pass "repository candidate states bind binary files, symlinks, inventories, and safe paths"

NO_RUBY_BIN="$TEST_ROOT/no-ruby-bin"
mkdir -p "$NO_RUBY_BIN"
for no_ruby_command in \
  awk bash basename cat chmod cmp cp cut dirname find git grep head ls mkdir mktemp mv readlink rm rmdir sed sh sort stat tr uniq wc xargs; do
  ln -s "$(command -v "$no_ruby_command")" "$NO_RUBY_BIN/$no_ruby_command"
done
if ! PATH="$NO_RUBY_BIN" "$ROOT/scripts/doctor.sh" --source-only > "$TEST_ROOT/no-ruby-doctor.log" 2>&1; then
  fail "doctor failed instead of degrading when Ruby was unavailable"
fi
grep -q "ruby is unavailable; skipped skill package limits, cross-phase skill-tree stability, and strict Evidence handoff table-shape checks" \
  "$TEST_ROOT/no-ruby-doctor.log" ||
  fail "doctor did not disclose skipped skill package and handoff checks without Ruby"
pass "doctor degrades explicitly when Ruby is unavailable"

if PATH="$NO_RUBY_BIN" \
  "$FIXED_SKILL_LINK_FIXTURE/scripts/doctor.sh" --source-only \
  > "$TEST_ROOT/no-ruby-fixed-skill-link.log" 2>&1; then
  fail "no-Ruby doctor accepted a fixed SKILL.md symbolic link"
fi
grep -q "skill tree content preflight could not be validated" \
  "$TEST_ROOT/no-ruby-fixed-skill-link.log" ||
  fail "no-Ruby doctor reported the wrong fixed skill-tree link failure"
if grep -q "z-outside-read-marker" "$TEST_ROOT/no-ruby-fixed-skill-link.log"; then
  fail "no-Ruby doctor read a fixed SKILL.md symbolic link after preflight failure"
fi
pass "no-Ruby doctor preflights skill content before fixed-file reads"

NO_RUBY_RACED_SKILL_FIXTURE="$(copy_fixture no-ruby-raced-skill-link)"
NO_RUBY_RACED_SKILL_PATH="$NO_RUBY_RACED_SKILL_FIXTURE/skills/z-market-validate/SKILL.md"
NO_RUBY_RACED_SKILL_SOURCE="$TEST_ROOT/no-ruby-raced-skill-source.md"
NO_RUBY_RACED_SKILL_DISPLACED="$TEST_ROOT/no-ruby-raced-skill-original.md"
NO_RUBY_RACED_SKILL_MARKER="$TEST_ROOT/no-ruby-raced-skill-marker"
NO_RUBY_RACED_REAL_FIND="$(command -v find)"
NO_RUBY_RACED_REAL_SLEEP="$(command -v sleep)"
NO_RUBY_RACED_REAL_MV="$(command -v mv)"
NO_RUBY_RACED_REAL_LN="$(command -v ln)"
printf '%s\n' \
  '---' \
  'name: z-no-ruby-raced-outside-marker' \
  'description: This no-Ruby raced marker is intentionally long enough to look like valid routing metadata during the boundary test.' \
  '---' \
  '# No-Ruby raced marker' > "$NO_RUBY_RACED_SKILL_SOURCE"
mkdir -p "$TEST_ROOT/no-ruby-raced-skill-bin"
# These single-quoted lines are the source of the generated fault-injection shim.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'status=0' \
  '"$REAL_FIND_BIN" "$@" || status=$?' \
  'if [[ "$status" -eq 0 && "${1:-}" == "$SKILL_ROOT" && ! -e "$STATE_MARKER" ]]; then' \
  '  "$REAL_SLEEP_BIN" 1' \
  '  "$REAL_MV_BIN" "$SKILL_PATH" "$DISPLACED_PATH"' \
  '  "$REAL_LN_BIN" -s "$OUTSIDE_PATH" "$SKILL_PATH"' \
  '  : > "$STATE_MARKER"' \
  'fi' \
  'exit "$status"' > "$TEST_ROOT/no-ruby-raced-skill-bin/find"
chmod +x "$TEST_ROOT/no-ruby-raced-skill-bin/find"
if PATH="$TEST_ROOT/no-ruby-raced-skill-bin:$NO_RUBY_BIN" \
  REAL_FIND_BIN="$NO_RUBY_RACED_REAL_FIND" \
  REAL_SLEEP_BIN="$NO_RUBY_RACED_REAL_SLEEP" \
  REAL_MV_BIN="$NO_RUBY_RACED_REAL_MV" \
  REAL_LN_BIN="$NO_RUBY_RACED_REAL_LN" \
  SKILL_ROOT="$NO_RUBY_RACED_SKILL_FIXTURE/skills" \
  SKILL_PATH="$NO_RUBY_RACED_SKILL_PATH" \
  DISPLACED_PATH="$NO_RUBY_RACED_SKILL_DISPLACED" \
  OUTSIDE_PATH="$NO_RUBY_RACED_SKILL_SOURCE" \
  STATE_MARKER="$NO_RUBY_RACED_SKILL_MARKER" \
  "$NO_RUBY_RACED_SKILL_FIXTURE/scripts/doctor.sh" --source-only \
  > "$TEST_ROOT/no-ruby-raced-skill.log" 2>&1; then
  fail "no-Ruby doctor accepted SKILL.md replaced between content preflights"
fi
[[ -f "$NO_RUBY_RACED_SKILL_MARKER" ]] ||
  fail "no-Ruby raced skill fixture did not replace SKILL.md after the first preflight"
grep -q "skill tree content preflight changed before validation; skill content checks were skipped" \
  "$TEST_ROOT/no-ruby-raced-skill.log" ||
  fail "no-Ruby doctor reported the wrong pre-content skill-tree drift failure"
if grep -q "z-no-ruby-raced-outside-marker" "$TEST_ROOT/no-ruby-raced-skill.log"; then
  fail "no-Ruby doctor read SKILL.md replaced between content preflights"
fi
pass "no-Ruby doctor revalidates the skill tree before content reads"

NO_RUBY_LIMIT_FIXTURE="$(copy_fixture no-ruby-candidate-limit)"
dd if=/dev/zero of="$NO_RUBY_LIMIT_FIXTURE/oversized-public-source.txt" \
  bs=2097153 count=1 2>/dev/null
if PATH="$NO_RUBY_BIN" \
  "$NO_RUBY_LIMIT_FIXTURE/scripts/doctor.sh" --source-only --fail-fast \
  > "$TEST_ROOT/no-ruby-candidate-limit.log" 2>&1; then
  fail "no-Ruby doctor accepted a repository candidate above the per-file limit"
fi
grep -q "repository candidate preflight could not be validated" \
  "$TEST_ROOT/no-ruby-candidate-limit.log" ||
  fail "no-Ruby doctor reported the wrong candidate resource-limit failure"
pass "no-Ruby doctor bounds repository candidates before content scans"

NO_RUBY_IDENTITY_FIXTURE="$(copy_fixture no-ruby-candidate-identity)"
printf '%s\n' 'public source with an external write alias' \
  > "$NO_RUBY_IDENTITY_FIXTURE/hardlink-target.txt"
ln "$NO_RUBY_IDENTITY_FIXTURE/hardlink-target.txt" \
  "$NO_RUBY_IDENTITY_FIXTURE/hardlink-alias.txt"
if PATH="$NO_RUBY_BIN" \
  "$NO_RUBY_IDENTITY_FIXTURE/scripts/doctor.sh" --source-only --fail-fast \
  > "$TEST_ROOT/no-ruby-candidate-identity.log" 2>&1; then
  fail "no-Ruby doctor accepted a multiply linked repository candidate"
fi
grep -q "repository candidate preflight could not be validated" \
  "$TEST_ROOT/no-ruby-candidate-identity.log" ||
  fail "no-Ruby doctor reported the wrong candidate identity failure"
pass "no-Ruby doctor rejects repository candidates with external write aliases"

NO_GIT_SPECIAL_FIXTURE="$(copy_fixture no-git-special-candidate)"
mkfifo "$NO_GIT_SPECIAL_FIXTURE/public-special.fifo"
if PATH="$NO_RUBY_BIN" \
  "$NO_GIT_SPECIAL_FIXTURE/scripts/doctor.sh" --source-only --fail-fast \
  > "$TEST_ROOT/no-git-special-candidate.log" 2>&1; then
  fail "no-Git no-Ruby doctor silently ignored a special repository candidate"
fi
grep -q "repository candidate preflight could not be validated" \
  "$TEST_ROOT/no-git-special-candidate.log" ||
  fail "no-Git no-Ruby doctor reported the wrong special-candidate failure"
[[ -p "$NO_GIT_SPECIAL_FIXTURE/public-special.fifo" ]] ||
  fail "no-Git candidate validation changed the special entry"
pass "no-Git candidate discovery exposes special entries to fail-closed preflight"

test_heavy_no_ruby_candidate_limits() {
if (
  ZSTACK_REAL_GIT="$(command -v git)"
  export ZSTACK_REAL_GIT
  # Invoked indirectly by the child Bash after export.
  # shellcheck disable=SC2329
  git() {
    local argument
    for argument in "$@"; do
      if [[ "$argument" == "ls-files" ]]; then
        awk 'BEGIN {
          for (candidate_index = 0; candidate_index <= 100000; candidate_index++) {
            printf "README.md%c", 0
          }
        }'
        return $?
      fi
    done
    "$ZSTACK_REAL_GIT" "$@"
  }
  export -f git
  PATH="$NO_RUBY_BIN" \
    "$ROOT/scripts/doctor.sh" --source-only --fail-fast \
    > "$TEST_ROOT/no-ruby-candidate-count.log" 2>&1
); then
  fail "no-Ruby doctor accepted more than 100,000 repository candidates"
fi
grep -q "repository candidate inventory failed" \
  "$TEST_ROOT/no-ruby-candidate-count.log" ||
  fail "no-Ruby doctor reported the wrong candidate-count failure"
pass "no-Ruby candidate inventory enforces its item limit through the Git pipeline"

if (
  ZSTACK_REAL_FIND="$(command -v find)"
  ZSTACK_REAL_GIT="$(command -v git)"
  export ZSTACK_REAL_FIND ZSTACK_REAL_GIT
  # Invoked indirectly by the child Bash after export.
  # shellcheck disable=SC2329
  git() {
    local argument
    for argument in "$@"; do
      [[ "$argument" == "rev-parse" ]] && return 1
    done
    "$ZSTACK_REAL_GIT" "$@"
  }
  # Invoked indirectly by the child Bash after export.
  # shellcheck disable=SC2329
  find() {
    if [[ "${1:-}" == "." ]]; then
      awk 'BEGIN {
        for (candidate_index = 0; candidate_index <= 100000; candidate_index++) {
          printf "./README.md%c", 0
        }
      }'
      return $?
    fi
    "$ZSTACK_REAL_FIND" "$@"
  }
  export -f find git
  PATH="$NO_RUBY_BIN" \
    "$ROOT/scripts/doctor.sh" --source-only --fail-fast \
    > "$TEST_ROOT/no-git-no-ruby-candidate-count.log" 2>&1
); then
  fail "no-Git no-Ruby doctor accepted more than 100,000 repository candidates"
fi
grep -q "repository candidate inventory failed" \
  "$TEST_ROOT/no-git-no-ruby-candidate-count.log" ||
  fail "no-Git no-Ruby doctor reported the wrong candidate-count failure"
pass "no-Git candidate inventory enforces its item limit through the find pipeline"

if (
  ZSTACK_REAL_GIT="$(command -v git)"
  export ZSTACK_REAL_GIT
  # Invoked indirectly by the child Bash after export.
  # shellcheck disable=SC2329
  git() {
    local argument
    for argument in "$@"; do
      if [[ "$argument" == "ls-files" ]]; then
        awk 'BEGIN {
          chunk = ""
          for (chunk_index = 0; chunk_index < 1024; chunk_index++) {
            chunk = chunk "aaaaaaaaaaaaaaaa"
          }
          for (candidate_index = 0; candidate_index < 1024; candidate_index++) {
            printf "./%s%04d%c", chunk, candidate_index, 0
          }
        }'
        return $?
      fi
    done
    "$ZSTACK_REAL_GIT" "$@"
  }
  export -f git
  PATH="$NO_RUBY_BIN" \
    "$ROOT/scripts/doctor.sh" --source-only --fail-fast \
    > "$TEST_ROOT/no-ruby-candidate-inventory-bytes.log" 2>&1
); then
  fail "no-Ruby doctor accepted a repository candidate inventory above 16 MiB"
fi
grep -q "repository candidate inventory failed" \
  "$TEST_ROOT/no-ruby-candidate-inventory-bytes.log" ||
  fail "no-Ruby doctor reported the wrong candidate inventory-byte failure"
pass "no-Ruby candidate inventory enforces its byte limit independently of item count"

NO_RUBY_TOTAL_LIMIT_FIXTURE="$(copy_fixture no-ruby-candidate-total-limit)"
mkdir -p "$NO_RUBY_TOTAL_LIMIT_FIXTURE/bulk-public-source"
ruby -e '
  root = ARGV.fetch(0)
  257.times do |index|
    path = File.join(root, format("candidate-%03d.bin", index))
    File.open(path, "wb") { |file| file.truncate(2 * 1024 * 1024) }
  end
' "$NO_RUBY_TOTAL_LIMIT_FIXTURE/bulk-public-source"
if PATH="$NO_RUBY_BIN" \
  "$NO_RUBY_TOTAL_LIMIT_FIXTURE/scripts/doctor.sh" --source-only --fail-fast \
  > "$TEST_ROOT/no-ruby-candidate-total-limit.log" 2>&1; then
  fail "no-Ruby doctor accepted repository candidates above the total-byte limit"
fi
grep -q "repository candidate preflight could not be validated" \
  "$TEST_ROOT/no-ruby-candidate-total-limit.log" ||
  fail "no-Ruby doctor reported the wrong candidate total-byte failure"
pass "no-Ruby candidate preflight enforces total bytes independently of per-file limits"
}

DOCTOR_MKTEMP_FAILURE_ROOT="$TEST_ROOT/doctor-mktemp-failure"
DOCTOR_MKTEMP_FAILURE_COUNTER="$TEST_ROOT/doctor-mktemp-failure-counter"
mkdir -p "$DOCTOR_MKTEMP_FAILURE_ROOT"
if (
  ZSTACK_REAL_MKTEMP="$(command -v mktemp)"
  export ZSTACK_REAL_MKTEMP DOCTOR_MKTEMP_FAILURE_COUNTER
  # Invoked by the child Bash after export.
  # shellcheck disable=SC2329
  mktemp() {
    local count=0
    [[ ! -f "$DOCTOR_MKTEMP_FAILURE_COUNTER" ]] || count="$(cat "$DOCTOR_MKTEMP_FAILURE_COUNTER")"
    count=$((count + 1))
    printf '%s\n' "$count" > "$DOCTOR_MKTEMP_FAILURE_COUNTER"
    [[ "$count" -ne 2 ]] || return 73
    "$ZSTACK_REAL_MKTEMP" "$@"
  }
  export -f mktemp
  TMPDIR="$DOCTOR_MKTEMP_FAILURE_ROOT" \
    "$ROOT/scripts/doctor.sh" --source-only > "$TEST_ROOT/doctor-mktemp-failure.log" 2>&1
); then
  fail "doctor accepted an injected second temporary-file creation failure"
fi
if find "$DOCTOR_MKTEMP_FAILURE_ROOT" -mindepth 1 -print -quit | grep -q .; then
  fail "doctor leaked its first temporary file when the second creation failed"
fi
pass "doctor installs temporary-file cleanup before fallible allocation"

DOCTOR_MKTEMP_REPLACEMENT_ROOT="$TEST_ROOT/doctor-mktemp-replacement"
DOCTOR_MKTEMP_REPLACEMENT_COUNTER="$TEST_ROOT/doctor-mktemp-replacement-counter"
DOCTOR_MKTEMP_REPLACEMENT_RECORD="$TEST_ROOT/doctor-mktemp-replacement-record"
DOCTOR_MKTEMP_CREATED_FILE="$TEST_ROOT/doctor-mktemp-created-file"
mkdir -p "$DOCTOR_MKTEMP_REPLACEMENT_ROOT"
if (
  ZSTACK_REAL_MKTEMP="$(command -v mktemp)"
  export ZSTACK_REAL_MKTEMP DOCTOR_MKTEMP_REPLACEMENT_COUNTER \
    DOCTOR_MKTEMP_REPLACEMENT_RECORD DOCTOR_MKTEMP_CREATED_FILE
  # Invoked by the child Bash after export.
  # shellcheck disable=SC2329
  mktemp() {
    local count=0
    local created=""
    [[ ! -f "$DOCTOR_MKTEMP_REPLACEMENT_COUNTER" ]] ||
      count="$(cat "$DOCTOR_MKTEMP_REPLACEMENT_COUNTER")"
    count=$((count + 1))
    printf '%s\n' "$count" > "$DOCTOR_MKTEMP_REPLACEMENT_COUNTER"
    if [[ "$count" -eq 2 ]]; then
      created="$(cat "$DOCTOR_MKTEMP_REPLACEMENT_RECORD")"
      mv "$created" "$DOCTOR_MKTEMP_CREATED_FILE"
      printf '%s\n' "replacement must survive" > "$created"
      return 73
    fi
    created="$("$ZSTACK_REAL_MKTEMP" "$@")" || return
    printf '%s\n' "$created" > "$DOCTOR_MKTEMP_REPLACEMENT_RECORD"
    printf '%s\n' "$created"
  }
  export -f mktemp
  TMPDIR="$DOCTOR_MKTEMP_REPLACEMENT_ROOT" \
    "$ROOT/scripts/doctor.sh" --source-only > "$TEST_ROOT/doctor-mktemp-replacement.log" 2>&1
); then
  fail "doctor accepted an injected temporary-file replacement failure"
fi
DOCTOR_MKTEMP_REPLACEMENT_PATH="$(cat "$DOCTOR_MKTEMP_REPLACEMENT_RECORD")"
grep -qx "replacement must survive" "$DOCTOR_MKTEMP_REPLACEMENT_PATH" ||
  fail "doctor temporary cleanup removed a replacement file"
[[ -f "$DOCTOR_MKTEMP_CREATED_FILE" ]] || fail "doctor replacement fixture lost the originally created file"
rm -f "$DOCTOR_MKTEMP_REPLACEMENT_PATH" "$DOCTOR_MKTEMP_CREATED_FILE"
pass "doctor temporary cleanup preserves concurrently replaced files"

grep -Fq 'ruby scripts/report-evidence-coverage.rb --require-current-complete-pass' "$ROOT/CONTRIBUTING.md" ||
  fail "contributor guide omitted the current-source any-host evidence gate"
grep -Fq 'ruby scripts/report-evidence-coverage.rb --require-current-complete-pass' "$ROOT/.github/workflows/validate.yml" ||
  fail "CI omitted the current-source any-host evidence gate"
CONTRIBUTOR_HOST_GATE_COUNT="$(grep -Ec '^[[:space:]]*--require-current-complete-pass-host' "$ROOT/CONTRIBUTING.md")"
CI_HOST_GATE_COUNT="$(grep -Ec '^[[:space:]]*--require-current-complete-pass-host' "$ROOT/.github/workflows/validate.yml")"
[[ "$CONTRIBUTOR_HOST_GATE_COUNT" -gt 0 && "$CONTRIBUTOR_HOST_GATE_COUNT" -eq "$CI_HOST_GATE_COUNT" ]] ||
  fail "contributor guide host evidence gates drifted from CI"
if grep -Eq '^[[:space:]]*--require-complete-pass-host([[:space:]]|$)|^[[:space:]]*ruby[[:space:]]+scripts/report-evidence-coverage\.rb[[:space:]]+--require-complete-pass([[:space:]]|$)' "$ROOT/CONTRIBUTING.md"; then
  fail "contributor guide uses a historical evidence gate for release validation"
fi
pass "contributor checks match current-source CI evidence gates"

ruby "$ROOT/scripts/check-evidence-docs.rb" >/dev/null ||
  fail "documented current evidence does not match the coverage reports"
STALE_EVIDENCE_ROOT="$TEST_ROOT/stale-evidence-docs"
mkdir -p "$STALE_EVIDENCE_ROOT/docs"
cp "$ROOT/README.md" "$STALE_EVIDENCE_ROOT/README.md"
cp "$ROOT/docs/compatibility.md" "$STALE_EVIDENCE_ROOT/docs/compatibility.md"
ruby -0777 -pe 'sub(/Codex 行为 \*\*(\d+)\/(\d+)\*\*/) { "Codex 行为 **#{$1.to_i + 1}/#{$2}**" }' \
  "$ROOT/README.zh-CN.md" > "$STALE_EVIDENCE_ROOT/README.zh-CN.md"
cmp -s "$ROOT/README.zh-CN.md" "$STALE_EVIDENCE_ROOT/README.zh-CN.md" &&
  fail "stale evidence fixture did not change the documented count"
if ruby "$ROOT/scripts/check-evidence-docs.rb" \
  --document "$STALE_EVIDENCE_ROOT/README.md" \
  --document "$STALE_EVIDENCE_ROOT/README.zh-CN.md" \
  --document "$STALE_EVIDENCE_ROOT/docs/compatibility.md" \
  > "$TEST_ROOT/stale-evidence-doc.log" 2>&1; then
  fail "evidence-document checker accepted a stale host count"
fi
grep -q "current-evidence block is stale" "$TEST_ROOT/stale-evidence-doc.log" ||
  fail "evidence-document checker reported the wrong stale-count failure"
pass "documented host evidence matches current coverage and rejects stale counts"

EVIDENCE_DOC_INPUT_ROOT="$TEST_ROOT/evidence-document-input-boundary"
mkdir -p "$EVIDENCE_DOC_INPUT_ROOT"
ln -s "$ROOT/README.md" "$EVIDENCE_DOC_INPUT_ROOT/linked.md"
cp "$ROOT/README.md" "$EVIDENCE_DOC_INPUT_ROOT/hardlinked-source.md"
ln "$EVIDENCE_DOC_INPUT_ROOT/hardlinked-source.md" "$EVIDENCE_DOC_INPUT_ROOT/hardlinked.md"
cp "$ROOT/README.md" "$EVIDENCE_DOC_INPUT_ROOT/oversized.md"
ruby -e 'File.open(ARGV.fetch(0), "ab") { |file| file.truncate(2 * 1024 * 1024 + 1) }' \
  "$EVIDENCE_DOC_INPUT_ROOT/oversized.md"
if ruby "$ROOT/scripts/check-evidence-docs.rb" \
  --document "$EVIDENCE_DOC_INPUT_ROOT/linked.md" \
  --document "$EVIDENCE_DOC_INPUT_ROOT/hardlinked.md" \
  --document "$EVIDENCE_DOC_INPUT_ROOT/oversized.md" \
  > "$TEST_ROOT/evidence-document-input-boundary.log" 2>&1; then
  fail "evidence-document checker accepted linked, hardlinked, or oversized inputs"
fi
grep -q "linked.md: cannot read document safely:.*regular non-link" \
  "$TEST_ROOT/evidence-document-input-boundary.log" ||
  fail "evidence-document checker reported the wrong symlink failure"
grep -q "hardlinked.md: cannot read document safely:.*one hard link" \
  "$TEST_ROOT/evidence-document-input-boundary.log" ||
  fail "evidence-document checker reported the wrong hardlink failure"
grep -q "oversized.md: cannot read document safely:.*exceeds 2097152 bytes" \
  "$TEST_ROOT/evidence-document-input-boundary.log" ||
  fail "evidence-document checker reported the wrong size-limit failure"
pass "evidence-document inputs are bounded, stable, and reject linked files"

ruby -I "$ROOT/scripts/lib" -r eval_host_contracts -e '
  contracts = Zstack::EvalHostContracts
  abort "Grok isolated config is mutable" unless contracts::GROK_ISOLATED_CONFIG.frozen?
  abort "Grok final marker is mutable" unless contracts::GROK_FINAL_MARKER.frozen?
  abort "Grok prompt descriptor contract changed" unless contracts::GROK_PROMPT_DESCRIPTOR == 9 && contracts::GROK_PROMPT_PATH == "/dev/fd/9" && contracts::GROK_PROMPT_PATH.frozen?
  abort "Grok system prompts are mutable" unless contracts::GROK_SYSTEM_PROMPTS.frozen? && contracts::GROK_SYSTEM_PROMPTS.values.all?(&:frozen?)
  abort "Grok system prompts lost their final boundary" unless contracts::GROK_SYSTEM_PROMPTS.values.all? { |prompt| prompt.include?(contracts::GROK_FINAL_MARKER) }
  abort "Grok isolated config lost compatibility exclusions" unless %w[claude cursor codex].all? { |name| contracts::GROK_ISOLATED_CONFIG.include?("[compat.#{name}]") }
  expected = [
    [{ "is_error" => true, "api_error_status" => 404, "result" => "selected model unavailable" }, "model-unavailable"],
    [{ "is_error" => true, "api_error_status" => 401, "result" => "denied" }, "authentication"],
    [{ "is_error" => true, "api_error_status" => 429, "result" => "slow down" }, "rate-limit"],
    [{ "is_error" => true, "api_error_status" => 503, "result" => "upstream" }, "provider-error"],
    [{ "is_error" => false }, "incomplete-result"]
  ]
  expected.each do |(data, category)|
    abort "Claude error category changed for #{category}" unless contracts.claude_error_category(data, false) == category
  end
  abort "completed Claude result received an error category" unless contracts.claude_error_category({}, true).nil?
  grok_errors = [
    [{ "type" => "error", "message" => "Unauthorized (401) from https://example.invalid: no auth context" }, 401, "authentication"],
    [{ "type" => "error", "message" => "HTTP 429 rate limit" }, 429, "rate-limit"],
    [{ "type" => "error", "message" => "Service Unavailable (503) from https://example.invalid" }, 503, "provider-error"],
    [{ "type" => "error", "message" => "selected model was not found; HTTP 404" }, 404, "model-unavailable"]
  ]
  grok_errors.each do |(data, status, category)|
    actual_status = contracts.grok_api_error_status(data)
    abort "Grok API status changed for #{category}" unless actual_status == status
    abort "Grok error category changed for #{category}" unless contracts.grok_error_category(data, false, nil, actual_status) == category
  end
  abort "Grok final-boundary failure lost precedence" unless contracts.grok_error_category({ "type" => "result" }, false, "missing-final-marker") == "final-boundary-invalid"
'
pass "evaluation host contracts keep immutable inputs separate from archive proof logic"

STRUCTURED_RESULT_FILE_CONTRACT="$TEST_ROOT/structured-result-file-contract"
mkdir -p "$STRUCTURED_RESULT_FILE_CONTRACT"
printf '%s\n' '{}' > "$STRUCTURED_RESULT_FILE_CONTRACT/regular.json"
printf '%s\n' '{"type":"result","subtype":"success","is_error":false,"result":"answer","modelUsage":{"model":{}},"total_cost_usd":1e309}' \
  > "$STRUCTURED_RESULT_FILE_CONTRACT/claude-infinite.json"
printf '%s\n' '{"type":"result","text":"ZSTACK_FINAL_RESPONSE_V1\nanswer","num_turns":1,"stopReason":"end_turn","modelUsage":{"model":{}},"total_cost_usd":0.1,"usage":{"input_tokens":1e309}}' \
  > "$STRUCTURED_RESULT_FILE_CONTRACT/grok-infinite.json"
printf '%s\n' '{"type":"result","subtype":"success","is_error":true,"is_error":false,"result":"answer","modelUsage":{"model":{}},"total_cost_usd":0.1}' \
  > "$STRUCTURED_RESULT_FILE_CONTRACT/claude-duplicate.json"
printf '%s\n' '{"type":"result","text":"ZSTACK_FINAL_RESPONSE_V1\nanswer","num_turns":1,"stopReason":"end_turn","modelUsage":{"model":{}},"total_cost_usd":0.1,"usage":{"input_tokens":999,"input_tokens":1}}' \
  > "$STRUCTURED_RESULT_FILE_CONTRACT/grok-nested-duplicate.json"
ln -s "$STRUCTURED_RESULT_FILE_CONTRACT/regular.json" "$STRUCTURED_RESULT_FILE_CONTRACT/linked.json"
mkfifo "$STRUCTURED_RESULT_FILE_CONTRACT/result.fifo"
ruby -I "$ROOT/scripts/lib" -r eval_host_contracts -e '
  contracts = Zstack::EvalHostContracts
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  claude = contracts.claude_result(ARGV.fetch(0))
  grok = contracts.grok_result(ARGV.fetch(1))
  claude_infinite = contracts.claude_result(ARGV.fetch(2))
  grok_infinite = contracts.grok_result(ARGV.fetch(3))
  claude_duplicate = contracts.claude_result(ARGV.fetch(4))
  grok_duplicate = contracts.grok_result(ARGV.fetch(5))
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  abort "unsafe structured result reads blocked" unless elapsed < 1
  abort "linked Claude result was not rejected" unless claude.fetch("errorCategory") == "result-record-invalid" && claude.fetch("parseError").include?("regular non-link")
  abort "FIFO Grok result was not rejected" unless grok.fetch("errorCategory") == "result-record-invalid" && grok.fetch("parseError").include?("regular non-link")
  abort "infinite Claude cost was not rejected" unless claude_infinite.fetch("errorCategory") == "result-record-invalid" && claude_infinite.fetch("parseError").include?("finite")
  abort "infinite Grok usage was not rejected" unless grok_infinite.fetch("errorCategory") == "result-record-invalid" && grok_infinite.fetch("parseError").include?("finite")
  abort "duplicate Claude result key was not rejected" unless claude_duplicate.fetch("errorCategory") == "result-record-invalid" && claude_duplicate.fetch("parseError").include?("duplicate JSON object key")
  abort "nested duplicate Grok usage key was not rejected" unless grok_duplicate.fetch("errorCategory") == "result-record-invalid" && grok_duplicate.fetch("parseError").include?("duplicate JSON object key")
' "$STRUCTURED_RESULT_FILE_CONTRACT/linked.json" "$STRUCTURED_RESULT_FILE_CONTRACT/result.fifo" \
  "$STRUCTURED_RESULT_FILE_CONTRACT/claude-infinite.json" "$STRUCTURED_RESULT_FILE_CONTRACT/grok-infinite.json" \
  "$STRUCTURED_RESULT_FILE_CONTRACT/claude-duplicate.json" "$STRUCTURED_RESULT_FILE_CONTRACT/grok-nested-duplicate.json"
pass "structured host results are bounded, stable, non-link, UTF-8, and nonblocking"

INPUT_FILE_ROOT="$TEST_ROOT/input-file-contract"
mkdir -p "$INPUT_FILE_ROOT/trusted"
printf '%s\n' 'regular input bytes' > "$INPUT_FILE_ROOT/trusted/regular.txt"
ln -s "$INPUT_FILE_ROOT/trusted" "$INPUT_FILE_ROOT/trusted-alias"
printf '%s\n' 'outside input bytes' > "$INPUT_FILE_ROOT/outside.txt"
ln "$INPUT_FILE_ROOT/outside.txt" "$INPUT_FILE_ROOT/trusted/linked.txt"
ruby -I "$ROOT/scripts/lib" -r eval_input_file -e '
  regular = Zstack::EvalInputFile.read(
    File.join(ARGV.fetch(1), "regular.txt"),
    root: ARGV.fetch(0),
    label: "aliased evaluation input"
  )
  abort "evaluation input rejected a canonical trusted-root alias" unless regular == "regular input bytes\n"
  begin
    Zstack::EvalInputFile.read(
      File.join(ARGV.fetch(0), "linked.txt"),
      root: ARGV.fetch(0),
      label: "linked evaluation input"
    )
    abort "evaluation input accepted a multiply linked file"
  rescue Zstack::EvalInputFile::ReadError => e
    abort "evaluation input reported the wrong hardlink failure" unless e.message.include?("one hard link")
  end
' "$INPUT_FILE_ROOT/trusted" "$INPUT_FILE_ROOT/trusted-alias"
pass "evaluation inputs canonicalize trusted-root aliases and require current-owner single-link files"

SOURCE_SNAPSHOT_FIXTURE="$TEST_ROOT/source-snapshot"
mkdir -p "$SOURCE_SNAPSHOT_FIXTURE"
printf '%s' 'stable runner bytes' > "$SOURCE_SNAPSHOT_FIXTURE/stable.txt"
printf '%s' 'copy failure source bytes' > "$SOURCE_SNAPSHOT_FIXTURE/copy-failure.txt"
printf '\377' > "$SOURCE_SNAPSHOT_FIXTURE/invalid-utf8.bin"
dd if=/dev/zero of="$SOURCE_SNAPSHOT_FIXTURE/oversized.bin" \
  bs=$((2 * 1024 * 1024 + 1)) count=1 2>/dev/null
ln -s "$SOURCE_SNAPSHOT_FIXTURE/stable.txt" "$SOURCE_SNAPSHOT_FIXTURE/symlink.txt"
mkfifo "$SOURCE_SNAPSHOT_FIXTURE/special.fifo"
printf '%s' 'external hardlink bytes' > "$TEST_ROOT/source-snapshot-hardlink-target.txt"
ln "$TEST_ROOT/source-snapshot-hardlink-target.txt" "$SOURCE_SNAPSHOT_FIXTURE/hardlink.txt"
ruby -I "$ROOT/scripts/lib" -r eval_source_snapshot -e '
  root = ARGV.fetch(0)
  snapshot = Zstack::EvalSourceSnapshot.new(root)
  begin
    captured = snapshot.capture("stable.txt")
    File.write(File.join(root, "stable.txt"), "changed after capture")
    abort "captured runner bytes changed with their source" unless File.binread(captured) == "stable runner bytes"
    abort "runner source cache did not return one stable path" unless snapshot.capture("stable.txt") == captured
    unless snapshot.read(captured).frozen? && snapshot.read(captured) == "stable runner bytes" &&
           snapshot.read("stable.txt") == "stable runner bytes" && snapshot.read_text(captured) == "stable runner bytes" &&
           snapshot.read_text(captured).frozen? && snapshot.bytesize(captured) == 19
      abort "runner source memory authority did not preserve immutable captured bytes"
    end
    invalid_utf8 = snapshot.capture("invalid-utf8.bin")
    abort "runner source binary view changed invalid bytes" unless snapshot.read(invalid_utf8) == "\xFF".b
    begin
      snapshot.read_text(invalid_utf8)
      abort "runner source text view accepted invalid UTF-8"
    rescue RuntimeError => e
      abort "runner source text view reported the wrong encoding failure" unless e.message.include?("not valid UTF-8")
    end

    displaced_capture = "#{captured}.created"
    File.rename(captured, displaced_capture)
    File.write(captured, "replacement snapshot bytes")
    unless snapshot.read(captured) == "stable runner bytes"
      abort "runner source memory authority followed a replaced snapshot path"
    end
    published = File.join(File.dirname(root), "source-snapshot-published.txt")
    snapshot.copy(captured, published)
    abort "runner source copy did not use captured memory bytes" unless File.binread(published) == "stable runner bytes"
    begin
      snapshot.copy(captured, published)
      abort "runner source copy overwrote an existing destination"
    rescue RuntimeError => e
      abort "runner source copy reported the wrong exclusive-write failure" unless e.message.include?("Errno::EEXIST")
    end
    abort "failed exclusive copy changed its destination" unless File.binread(published) == "stable runner bytes"
    {
      "oversized.bin" => /runner source file exceeds 2097152 bytes/,
      "symlink.txt" => /runner path contains a symbolic link/,
      "special.fifo" => /missing or non-regular/,
      "hardlink.txt" => /one hard link/,
      "../outside.txt" => /canonical and stay inside/
    }.each do |path, expected|
      begin
        snapshot.capture(path)
        abort "unsafe runner source was accepted: #{path}"
      rescue RuntimeError => e
        abort "wrong runner-source failure for #{path}: #{e.message}" unless e.message.match?(expected)
      end
    end

    File.class_eval do
      alias_method :zstack_original_snapshot_fsync, :fsync
      define_method(:fsync) do
        if File.basename(path) == "copy-failure.txt"
          $zstack_snapshot_replacement = path
          File.rename(path, "#{path}.created")
          File.write(path, "replacement must survive\n")
          raise Errno::EIO
        end
        zstack_original_snapshot_fsync
      end
    end
    begin
      snapshot.capture("copy-failure.txt")
      abort "injected snapshot copy failure was accepted"
    rescue RuntimeError => e
      abort "snapshot copy reported the wrong injected failure" unless e.message.include?("Errno::EIO")
    end
    unless File.read($zstack_snapshot_replacement) == "replacement must survive\n"
      abort "failed snapshot copy removed a replacement target"
    end

    snapshot_root = File.dirname(captured)
    moved_snapshot_root = "#{snapshot_root}.created"
    File.rename(snapshot_root, moved_snapshot_root)
    Dir.mkdir(snapshot_root, 0o700)
    replacement_marker = File.join(snapshot_root, "replacement.txt")
    File.write(replacement_marker, "replacement directory must survive\n")
    snapshot.close
    abort "snapshot close removed a replacement directory" unless File.file?(replacement_marker)
    FileUtils.remove_entry(moved_snapshot_root)
    FileUtils.remove_entry(snapshot_root)
    File.unlink(published)
    snapshot = nil
  ensure
    snapshot&.close
  end
' "$SOURCE_SNAPSHOT_FIXTURE"
pass "archiver source snapshots are stable, bounded, symlink-safe, and replacement-safe"

RAW_ARCHIVE_CONTRACT="$TEST_ROOT/raw-archive-contract"
mkdir -p "$RAW_ARCHIVE_CONTRACT/raw/responses"
printf '%s' 'captured raw response' > "$RAW_ARCHIVE_CONTRACT/raw/responses/case.txt"
ruby -I "$ROOT/scripts/lib" -r eval_archive_raw_files -e '
  raw = ARGV.fetch(0)
  contents = { "responses/case.txt" => "captured raw response".b.freeze }
  manifest = Zstack::EvalArchiveRawFiles.write_manifest(raw, contents)
  abort "raw archive manifest was not generated from captured bytes" unless
    manifest.include?(Digest::SHA256.hexdigest(contents.fetch("responses/case.txt")))
  File.binwrite(File.join(raw, "responses", "case.txt"), "replaced raw response")
  begin
    Zstack::EvalArchiveRawFiles.verify!(raw, contents, manifest)
    abort "raw archive verifier accepted replaced content"
  rescue RuntimeError => e
    abort "raw archive verifier reported the wrong content drift" unless
      e.message.include?("differs from captured bytes")
  end
' "$RAW_ARCHIVE_CONTRACT/raw"
pass "raw archive manifests and inventories stay bound to captured in-memory bytes"

ARCHIVE_CANDIDATE_CONTRACT="$TEST_ROOT/archive-candidate-contract"
mkdir -p "$ARCHIVE_CANDIDATE_CONTRACT/hidden/raw"
printf '%s' 'prevalidated bytes' > "$ARCHIVE_CANDIDATE_CONTRACT/hidden/raw/evidence.txt"
ruby -I "$ROOT/scripts/lib" -r eval_archive_candidate -e '
  hidden = ARGV.fetch(0)
  published = ARGV.fetch(1)
  snapshot = Zstack::EvalArchiveCandidate.capture(hidden)
  Zstack::EvalArchiveCandidate.verify!(hidden, snapshot)
  File.rename(hidden, published)
  Zstack::EvalArchiveCandidate.verify!(published, snapshot, relocated: true)
  File.binwrite(File.join(published, "raw", "evidence.txt"), "self-consistent replacement")
  begin
    Zstack::EvalArchiveCandidate.verify!(published, snapshot, relocated: true)
    abort "archive candidate verifier accepted post-validation drift"
  rescue RuntimeError => e
    abort "archive candidate verifier reported the wrong tree drift" unless
      e.message.include?("differs from the prevalidated candidate tree")
  end
' "$ARCHIVE_CANDIDATE_CONTRACT/hidden" "$ARCHIVE_CANDIDATE_CONTRACT/published"
pass "archive candidates remain content-bound across atomic relocation"

ARCHIVE_OUTPUT_CONTRACT="$TEST_ROOT/archive-output-contract"
mkdir -p "$ARCHIVE_OUTPUT_CONTRACT/root"
printf '%s' 'existing bytes must survive' > "$ARCHIVE_OUTPUT_CONTRACT/root/existing.txt"
printf '%s' 'outside bytes must survive' > "$ARCHIVE_OUTPUT_CONTRACT/outside.txt"
ln -s "$ARCHIVE_OUTPUT_CONTRACT/outside.txt" "$ARCHIVE_OUTPUT_CONTRACT/root/symlink.txt"
ruby -I "$ROOT/scripts/lib" -r eval_archive_output -e '
  root = ARGV.fetch(0)
  outside = ARGV.fetch(1)
  writer = Zstack::EvalArchiveOutput.new(root)
  writer.write("generated.txt", "generated bytes\n")
  abort "archive output writer changed generated bytes" unless
    File.binread(File.join(root, "generated.txt")) == "generated bytes\n"
  { "existing.txt" => /Errno::EEXIST/, "symlink.txt" => /Errno::EEXIST/ }.each do |relative, expected|
    begin
      writer.write(relative, "replacement")
      abort "archive output writer overwrote #{relative}"
    rescue RuntimeError => e
      abort "archive output writer reported the wrong collision" unless e.message.match?(expected)
    end
  end
  abort "archive output writer changed existing bytes" unless
    File.binread(File.join(root, "existing.txt")) == "existing bytes must survive"
  abort "archive output writer followed a symbolic link" unless
    File.binread(outside) == "outside bytes must survive"
  begin
    writer.write("generated.txt", "second write")
    abort "archive output writer accepted a duplicate logical write"
  rescue RuntimeError => e
    abort "archive output writer reported the wrong duplicate" unless e.message.include?("written twice")
  end
' "$ARCHIVE_OUTPUT_CONTRACT/root" "$ARCHIVE_OUTPUT_CONTRACT/outside.txt"
pass "generated archive files are root-bound, exclusive, and no-follow"

OWNED_DIRECTORY_RACE_ROOT="$TEST_ROOT/owned-directory-race"
mkdir -p "$OWNED_DIRECTORY_RACE_ROOT/temporary"
printf '%s\n' 'original temporary directory' > "$OWNED_DIRECTORY_RACE_ROOT/temporary/original.txt"
ruby -I "$ROOT/scripts/lib" -r eval_owned_directory -rfileutils -e '
  root = ARGV.fetch(0)
  path = File.join(root, "temporary")
  displaced = File.join(root, "displaced-original")
  identity = Zstack::EvalOwnedDirectory.capture(path)
  before_quarantines = Dir.glob(File.join(root, ".zstack-owned-directory-*"))

  $zstack_owned_path = path
  $zstack_owned_displaced = displaced
  class << File
    alias zstack_original_owned_rename rename

    def rename(source, target)
      if source == $zstack_owned_path && !File.exist?($zstack_owned_displaced)
        zstack_original_owned_rename(source, $zstack_owned_displaced)
        Dir.mkdir(source, 0o700)
        File.write(File.join(source, "replacement.txt"), "replacement must survive\n")
      end
      zstack_original_owned_rename(source, target)
    end
  end

  removed = Zstack::EvalOwnedDirectory.remove_if_same(path, identity)
  abort "owned-directory cleanup accepted a pathname swapped before quarantine" if removed
  replacement = File.join(path, "replacement.txt")
  unless File.binread(replacement) == "replacement must survive\n"
    abort "owned-directory cleanup did not restore the replacement directory"
  end
  original = File.join(displaced, "original.txt")
  unless File.binread(original) == "original temporary directory\n"
    abort "owned-directory cleanup changed the displaced original directory"
  end
  after_quarantines = Dir.glob(File.join(root, ".zstack-owned-directory-*"))
  abort "owned-directory cleanup leaked an empty quarantine" unless after_quarantines == before_quarantines
  FileUtils.remove_entry(path)
  FileUtils.remove_entry(displaced)
' "$OWNED_DIRECTORY_RACE_ROOT"
pass "owned-directory cleanup quarantines by inode and restores raced replacements"

ARCHIVE_LOCK_ROOT="$TEST_ROOT/archive-lock-root"
mkdir -p "$ARCHIVE_LOCK_ROOT"
ruby -I "$ROOT/scripts/lib" -r eval_archive_lock -e '
  root = ARGV.fetch(0)
  first = Zstack::EvalArchiveLock.acquire(root)
  begin
    begin
      Zstack::EvalArchiveLock.acquire(root)
      abort "archive publication lock allowed concurrent acquisition"
    rescue RuntimeError => e
      abort "archive publication lock reported the wrong contention failure" unless e.message.include?("publication is in progress")
    end
  ensure
    first.close
  end
  recovered = Zstack::EvalArchiveLock.acquire(root)
  recovered.close
' "$ARCHIVE_LOCK_ROOT"
pass "archive publication locks serialize and recover after release"

ARCHIVE_LOCK_VICTIM="$TEST_ROOT/archive-lock-victim.txt"
printf '%s\n' 'must not be truncated through a hardlink' > "$ARCHIVE_LOCK_VICTIM"
chmod 600 "$ARCHIVE_LOCK_VICTIM"
ruby -I "$ROOT/scripts/lib" -r eval_archive_lock -rdigest -rtmpdir -e '
  root = File.realpath(ARGV.fetch(0))
  victim = ARGV.fetch(1)
  key = Digest::SHA256.hexdigest(root)[0, 32]
  lock_path = File.join(Dir.tmpdir, "zstack-eval-archive-#{key}.lock")
  File.unlink(lock_path) if File.exist?(lock_path) || File.symlink?(lock_path)
  File.link(victim, lock_path)
  begin
    begin
      lock = Zstack::EvalArchiveLock.acquire(root)
      lock.close
      abort "archive publication lock accepted a hardlinked lock file"
    rescue RuntimeError => e
      unless e.message.include?("owner-private single-link regular file")
        abort "archive publication lock reported the wrong hardlink failure: #{e.message}"
      end
    end
    unless File.binread(victim) == "must not be truncated through a hardlink\n"
      abort "archive publication lock truncated the hardlink target"
    end
  ensure
    File.unlink(lock_path) if File.exist?(lock_path) || File.symlink?(lock_path)
  end
' "$ARCHIVE_LOCK_ROOT" "$ARCHIVE_LOCK_VICTIM"
pass "archive publication locks reject hardlinks before truncating lock content"

ARCHIVE_LOCK_SYMLINK_VICTIM="$TEST_ROOT/archive-lock-symlink-victim.txt"
printf '%s\n' 'must not be truncated through a symlink' > "$ARCHIVE_LOCK_SYMLINK_VICTIM"
chmod 600 "$ARCHIVE_LOCK_SYMLINK_VICTIM"
ruby -I "$ROOT/scripts/lib" -r eval_archive_lock -rdigest -rtmpdir -e '
  root = File.realpath(ARGV.fetch(0))
  victim = ARGV.fetch(1)
  key = Digest::SHA256.hexdigest(root)[0, 32]
  lock_path = File.join(Dir.tmpdir, "zstack-eval-archive-#{key}.lock")
  File.unlink(lock_path) if File.exist?(lock_path) || File.symlink?(lock_path)
  File.symlink(victim, lock_path)

  constants = File::Constants
  nofollow = constants.const_get(:NOFOLLOW)
  constants.send(:remove_const, :NOFOLLOW)
  begin
    begin
      lock = Zstack::EvalArchiveLock.acquire(root)
      lock.close
      abort "archive publication lock accepted a symlink without O_NOFOLLOW"
    rescue RuntimeError => e
      unless e.message.include?("owner-private single-link regular file")
        abort "archive publication lock reported the wrong symlink failure: #{e.message}"
      end
    end
    unless File.binread(victim) == "must not be truncated through a symlink\n"
      abort "archive publication lock truncated the symlink target"
    end
  ensure
    constants.const_set(:NOFOLLOW, nofollow)
    File.unlink(lock_path) if File.exist?(lock_path) || File.symlink?(lock_path)
  end
' "$ARCHIVE_LOCK_ROOT" "$ARCHIVE_LOCK_SYMLINK_VICTIM"
pass "archive publication locks bind lock path identity before truncation without O_NOFOLLOW"

ruby -I "$ROOT/scripts/lib" -r eval_archive_lock -rdigest -rtmpdir -e '
  root = File.realpath(ARGV.fetch(0))
  key = Digest::SHA256.hexdigest(root)[0, 32]
  lock_path = File.join(Dir.tmpdir, "zstack-eval-archive-#{key}.lock")
  displaced_path = "#{lock_path}.displaced-#{Process.pid}"
  File.unlink(displaced_path) if File.exist?(displaced_path) || File.symlink?(displaced_path)

  first = Zstack::EvalArchiveLock.acquire(root)
  begin
    File.rename(lock_path, displaced_path)
    File.open(lock_path, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
      file.write("replacement must survive\n")
    end
    begin
      first.verify!
      abort "archive publication lock lease accepted a replaced pathname"
    rescue RuntimeError => e
      unless e.message.include?("path changed or became unsafe")
        abort "archive publication lock lease reported the wrong replacement failure: #{e.message}"
      end
    end

    second = Zstack::EvalArchiveLock.acquire(root)
    begin
      abort "replacement lock owner was not retained" unless File.binread(lock_path) == "#{Process.pid}\n"
    ensure
      second.close
    end
  ensure
    first.close
    File.unlink(lock_path) if File.exist?(lock_path) || File.symlink?(lock_path)
    File.unlink(displaced_path) if File.exist?(displaced_path) || File.symlink?(displaced_path)
  end
' "$ARCHIVE_LOCK_ROOT"
pass "archive publication lock leases detect pathname replacement before publication"

ruby -I "$ROOT/scripts/lib" -r eval_public_text -e '
  contract = Zstack::EvalPublicText
  private_examples = [
    "/Users/alice/check.rb",
    "/home/alice/check.rb",
    "/tmp/check.rb",
    "/private/tmp/check.rb",
    "/var/folders/aa/check.rb",
    "/private/var/folders/aa/check.rb",
    "C:\\Users\\alice\\check.rb"
  ]
  public_examples = [
    "https://example.com/tmp/check",
    "POST /api/waitlist",
    "artifacts/check.rb"
  ]
  abort "public-text contract missed a machine-local root" unless private_examples.all? { |text| contract.machine_local_path?(text) }
  abort "public-text contract rejected a portable reference" unless public_examples.none? { |text| contract.machine_local_path?(text) }
'
pass "public evidence text rejects machine-local roots without rejecting portable references"

# shellcheck source=./scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"
ruby -I "$ROOT/scripts/lib" -r eval_limits -e '
  expected = [
    Zstack::EvalLimits::MAX_RETAINED_FILE_BYTES,
    Zstack::EvalLimits::MAX_REPOSITORY_CANDIDATES,
    Zstack::EvalLimits::MAX_REPOSITORY_CANDIDATE_BYTES,
    Zstack::EvalLimits::MAX_REPOSITORY_CANDIDATE_INVENTORY_BYTES,
    Zstack::EvalLimits::MAX_RETAINED_FILE_BYTES,
    Zstack::EvalLimits::MAX_SKILL_COLLECTION_FILES,
    Zstack::EvalLimits::MAX_SKILL_COLLECTION_BYTES,
    Zstack::EvalLimits::MAX_SKILL_COLLECTION_TREE_ENTRIES
  ]
  actual = ARGV.map(&:to_i)
  abort "Bash and Ruby source-tree limits differ" unless actual == expected
' \
  "$ZSTACK_REPOSITORY_CANDIDATE_MAX_FILE_BYTES" \
  "$ZSTACK_REPOSITORY_CANDIDATE_MAX_FILES" \
  "$ZSTACK_REPOSITORY_CANDIDATE_MAX_BYTES" \
  "$ZSTACK_REPOSITORY_CANDIDATE_MAX_INVENTORY_BYTES" \
  "$ZSTACK_SKILL_TREE_MAX_FILE_BYTES" \
  "$ZSTACK_SKILL_TREE_MAX_FILES" \
  "$ZSTACK_SKILL_TREE_MAX_BYTES" \
  "$ZSTACK_SKILL_TREE_MAX_ENTRIES"
secret_samples=(
  "sk-proj-$(printf '%024d' 0)"
  "hf_$(printf '%032d' 0)"
  "sk_live_$(printf '%020d' 0)"
  "rk_live_$(printf '%020d' 0)"
  "sk_test_$(printf '%020d' 0)"
  "rk_test_$(printf '%020d' 0)"
  "whsec_$(printf '%020d' 0)"
  "export XAI_API_KEY=\"$(printf '%032d' 0)\""
  "CLOUDFLARE_API_TOKEN=\"$(printf '%032d' 0)\""
  "CLOUDFLARE_API_KEY=$(printf '%032d' 0)"
  "CLOUDFLARE_ACCESS_CLIENT_SECRET='$(printf '%032d' 0)'"
  "WRANGLER_R2_SQL_AUTH_TOKEN=$(printf '%032d' 0)"
  "CF_API_TOKEN=$(printf '%032d' 0)"
  "CF_API_KEY=$(printf '%032d' 0)"
  "ghp_$(printf '%020d' 0)"
  "gho_$(printf '%020d' 0)"
  "github_pat_$(printf '%024d' 0)"
  "npm_$(printf '%020d' 0)"
  "AIza$(printf '%035d' 0)"
  "xoxb-$(printf '%020d' 0)"
  "AKIA$(printf '%016d' 0)"
  "-----BEGIN ""PRIVATE KEY-----"
)
secret_sample_labels=(
  ai-provider hugging-face-token stripe-live-secret stripe-live-restricted stripe-test-secret
  stripe-test-restricted stripe-webhook xai-api-key
  cloudflare-api-token cloudflare-api-key cloudflare-access-client-secret
  wrangler-r2-token cloudflare-legacy-token cloudflare-legacy-key
  github-classic github-oauth github-fine-grained npm google-api slack-bot
  aws-access private-key
)
[[ "${#secret_samples[@]}" -eq "${#secret_sample_labels[@]}" ]] ||
  fail "secret lint positive samples and labels are out of sync"
for ((secret_sample_index = 0; secret_sample_index < ${#secret_samples[@]}; secret_sample_index++)); do
  secret_sample="${secret_samples[$secret_sample_index]}"
  [[ "$secret_sample" =~ $ZSTACK_SECRET_PATTERN ]] ||
    fail "secret lint missed ${secret_sample_labels[$secret_sample_index]} credentials"
done
for public_sample in \
  'sk-short' \
  'hf_REPLACE_ME' \
  'HF_TOKEN=hf_example' \
  'HUGGING_FACE_HUB_TOKEN=hf_example' \
  'sk_live_example' \
  'sk_test_example' \
  'whsec_REPLACE_ME' \
  'XAI_API_KEY=your_api_key' \
  'XAI_API_KEY="<YOUR_XAI_API_KEY_HERE>"' \
  'CLOUDFLARE_API_TOKEN=<YOUR_API_TOKEN_VALUE>' \
  'CLOUDFLARE_API_KEY="your_api_key"' \
  'CLOUDFLARE_ACCESS_CLIENT_SECRET=<YOUR_ACCESS_CLIENT_SECRET>' \
  'WRANGLER_R2_SQL_AUTH_TOKEN=<YOUR_R2_API_TOKEN_VALUE>' \
  'CF_API_TOKEN=your_api_token' \
  'CF_API_KEY=your_api_key' \
  "MY_XAI_API_KEY=$(printf '%032d' 0)" \
  "NOT_CLOUDFLARE_API_TOKEN=$(printf '%032d' 0)" \
  'github_pat_example' \
  "pk_live_$(printf '%020d' 0)" \
  "pk_test_$(printf '%020d' 0)" \
  'npm install package' \
  'POST /api/waitlist'; do
  if [[ "$public_sample" =~ $ZSTACK_SECRET_PATTERN ]]; then
    fail "secret lint rejected an ordinary placeholder or public string"
  fi
done
pass "secret lint covers provider credentials without matching placeholders or prefixed variables"

zstack_is_manifest_safe_path "/tmp/zstack-safe-path" || fail "manifest path contract rejected a safe absolute path"
for unsafe_manifest_path in \
  "/tmp/zstack|pipe" \
  $'/tmp/zstack\ttab' \
  $'/tmp/zstack\rcarriage-return' \
  $'/tmp/zstack\033escape' \
  $'/tmp/zstack\nnewline'; do
  if zstack_is_manifest_safe_path "$unsafe_manifest_path"; then
    fail "manifest path contract accepted a delimiter or control character"
  fi
done
pass "install manifest paths reject delimiters and terminal control characters"

zstack_is_manifest_line_safe "/tmp/zstack-root|/tmp/zstack-link" || fail "manifest line contract rejected a valid record"
for unsafe_manifest_line in \
  "/tmp/zstack-root" \
  "/tmp/zstack-root|/tmp/zstack-link|extra" \
  "relative-root|/tmp/zstack-link" \
  "/tmp/zstack-root|relative-link" \
  $'/tmp/zstack-root|/tmp/zstack-\033link'; do
  if zstack_is_manifest_line_safe "$unsafe_manifest_line"; then
    fail "manifest line contract accepted malformed or unsafe fields"
  fi
done
pass "install manifest records require one delimiter and two safe absolute paths"

STATE_FILE_CONTRACT="$TEST_ROOT/state-file-contract"
mkdir -p "$STATE_FILE_CONTRACT/regular" "$STATE_FILE_CONTRACT/directory"
touch "$STATE_FILE_CONTRACT/regular/file"
ln -s "$STATE_FILE_CONTRACT/regular/file" "$STATE_FILE_CONTRACT/symlink"
zstack_require_safe_state_file "$STATE_FILE_CONTRACT/regular/file" "test state file" || fail "state file contract rejected a regular file"
for unsafe_state_file in "$STATE_FILE_CONTRACT/directory" "$STATE_FILE_CONTRACT/symlink"; do
  if zstack_require_safe_state_file "$unsafe_state_file" "test state file" >/dev/null 2>&1; then
    fail "state file contract accepted a directory or symlink"
  fi
done
printf '%s\n' "hardlinked state bytes" > "$STATE_FILE_CONTRACT/hardlinked"
ln "$STATE_FILE_CONTRACT/hardlinked" "$STATE_FILE_CONTRACT/hardlinked-alias"
[[ "$(zstack_file_link_count "$STATE_FILE_CONTRACT/hardlinked")" == "2" ]] ||
  fail "portable state-file hard-link detection returned the wrong count"
if zstack_require_safe_state_file "$STATE_FILE_CONTRACT/hardlinked" "test state file" >/dev/null 2>&1; then
  fail "state file contract accepted a multiply linked regular file"
fi
pass "state leaves accept only single-link regular files"

SNAPSHOT_CONTRACT="$STATE_FILE_CONTRACT/snapshot-contract"
mkdir -p "$SNAPSHOT_CONTRACT"
printf '%s\n' "stable source bytes" > "$SNAPSHOT_CONTRACT/source"
captured_snapshot=""
captured_source_identity=""
captured_snapshot_identity=""
zstack_capture_regular_file_snapshot \
  "$SNAPSHOT_CONTRACT/source" captured_snapshot captured_source_identity \
  "$SNAPSHOT_CONTRACT/captured.XXXXXX" captured_snapshot_identity ||
  fail "regular-file snapshot helper rejected a stable source"
[[ "$captured_source_identity" == "$(zstack_file_identity "$SNAPSHOT_CONTRACT/source")" ]] ||
  fail "regular-file snapshot helper returned the wrong source identity"
[[ "$captured_snapshot_identity" == "$(zstack_file_identity "$captured_snapshot")" ]] ||
  fail "regular-file snapshot helper returned the wrong snapshot identity"
cmp -s "$SNAPSHOT_CONTRACT/source" "$captured_snapshot" ||
  fail "regular-file snapshot helper returned the wrong bytes"
zstack_regular_file_snapshot_is_unchanged \
  "$SNAPSHOT_CONTRACT/source" "$captured_source_identity" "$captured_snapshot" ||
  fail "regular-file snapshot helper did not produce a strict snapshot"
zstack_cleanup_identity_temp_files ||
  fail "regular-file snapshot helper could not clean its captured snapshot"
[[ ! -e "$captured_snapshot" && ! -L "$captured_snapshot" ]] ||
  fail "regular-file snapshot helper left its captured snapshot behind"

printf '%s\n' "linked source bytes" > "$SNAPSHOT_CONTRACT/linked-source"
ln "$SNAPSHOT_CONTRACT/linked-source" "$SNAPSHOT_CONTRACT/linked-source-alias"
rejected_snapshot="unchanged-snapshot-output"
rejected_identity="unchanged-identity-output"
if zstack_capture_regular_file_snapshot \
  "$SNAPSHOT_CONTRACT/linked-source" rejected_snapshot rejected_identity \
  "$SNAPSHOT_CONTRACT/rejected.XXXXXX"; then
  fail "regular-file snapshot helper accepted a multiply linked source"
fi
[[ "$rejected_snapshot" == "unchanged-snapshot-output" ]] ||
  fail "regular-file snapshot helper published a failed snapshot path"
[[ "$rejected_identity" == "unchanged-identity-output" ]] ||
  fail "regular-file snapshot helper published a failed source identity"
zstack_cleanup_identity_temp_files ||
  fail "regular-file snapshot helper could not clean a rejected snapshot"
[[ -f "$SNAPSHOT_CONTRACT/linked-source" && -f "$SNAPSHOT_CONTRACT/linked-source-alias" ]] ||
  fail "regular-file snapshot helper changed a rejected multiply linked source"
pass "regular-file snapshots publish outputs only after strict identity and byte verification"

(
  # The sourced snapshot helpers consume these arrays by their global names.
  # shellcheck disable=SC2034
  ZSTACK_IDENTITY_TEMP_PATHS=()
  # shellcheck disable=SC2034
  ZSTACK_IDENTITY_TEMP_IDENTITIES=()
  replacement_real_cp="$(command -v cp)"
  # Invoked by the helper in this subshell.
  # shellcheck disable=SC2329
  cp() {
    "$replacement_real_cp" "$@"
    case "${2:-}" in
      "$SNAPSHOT_CONTRACT/replaced."*)
        unlink "$2"
        "$replacement_real_cp" "$1" "$2"
        ;;
    esac
  }
  replacement_snapshot="unchanged-replacement-output"
  replacement_source_identity="unchanged-replacement-identity"
  if zstack_capture_regular_file_snapshot \
    "$SNAPSHOT_CONTRACT/source" replacement_snapshot replacement_source_identity \
    "$SNAPSHOT_CONTRACT/replaced.XXXXXX"; then
    fail "regular-file snapshot helper accepted a same-byte replacement inode"
  fi
  [[ "$replacement_snapshot" == "unchanged-replacement-output" ]] ||
    fail "regular-file snapshot helper published a replaced snapshot path"
  [[ "$replacement_source_identity" == "unchanged-replacement-identity" ]] ||
    fail "regular-file snapshot helper published a source identity after snapshot replacement"
  replaced_snapshot_path="$(find "$SNAPSHOT_CONTRACT" \
    -maxdepth 1 -name 'replaced.*' -type f -print -quit)"
  [[ -n "$replaced_snapshot_path" ]] ||
    fail "regular-file snapshot replacement fixture did not create a replacement"
  zstack_cleanup_identity_temp_files ||
    fail "regular-file snapshot replacement cleanup returned an unexpected failure"
  [[ -f "$replaced_snapshot_path" ]] ||
    fail "regular-file snapshot cleanup removed an identity-mismatched replacement"
  unlink "$replaced_snapshot_path"
)
pass "regular-file snapshots bind the allocated destination inode before publishing outputs"

published_temp=""
published_temp_identity=""
published_path="$SNAPSHOT_CONTRACT/published.txt"
zstack_make_identity_temp_file \
  published_temp "$SNAPSHOT_CONTRACT/publish.XXXXXX" published_temp_identity
printf '%s\n' "published bytes" > "$published_temp"
zstack_publish_identity_temp_file \
  "$published_temp" "$published_temp_identity" "$published_path" ||
  fail "identity-bound temporary file could not be published to an empty fixed path"
[[ ! -e "$published_temp" && ! -L "$published_temp" ]] ||
  fail "identity-bound temporary publication left its random source name"
[[ "$(zstack_file_identity "$published_path")" == "$published_temp_identity" ]] ||
  fail "identity-bound temporary publication changed the file identity"
[[ "$(zstack_file_link_count "$published_path")" == "1" ]] ||
  fail "identity-bound temporary publication left a multiply linked file"
zstack_cleanup_identity_temp_files ||
  fail "identity-bound published file could not be cleaned by its retargeted registration"
[[ ! -e "$published_path" && ! -L "$published_path" ]] ||
  fail "identity-bound published file was not removed during cleanup"

collision_temp=""
collision_temp_identity=""
collision_path="$SNAPSHOT_CONTRACT/publish-collision.txt"
printf '%s\n' "collision must survive" > "$collision_path"
zstack_make_identity_temp_file \
  collision_temp "$SNAPSHOT_CONTRACT/collision.XXXXXX" collision_temp_identity
printf '%s\n' "owned temporary bytes" > "$collision_temp"
if zstack_publish_identity_temp_file \
  "$collision_temp" "$collision_temp_identity" "$collision_path"; then
  fail "identity-bound temporary publication overwrote an existing destination"
fi
grep -qx 'collision must survive' "$collision_path" ||
  fail "identity-bound temporary publication changed an existing destination"
zstack_cleanup_identity_temp_files ||
  fail "identity-bound collision cleanup returned an unexpected failure"
[[ ! -e "$collision_temp" && ! -L "$collision_temp" ]] ||
  fail "identity-bound collision cleanup left its owned temporary source"
grep -qx 'collision must survive' "$collision_path" ||
  fail "identity-bound collision cleanup removed the existing destination"
unlink "$collision_path"
pass "identity-bound temporary files publish fixed names exclusively and retarget cleanup"

printf '%s' "12345" > "$STATE_FILE_CONTRACT/bounded"
[[ "$(zstack_file_size_bytes "$STATE_FILE_CONTRACT/bounded")" == "5" ]] || fail "portable state-file size detection returned the wrong byte count"
chmod 640 "$STATE_FILE_CONTRACT/bounded"
[[ "$(zstack_file_mode_bits "$STATE_FILE_CONTRACT/bounded")" == "640" ]] || fail "portable state-file mode detection returned the wrong permissions"
[[ "$(zstack_file_uid "$STATE_FILE_CONTRACT/bounded")" == "$(id -u)" ]] || fail "portable state-file ownership detection returned the wrong uid"
bounded_identity="$(zstack_file_identity "$STATE_FILE_CONTRACT/bounded")" || fail "portable file identity detection failed"
[[ "$bounded_identity" =~ ^[0-9]+:[0-9]+$ ]] || fail "portable file identity had an invalid format"
zstack_mode_is_owner_only 600 || fail "private state mode was rejected"
if zstack_mode_is_owner_only 640; then
  fail "group-readable state mode was accepted as private"
fi
if zstack_mode_is_owner_only invalid; then
  fail "invalid state mode was accepted as private"
fi
STATE_SIZE_GNU_BIN="$STATE_FILE_CONTRACT/gnu-stat-bin"
STATE_SIZE_FALLBACK_BIN="$STATE_FILE_CONTRACT/no-stat-bin"
STATE_LINK_COUNT_GNU_BIN="$STATE_FILE_CONTRACT/gnu-link-stat-bin"
mkdir -p "$STATE_SIZE_GNU_BIN" "$STATE_SIZE_FALLBACK_BIN" "$STATE_LINK_COUNT_GNU_BIN"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  '[[ "$1" == "-f" ]] && exit 1' \
  '[[ "$1" == "-c" && "$2" == "%s" ]] || exit 1' \
  'printf "5\n"' > "$STATE_SIZE_GNU_BIN/stat"
printf '%s\n' '#!/usr/bin/env bash' 'exit 9' > "$STATE_SIZE_GNU_BIN/wc"
printf '%s\n' '#!/usr/bin/env bash' 'exit 1' > "$STATE_SIZE_FALLBACK_BIN/stat"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  '[[ "$1" == "-f" ]] && exit 1' \
  '[[ "$1" == "-c" && "$2" == "%h" ]] || exit 1' \
  'printf "2\n"' > "$STATE_LINK_COUNT_GNU_BIN/stat"
chmod +x \
  "$STATE_SIZE_GNU_BIN/stat" \
  "$STATE_SIZE_GNU_BIN/wc" \
  "$STATE_SIZE_FALLBACK_BIN/stat" \
  "$STATE_LINK_COUNT_GNU_BIN/stat"
[[ "$(PATH="$STATE_SIZE_GNU_BIN:$PATH" zstack_file_size_bytes "$STATE_FILE_CONTRACT/bounded")" == "5" ]] || fail "state-file size detection rejected GNU stat semantics"
[[ "$(PATH="$STATE_SIZE_FALLBACK_BIN:$PATH" zstack_file_size_bytes "$STATE_FILE_CONTRACT/bounded")" == "5" ]] || fail "state-file size detection lost its wc fallback"
[[ "$(PATH="$STATE_LINK_COUNT_GNU_BIN:$PATH" zstack_file_link_count "$STATE_FILE_CONTRACT/bounded")" == "2" ]] ||
  fail "state-file hard-link detection rejected GNU stat semantics"
zstack_require_bounded_state_file "$STATE_FILE_CONTRACT/bounded" "test state file" 5 || fail "state size contract rejected its exact limit"
if zstack_require_bounded_state_file "$STATE_FILE_CONTRACT/bounded" "test state file" 4 >/dev/null 2>&1; then
  fail "state size contract accepted a file above its limit"
fi
printf 'left\0right\n' > "$STATE_FILE_CONTRACT/nul"
if zstack_require_bounded_state_file "$STATE_FILE_CONTRACT/nul" "test state file" 64 >/dev/null 2>&1; then
  fail "state text contract accepted a NUL byte that Bash cannot preserve"
fi
pass "state files cover portable size paths and reject lossy NUL parsing"

TEMP_IDENTITY_CREATED="$STATE_FILE_CONTRACT/temporary-created"
TEMP_IDENTITY_MOVED="$STATE_FILE_CONTRACT/temporary-created.moved"
printf '%s\n' "created bytes" > "$TEMP_IDENTITY_CREATED"
temporary_identity="$(zstack_file_identity "$TEMP_IDENTITY_CREATED")" || fail "temporary file identity could not be captured"
mv "$TEMP_IDENTITY_CREATED" "$TEMP_IDENTITY_MOVED"
printf '%s\n' "replacement bytes" > "$TEMP_IDENTITY_CREATED"
zstack_remove_regular_file_if_identity "$TEMP_IDENTITY_CREATED" "$temporary_identity" ||
  fail "identity-bound temporary cleanup returned an error for a replacement"
grep -qx "replacement bytes" "$TEMP_IDENTITY_CREATED" || fail "identity-bound temporary cleanup removed a replacement"
zstack_remove_regular_file_if_identity "$TEMP_IDENTITY_MOVED" "$temporary_identity" ||
  fail "identity-bound temporary cleanup could not remove its original file"
[[ ! -e "$TEMP_IDENTITY_MOVED" ]] || fail "identity-bound temporary cleanup left its original file"
pass "state ownership, permissions, and file identities are portable and replacement-safe"

TEMP_CLEANUP_RACE_PATH="$STATE_FILE_CONTRACT/temporary-raced"
TEMP_CLEANUP_RACE_MV_BIN="$STATE_FILE_CONTRACT/temporary-raced-mv-bin"
printf '%s\n' "owned temporary bytes" > "$TEMP_CLEANUP_RACE_PATH"
temp_cleanup_race_identity="$(zstack_file_identity "$TEMP_CLEANUP_RACE_PATH")" ||
  fail "raced temporary identity could not be captured"
mkdir -p "$TEMP_CLEANUP_RACE_MV_BIN"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'if [[ "${1:-}" == "$TEMP_PATH" ]]; then' \
  '  unlink "$TEMP_PATH"' \
  '  printf "%s\n" "temporary replacement must survive" > "$TEMP_PATH"' \
  'fi' \
  'exec "$REAL_MV_BIN" "$@"' > "$TEMP_CLEANUP_RACE_MV_BIN/mv"
chmod +x "$TEMP_CLEANUP_RACE_MV_BIN/mv"
if (
  REAL_MV_BIN="$(command -v mv)"
  TEMP_PATH="$TEMP_CLEANUP_RACE_PATH"
  export REAL_MV_BIN TEMP_PATH
  PATH="$TEMP_CLEANUP_RACE_MV_BIN:$PATH" \
    zstack_remove_regular_file_if_identity \
      "$TEMP_CLEANUP_RACE_PATH" "$temp_cleanup_race_identity"
); then
  fail "identity-bound temporary cleanup accepted an in-flight replacement"
fi
grep -qx 'temporary replacement must survive' "$TEMP_CLEANUP_RACE_PATH" ||
  fail "identity-bound temporary cleanup removed or displaced a raced replacement"
temp_cleanup_quarantines="$(find "$STATE_FILE_CONTRACT" -maxdepth 1 -name 'temporary-raced.zstack-remove.*' -print | wc -l | tr -d ' ')"
[[ "$temp_cleanup_quarantines" -eq 0 ]] ||
  fail "identity-bound temporary cleanup left a restored quarantine"
pass "identity-bound temporary cleanup quarantines and restores in-flight replacements"

STRICT_REMOVE_PATH="$STATE_FILE_CONTRACT/strict-remove"
STRICT_REMOVE_EXPECTED="$STATE_FILE_CONTRACT/strict-remove.expected"
STRICT_REMOVE_RM_BIN="$STATE_FILE_CONTRACT/strict-remove-rm-bin"
printf '%s\n' "strict removal bytes" > "$STRICT_REMOVE_PATH"
cp "$STRICT_REMOVE_PATH" "$STRICT_REMOVE_EXPECTED"
strict_remove_identity="$(zstack_file_identity "$STRICT_REMOVE_PATH")" ||
  fail "strict removal identity could not be captured"
mkdir -p "$STRICT_REMOVE_RM_BIN"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'last_argument=""' \
  'for argument in "$@"; do last_argument="$argument"; done' \
  'case "$last_argument" in' \
  '  *.zstack-remove.*/entry) exit 74 ;;' \
  '  *) exec "$REAL_RM_BIN" "$@" ;;' \
  'esac' > "$STRICT_REMOVE_RM_BIN/rm"
chmod +x "$STRICT_REMOVE_RM_BIN/rm"
if (
  REAL_RM_BIN="$(command -v rm)"
  export REAL_RM_BIN
  PATH="$STRICT_REMOVE_RM_BIN:$PATH" \
    zstack_remove_regular_file_strict_if_identity \
      "$STRICT_REMOVE_PATH" "$strict_remove_identity" "$STRICT_REMOVE_EXPECTED"
); then
  fail "strict removal accepted a failed quarantine delete"
fi
cmp -s "$STRICT_REMOVE_PATH" "$STRICT_REMOVE_EXPECTED" ||
  fail "strict removal did not restore bytes after quarantine delete failure"
strict_remove_quarantines="$(find "$STATE_FILE_CONTRACT" -maxdepth 1 -name 'strict-remove.zstack-remove.*' -print | wc -l | tr -d ' ')"
[[ "$strict_remove_quarantines" -eq 0 ]] ||
  fail "strict removal left a quarantine after restoring a delete failure"
zstack_remove_regular_file_strict_if_identity \
  "$STRICT_REMOVE_PATH" "$strict_remove_identity" "$STRICT_REMOVE_EXPECTED" ||
  fail "strict removal could not remove the restored original"
[[ ! -e "$STRICT_REMOVE_PATH" ]] ||
  fail "strict removal left its identity-matched original"
pass "strict quarantine deletion restores originals after delete failure"

STRICT_EXPECTED_RACE_PATH="$STATE_FILE_CONTRACT/strict-expected-race"
STRICT_EXPECTED_RACE_SNAPSHOT="$STATE_FILE_CONTRACT/strict-expected-race.snapshot"
STRICT_EXPECTED_RACE_ALIAS="$STATE_FILE_CONTRACT/strict-expected-race.alias"
STRICT_EXPECTED_RACE_MV_BIN="$STATE_FILE_CONTRACT/strict-expected-race-mv-bin"
printf '%s\n' "strict expected race bytes" > "$STRICT_EXPECTED_RACE_PATH"
cp "$STRICT_EXPECTED_RACE_PATH" "$STRICT_EXPECTED_RACE_SNAPSHOT"
strict_expected_race_identity="$(zstack_file_identity "$STRICT_EXPECTED_RACE_PATH")" ||
  fail "strict expected-race identity could not be captured"
mkdir -p "$STRICT_EXPECTED_RACE_MV_BIN"
# These single-quoted lines are the source of the generated fault-injection shim.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'if [[ "${1:-}" == "$RACE_PATH" ]]; then' \
  '  "$REAL_MV_BIN" "$@"' \
  '  ln "$EXPECTED_PATH" "$EXPECTED_ALIAS"' \
  '  exit 0' \
  'fi' \
  'exec "$REAL_MV_BIN" "$@"' > "$STRICT_EXPECTED_RACE_MV_BIN/mv"
chmod +x "$STRICT_EXPECTED_RACE_MV_BIN/mv"
if (
  REAL_MV_BIN="$(command -v mv)"
  RACE_PATH="$STRICT_EXPECTED_RACE_PATH"
  EXPECTED_PATH="$STRICT_EXPECTED_RACE_SNAPSHOT"
  EXPECTED_ALIAS="$STRICT_EXPECTED_RACE_ALIAS"
  export REAL_MV_BIN RACE_PATH EXPECTED_PATH EXPECTED_ALIAS
  PATH="$STRICT_EXPECTED_RACE_MV_BIN:$PATH" \
    zstack_remove_regular_file_strict_if_identity \
      "$STRICT_EXPECTED_RACE_PATH" \
      "$strict_expected_race_identity" \
      "$STRICT_EXPECTED_RACE_SNAPSHOT"
); then
  fail "strict removal trusted an expected snapshot hardlinked during quarantine"
fi
cmp -s "$STRICT_EXPECTED_RACE_PATH" "$STRICT_EXPECTED_RACE_SNAPSHOT" ||
  fail "strict removal did not restore the source after expected-snapshot drift"
[[ "$(zstack_file_link_count "$STRICT_EXPECTED_RACE_SNAPSHOT")" == "2" ]] ||
  fail "strict expected-race fixture did not preserve the external hardlink"
cmp -s "$STRICT_EXPECTED_RACE_ALIAS" "$STRICT_EXPECTED_RACE_SNAPSHOT" ||
  fail "strict removal changed the external expected-snapshot alias"
strict_expected_race_quarantines="$(find "$STATE_FILE_CONTRACT" -maxdepth 1 \
  -name 'strict-expected-race.zstack-remove.*' -print | wc -l | tr -d ' ')"
[[ "$strict_expected_race_quarantines" -eq 0 ]] ||
  fail "strict removal left a quarantine after expected-snapshot restoration"
unlink "$STRICT_EXPECTED_RACE_ALIAS"
zstack_remove_regular_file_strict_if_identity \
  "$STRICT_EXPECTED_RACE_PATH" \
  "$strict_expected_race_identity" \
  "$STRICT_EXPECTED_RACE_SNAPSHOT" ||
  fail "strict removal could not remove the restored expected-race source"
unlink "$STRICT_EXPECTED_RACE_SNAPSHOT"
pass "strict quarantine binds expected snapshot identity through the move"

printf '/tmp/zstack-root\n' > "$STATE_FILE_CONTRACT/root"
[[ "$(zstack_read_root_record "$STATE_FILE_CONTRACT/root")" == "/tmp/zstack-root" ]] || fail "root record parser rejected one safe absolute path"
zstack_require_safe_root_record "$STATE_FILE_CONTRACT/root" || fail "root record contract rejected canonical content"
printf '/tmp/zstack-root\n\n' > "$STATE_FILE_CONTRACT/root"
if zstack_require_safe_root_record "$STATE_FILE_CONTRACT/root" >/dev/null 2>&1; then
  fail "root record contract collapsed multiple logical lines"
fi
printf 'relative-root\n' > "$STATE_FILE_CONTRACT/root"
if zstack_require_safe_root_record "$STATE_FILE_CONTRACT/root" >/dev/null 2>&1; then
  fail "root record contract accepted a relative path"
fi
pass "root records require exactly one safe absolute path"

LOCK_TYPE_CONTRACT="$TEST_ROOT/lock-type-contract"
mkdir -p "$LOCK_TYPE_CONTRACT"
printf '%s\n' "preserve lock target" > "$LOCK_TYPE_CONTRACT/target"
ln -s "$LOCK_TYPE_CONTRACT/target" "$LOCK_TYPE_CONTRACT/symlink.lock"
mkfifo "$LOCK_TYPE_CONTRACT/fifo.lock"
mkdir -p "$LOCK_TYPE_CONTRACT/directory.lock"
mkfifo "$LOCK_TYPE_CONTRACT/directory.lock/pid"
for unsafe_lock in \
  "$LOCK_TYPE_CONTRACT/symlink.lock" \
  "$LOCK_TYPE_CONTRACT/fifo.lock" \
  "$LOCK_TYPE_CONTRACT/directory.lock"; do
  if zstack_acquire_pid_lock "$unsafe_lock" "test" > "$LOCK_TYPE_CONTRACT/error.log" 2>&1; then
    fail "lock contract accepted an unsafe lock type"
  fi
  grep -q "Refusing unsafe test lock" "$LOCK_TYPE_CONTRACT/error.log" || fail "lock contract reported the wrong unsafe-type failure"
done
[[ -L "$LOCK_TYPE_CONTRACT/symlink.lock" ]] || fail "lock contract removed an unsafe symlink"
[[ -p "$LOCK_TYPE_CONTRACT/fifo.lock" ]] || fail "lock contract removed an unsafe FIFO"
[[ -p "$LOCK_TYPE_CONTRACT/directory.lock/pid" ]] || fail "lock contract removed an unsafe owner file"
grep -qx "preserve lock target" "$LOCK_TYPE_CONTRACT/target" || fail "lock contract changed a symlink target"
pass "PID locks reject and preserve unsafe filesystem types"

LOCK_HARDLINK_CONTRACT="$TEST_ROOT/lock-hardlink-contract"
mkdir -p "$LOCK_HARDLINK_CONTRACT/hardlinked.lock"
printf '%s\n' "999999999" > "$LOCK_HARDLINK_CONTRACT/hardlinked.lock/pid"
ln "$LOCK_HARDLINK_CONTRACT/hardlinked.lock/pid" "$LOCK_HARDLINK_CONTRACT/owner-alias"
chmod 700 "$LOCK_HARDLINK_CONTRACT/hardlinked.lock"
chmod 600 "$LOCK_HARDLINK_CONTRACT/hardlinked.lock/pid" "$LOCK_HARDLINK_CONTRACT/owner-alias"
if zstack_acquire_pid_lock "$LOCK_HARDLINK_CONTRACT/hardlinked.lock" "test" \
  > "$LOCK_HARDLINK_CONTRACT/error.log" 2>&1; then
  fail "lock contract recovered a multiply linked owner file"
fi
grep -q 'PID lock owner must have exactly one hard link' "$LOCK_HARDLINK_CONTRACT/error.log" ||
  fail "lock contract reported the wrong hardlinked-owner failure"
grep -qx '999999999' "$LOCK_HARDLINK_CONTRACT/hardlinked.lock/pid" ||
  fail "lock contract changed a hardlinked owner file"
grep -qx '999999999' "$LOCK_HARDLINK_CONTRACT/owner-alias" ||
  fail "lock contract changed a hardlinked owner alias"
pass "PID locks reject and preserve hardlinked owner metadata"

LOCK_OWNER_CONTRACT="$TEST_ROOT/lock-owner-contract"
mkdir -p \
  "$LOCK_OWNER_CONTRACT/empty-directory.lock" \
  "$LOCK_OWNER_CONTRACT/malformed-directory.lock" \
  "$LOCK_OWNER_CONTRACT/missing-directory.lock" \
  "$LOCK_OWNER_CONTRACT/unreadable-directory.lock"
: > "$LOCK_OWNER_CONTRACT/empty-file.lock"
: > "$LOCK_OWNER_CONTRACT/empty-directory.lock/pid"
printf 'stale\n' > "$LOCK_OWNER_CONTRACT/malformed-file.lock"
printf 'stale\n' > "$LOCK_OWNER_CONTRACT/malformed-directory.lock/pid"
printf '999999999\n888888888\n' > "$LOCK_OWNER_CONTRACT/multiline-file.lock"
printf '%040d\n' 1 > "$LOCK_OWNER_CONTRACT/oversized-file.lock"
printf '999999999\n' > "$LOCK_OWNER_CONTRACT/unreadable-file.lock"
printf '999999999\n' > "$LOCK_OWNER_CONTRACT/unreadable-directory.lock/pid"
chmod 700 \
  "$LOCK_OWNER_CONTRACT/empty-directory.lock" \
  "$LOCK_OWNER_CONTRACT/malformed-directory.lock" \
  "$LOCK_OWNER_CONTRACT/missing-directory.lock" \
  "$LOCK_OWNER_CONTRACT/unreadable-directory.lock"
chmod 600 \
  "$LOCK_OWNER_CONTRACT/empty-file.lock" \
  "$LOCK_OWNER_CONTRACT/empty-directory.lock/pid" \
  "$LOCK_OWNER_CONTRACT/malformed-file.lock" \
  "$LOCK_OWNER_CONTRACT/malformed-directory.lock/pid" \
  "$LOCK_OWNER_CONTRACT/multiline-file.lock" \
  "$LOCK_OWNER_CONTRACT/oversized-file.lock" \
  "$LOCK_OWNER_CONTRACT/unreadable-file.lock" \
  "$LOCK_OWNER_CONTRACT/unreadable-directory.lock/pid"
chmod 000 \
  "$LOCK_OWNER_CONTRACT/unreadable-file.lock" \
  "$LOCK_OWNER_CONTRACT/unreadable-directory.lock/pid"
for incomplete_lock in \
  "$LOCK_OWNER_CONTRACT/empty-file.lock" \
  "$LOCK_OWNER_CONTRACT/empty-directory.lock" \
  "$LOCK_OWNER_CONTRACT/malformed-file.lock" \
  "$LOCK_OWNER_CONTRACT/malformed-directory.lock" \
  "$LOCK_OWNER_CONTRACT/missing-directory.lock" \
  "$LOCK_OWNER_CONTRACT/multiline-file.lock" \
  "$LOCK_OWNER_CONTRACT/oversized-file.lock" \
  "$LOCK_OWNER_CONTRACT/unreadable-file.lock" \
  "$LOCK_OWNER_CONTRACT/unreadable-directory.lock"; do
  if zstack_acquire_pid_lock "$incomplete_lock" "test" > "$LOCK_OWNER_CONTRACT/error.log" 2>&1; then
    fail "lock contract recovered a lock whose owner could not be audited"
  fi
  [[ -e "$incomplete_lock" ]] || fail "lock contract removed a lock whose owner could not be audited"
done
[[ -f "$LOCK_OWNER_CONTRACT/empty-file.lock" ]] || fail "lock contract replaced an empty legacy lock"
[[ -f "$LOCK_OWNER_CONTRACT/empty-directory.lock/pid" ]] || fail "lock contract replaced an empty directory-lock owner"
[[ "$((8#$(zstack_file_mode_bits "$LOCK_OWNER_CONTRACT/unreadable-file.lock")))" == "0" ]] || fail "lock contract changed unreadable legacy-lock permissions"
[[ "$((8#$(zstack_file_mode_bits "$LOCK_OWNER_CONTRACT/unreadable-directory.lock/pid")))" == "0" ]] || fail "lock contract changed unreadable owner-file permissions"
chmod 600 \
  "$LOCK_OWNER_CONTRACT/unreadable-file.lock" \
  "$LOCK_OWNER_CONTRACT/unreadable-directory.lock/pid"
grep -qx "999999999" "$LOCK_OWNER_CONTRACT/unreadable-file.lock" || fail "lock contract changed an unreadable legacy lock"
grep -qx "999999999" "$LOCK_OWNER_CONTRACT/unreadable-directory.lock/pid" || fail "lock contract changed an unreadable owner file"
[[ ! -e "$LOCK_OWNER_CONTRACT/missing-directory.lock/pid" ]] || fail "lock contract invented metadata while refusing an ownerless lock"
pass "PID lock recovery preserves missing, malformed, oversized, and unreadable owner state"

LOCK_INIT_FAILURE="$LOCK_OWNER_CONTRACT/init-failure.lock"
if (
  # Invoked indirectly by zstack_acquire_pid_lock in this subshell.
  # shellcheck disable=SC2329
  printf() {
    if [[ "${2:-}" == "$$" ]]; then
      return 74
    fi
    # Delegate the original format and arguments for every non-injected call.
    # shellcheck disable=SC2059
    builtin printf "$@"
  }
  zstack_acquire_pid_lock "$LOCK_INIT_FAILURE" "test"
) > "$LOCK_OWNER_CONTRACT/init-failure.log" 2>&1; then
  fail "lock contract accepted a failed owner write"
fi
[[ ! -e "$LOCK_INIT_FAILURE" ]] ||
  fail "lock contract left a directory after owner-write failure"
lock_init_quarantines="$(find "$LOCK_OWNER_CONTRACT" -maxdepth 2 -name 'pid.zstack-remove.*' -print | wc -l | tr -d ' ')"
[[ "$lock_init_quarantines" -eq 0 ]] ||
  fail "lock contract left an owner quarantine after initialization failure"
grep -q 'Could not initialize test lock' "$LOCK_OWNER_CONTRACT/init-failure.log" ||
  fail "lock contract reported the wrong owner-write failure"
pass "PID lock initialization verifies owner state and cleans failed writes"

zstack_acquire_pid_lock "$LOCK_OWNER_CONTRACT/private.lock" "test" || fail "lock contract could not create a fresh private lock"
[[ "$(zstack_file_mode_bits "$LOCK_OWNER_CONTRACT/private.lock")" == "700" ]] || fail "lock contract created a non-private lock directory"
[[ "$(zstack_file_mode_bits "$LOCK_OWNER_CONTRACT/private.lock/pid")" == "600" ]] || fail "lock contract created non-private owner metadata"
zstack_release_pid_lock "$LOCK_OWNER_CONTRACT/private.lock"
[[ ! -e "$LOCK_OWNER_CONTRACT/private.lock" ]] || fail "lock contract did not release a freshly created lock"
pass "PID locks create owner-private directories and metadata"

mkdir -p \
  "$LOCK_OWNER_CONTRACT/nonprivate-directory.lock" \
  "$LOCK_OWNER_CONTRACT/nonprivate-owner.lock"
printf '999999999\n' > "$LOCK_OWNER_CONTRACT/nonprivate-file.lock"
printf '999999999\n' > "$LOCK_OWNER_CONTRACT/nonprivate-directory.lock/pid"
printf '999999999\n' > "$LOCK_OWNER_CONTRACT/nonprivate-owner.lock/pid"
chmod 644 "$LOCK_OWNER_CONTRACT/nonprivate-file.lock"
chmod 755 "$LOCK_OWNER_CONTRACT/nonprivate-directory.lock"
chmod 600 "$LOCK_OWNER_CONTRACT/nonprivate-directory.lock/pid"
chmod 700 "$LOCK_OWNER_CONTRACT/nonprivate-owner.lock"
chmod 644 "$LOCK_OWNER_CONTRACT/nonprivate-owner.lock/pid"
for nonprivate_lock in \
  "$LOCK_OWNER_CONTRACT/nonprivate-file.lock" \
  "$LOCK_OWNER_CONTRACT/nonprivate-directory.lock" \
  "$LOCK_OWNER_CONTRACT/nonprivate-owner.lock"; do
  if zstack_acquire_pid_lock "$nonprivate_lock" "test" > "$LOCK_OWNER_CONTRACT/error.log" 2>&1; then
    fail "lock contract acquired a lock with non-private metadata"
  fi
  [[ -e "$nonprivate_lock" ]] || fail "lock contract removed a lock with non-private metadata"
done
pass "PID locks reject and preserve non-private lock metadata"

mkdir "$LOCK_TYPE_CONTRACT/unexpected.lock"
printf '999999999\n' > "$LOCK_TYPE_CONTRACT/unexpected.lock/pid"
printf 'preserve unexpected lock state\n' > "$LOCK_TYPE_CONTRACT/unexpected.lock/.sentinel"
chmod 700 "$LOCK_TYPE_CONTRACT/unexpected.lock"
chmod 600 "$LOCK_TYPE_CONTRACT/unexpected.lock/pid"
if zstack_acquire_pid_lock "$LOCK_TYPE_CONTRACT/unexpected.lock" "test" > "$LOCK_TYPE_CONTRACT/error.log" 2>&1; then
  fail "lock contract recovered a directory with unexpected contents"
fi
grep -q "unexpected entry" "$LOCK_TYPE_CONTRACT/error.log" || fail "lock contract reported the wrong unexpected-entry failure"
grep -qx "999999999" "$LOCK_TYPE_CONTRACT/unexpected.lock/pid" || fail "lock contract removed stale owner metadata before refusing recovery"
grep -qx "preserve unexpected lock state" "$LOCK_TYPE_CONTRACT/unexpected.lock/.sentinel" || fail "lock contract changed unexpected lock state"
pass "PID lock recovery preserves directories with unexpected contents"

LOCK_RELEASE_CONTRACT="$TEST_ROOT/lock-release-contract"
mkdir -p \
  "$LOCK_RELEASE_CONTRACT/directory.lock" \
  "$LOCK_RELEASE_CONTRACT/unexpected-directory.lock"
printf '%s\n' "$$" > "$LOCK_RELEASE_CONTRACT/owner"
ln -s "$LOCK_RELEASE_CONTRACT/owner" "$LOCK_RELEASE_CONTRACT/symlink.lock"
ln -s "$LOCK_RELEASE_CONTRACT/owner" "$LOCK_RELEASE_CONTRACT/directory.lock/pid"
printf '%s\n' "$$" > "$LOCK_RELEASE_CONTRACT/unexpected-directory.lock/pid"
printf 'preserve release state\n' > "$LOCK_RELEASE_CONTRACT/unexpected-directory.lock/.sentinel"
zstack_release_pid_lock "$LOCK_RELEASE_CONTRACT/symlink.lock"
zstack_release_pid_lock "$LOCK_RELEASE_CONTRACT/directory.lock"
zstack_release_pid_lock "$LOCK_RELEASE_CONTRACT/unexpected-directory.lock"
[[ -L "$LOCK_RELEASE_CONTRACT/symlink.lock" ]] || fail "lock release removed a replaced lock symlink"
[[ -L "$LOCK_RELEASE_CONTRACT/directory.lock/pid" ]] || fail "lock release removed a replaced owner symlink"
grep -qx "$$" "$LOCK_RELEASE_CONTRACT/unexpected-directory.lock/pid" || fail "lock release removed owner metadata beside unexpected state"
grep -qx "preserve release state" "$LOCK_RELEASE_CONTRACT/unexpected-directory.lock/.sentinel" || fail "lock release changed unexpected state"
grep -qx "$$" "$LOCK_RELEASE_CONTRACT/owner" || fail "lock release changed an unsafe symlink target"
pass "PID lock release preserves replaced entries and unexpected contents"

LOCK_INTERNAL_RACE_BIN="$LOCK_RELEASE_CONTRACT/race-mv-bin"
LOCK_RELEASE_RACE="$LOCK_RELEASE_CONTRACT/raced-release.lock"
LOCK_RECOVERY_RACE="$LOCK_RELEASE_CONTRACT/raced-recovery.lock"
mkdir -p "$LOCK_INTERNAL_RACE_BIN" "$LOCK_RELEASE_RACE" "$LOCK_RECOVERY_RACE"
printf '%s\n' "$$" > "$LOCK_RELEASE_RACE/pid"
printf '%s\n' "999999999" > "$LOCK_RECOVERY_RACE/pid"
chmod 700 "$LOCK_RELEASE_RACE" "$LOCK_RECOVERY_RACE"
chmod 600 "$LOCK_RELEASE_RACE/pid" "$LOCK_RECOVERY_RACE/pid"
# These single-quoted lines are the source of the generated fault-injection shim.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'if [[ "${1:-}" == "$LOCK_OWNER_PATH" ]]; then' \
  '  unlink "$LOCK_OWNER_PATH"' \
  '  printf "%s\n" "$REPLACEMENT_PID" > "$LOCK_OWNER_PATH"' \
  '  chmod 600 "$LOCK_OWNER_PATH"' \
  'fi' \
  'exec "$REAL_MV_BIN" "$@"' > "$LOCK_INTERNAL_RACE_BIN/mv"
chmod +x "$LOCK_INTERNAL_RACE_BIN/mv"
(
  REAL_MV_BIN="$(command -v mv)"
  LOCK_OWNER_PATH="$LOCK_RELEASE_RACE/pid"
  REPLACEMENT_PID="999999999"
  export REAL_MV_BIN LOCK_OWNER_PATH REPLACEMENT_PID
  PATH="$LOCK_INTERNAL_RACE_BIN:$PATH" zstack_release_pid_lock "$LOCK_RELEASE_RACE"
)
grep -qx '999999999' "$LOCK_RELEASE_RACE/pid" ||
  fail "PID lock release removed or displaced an in-flight owner replacement"
lock_release_race_quarantines="$(find "$LOCK_RELEASE_RACE" -maxdepth 1 -name 'pid.zstack-remove.*' -print | wc -l | tr -d ' ')"
[[ "$lock_release_race_quarantines" -eq 0 ]] ||
  fail "PID lock release left a restored owner quarantine"
if (
  REAL_MV_BIN="$(command -v mv)"
  LOCK_OWNER_PATH="$LOCK_RECOVERY_RACE/pid"
  REPLACEMENT_PID="$$"
  export REAL_MV_BIN LOCK_OWNER_PATH REPLACEMENT_PID
  PATH="$LOCK_INTERNAL_RACE_BIN:$PATH" \
    zstack_acquire_pid_lock "$LOCK_RECOVERY_RACE" "test"
) > "$LOCK_RELEASE_CONTRACT/internal-race.log" 2>&1; then
  fail "PID lock recovery acquired a directory whose owner changed during removal"
fi
grep -qx "$$" "$LOCK_RECOVERY_RACE/pid" ||
  fail "PID lock recovery removed or displaced an in-flight active owner"
grep -q 'Another test operation is in progress' "$LOCK_RELEASE_CONTRACT/internal-race.log" ||
  fail "PID lock recovery did not re-evaluate the restored active owner"
lock_recovery_race_quarantines="$(find "$LOCK_RECOVERY_RACE" -maxdepth 1 -name 'pid.zstack-remove.*' -print | wc -l | tr -d ' ')"
[[ "$lock_recovery_race_quarantines" -eq 0 ]] ||
  fail "PID lock recovery left a restored owner quarantine"
pass "PID lock recovery and release preserve in-flight owner replacements"

quoted_control_target="$(zstack_quote_for_log $'unsafe\033[31m\nlink-target')"
if [[ "$quoted_control_target" == *$'\033'* || "$quoted_control_target" == *$'\n'* ]]; then
  fail "log quoting retained a raw terminal control character"
fi
CONTROL_TARGET_LINK="$TEST_ROOT/control-target-link"
DOT_TARGET_LINK="$TEST_ROOT/dot-target-link"
ln -s $'/tmp/unsafe\033[31m-target' "$CONTROL_TARGET_LINK"
ln -s '/tmp/.' "$DOT_TARGET_LINK"
if zstack_resolve_link_target "$CONTROL_TARGET_LINK" >/dev/null 2>&1; then
  fail "link resolver accepted a control character in the target"
fi
if zstack_resolve_link_target "$DOT_TARGET_LINK" >/dev/null 2>&1; then
  fail "link resolver accepted a non-canonical dot leaf"
fi
pass "link targets are safely quoted and reject control or dot-leaf ambiguity"

ruby_warning_output="$({
  for ruby_file in "$ROOT"/scripts/*.rb "$ROOT"/scripts/lib/*.rb; do
    ruby -wc "$ruby_file" >/dev/null
  done
} 2>&1)"
[[ -z "$ruby_warning_output" ]] || fail "Ruby warning-free compile failed: $ruby_warning_output"
pass "Ruby scripts compile without warnings"

HOME=/ "$ROOT/scripts/setup.sh" --help >/dev/null
HOME=/ "$ROOT/scripts/unlink.sh" --help >/dev/null
"$ROOT/scripts/new-skill.sh" --help >/dev/null
CLI_HOME="$TEST_ROOT/cli-home"
if HOME="$CLI_HOME" "$ROOT/scripts/setup.sh" --hosts agents,,codex > "$TEST_ROOT/host-list.log" 2>&1; then
  fail "setup accepted an empty host filter item"
fi
grep -q "Invalid --hosts list" "$TEST_ROOT/host-list.log" || fail "setup reported the wrong host-list failure"
if HOME="$CLI_HOME" "$ROOT/scripts/setup.sh" --hosts agents,agents > "$TEST_ROOT/duplicate-host.log" 2>&1; then
  fail "setup accepted a duplicate host filter item"
fi
grep -q "Duplicate host profile" "$TEST_ROOT/duplicate-host.log" || fail "setup reported the wrong duplicate-host failure"
[[ ! -e "$CLI_HOME/.zstack" ]] || fail "invalid CLI input changed HOME"

assert_eval_cli_rejects() {
  local expected="$1"
  shift
  if "$@" > "$TEST_ROOT/eval-cli-limit.log" 2>&1; then
    fail "evaluation CLI accepted an unsafe resource bound: $*"
  fi
  grep -q -- "$expected" "$TEST_ROOT/eval-cli-limit.log" ||
    fail "evaluation CLI reported the wrong resource-bound failure: $*"
}
assert_eval_cli_rejects "--jobs must be between 1 and 32" \
  "$ROOT/scripts/run-codex-routing-evals.rb" --dry-run --jobs 33
assert_eval_cli_rejects "--timeout-seconds must be between 1 and 86400" \
  "$ROOT/scripts/run-codex-behavioral-evals.rb" --dry-run --timeout-seconds 86401
assert_eval_cli_rejects "--truncate-descriptions must be between 80 and 4096" \
  "$ROOT/scripts/run-codex-routing-evals.rb" --dry-run --truncate-descriptions 4097
assert_eval_cli_rejects "--max-budget-usd must be finite and greater than zero" \
  "$ROOT/scripts/run-claude-routing-evals.rb" --dry-run --max-budget-usd 1e309
assert_eval_cli_rejects "--max-budget-usd must be finite and greater than zero" \
  "$ROOT/scripts/run-claude-behavioral-evals.rb" --dry-run --max-budget-usd 1e309
assert_eval_cli_rejects "--max-turns must be between 1 and 100" \
  "$ROOT/scripts/run-grok-routing-evals.rb" --dry-run --max-turns 101
assert_eval_cli_rejects "--max-turns must be between 1 and 100" \
  "$ROOT/scripts/run-grok-behavioral-evals.rb" --dry-run --max-turns 101

STRICT_YAML_RUNNER_FIXTURE="$(copy_fixture strict-yaml-runner)"
ruby -e '
  path = ARGV.fetch(0)
  content = File.read(path)
  replacement = content.sub(/^(    expected_skill: .+)$/) { |line| "    expected_skill: none\n#{line}" }
  abort "duplicate routing fixture did not change" if replacement == content
  File.write(path, replacement)
' "$STRICT_YAML_RUNNER_FIXTURE/evals/routing.yaml"
if "$STRICT_YAML_RUNNER_FIXTURE/scripts/run-codex-routing-evals.rb" \
  --dry-run --case market-vague > "$TEST_ROOT/strict-yaml-runner.log" 2>&1; then
  fail "routing runner accepted a duplicate manifest key without doctor"
fi
grep -q 'duplicate key "expected_skill"' "$TEST_ROOT/strict-yaml-runner.log" ||
  fail "routing runner reported the wrong duplicate manifest failure"
cp "$ROOT/evals/routing.yaml" "$STRICT_YAML_RUNNER_FIXTURE/evals/routing.real.yaml"
rm -f "$STRICT_YAML_RUNNER_FIXTURE/evals/routing.yaml"
ln -s "routing.real.yaml" "$STRICT_YAML_RUNNER_FIXTURE/evals/routing.yaml"
if "$STRICT_YAML_RUNNER_FIXTURE/scripts/run-codex-routing-evals.rb" \
  --dry-run --case market-vague > "$TEST_ROOT/linked-yaml-runner.log" 2>&1; then
  fail "routing runner followed a linked eval manifest without doctor"
fi
grep -q "must be a regular non-link file" "$TEST_ROOT/linked-yaml-runner.log" ||
  fail "routing runner reported the wrong linked manifest failure"
rm -f "$STRICT_YAML_RUNNER_FIXTURE/evals/routing.yaml"
dd if=/dev/zero of="$STRICT_YAML_RUNNER_FIXTURE/evals/routing.yaml" \
  bs=$((2 * 1024 * 1024 + 1)) count=1 2>/dev/null
if "$STRICT_YAML_RUNNER_FIXTURE/scripts/run-codex-routing-evals.rb" \
  --dry-run --case market-vague > "$TEST_ROOT/oversized-yaml-runner.log" 2>&1; then
  fail "routing runner accepted an unbounded eval manifest without doctor"
fi
grep -q "exceeds 2097152 bytes" "$TEST_ROOT/oversized-yaml-runner.log" ||
  fail "routing runner reported the wrong oversized manifest failure"
mv "$STRICT_YAML_RUNNER_FIXTURE/evals" "$STRICT_YAML_RUNNER_FIXTURE/evals.real"
ln -s "evals.real" "$STRICT_YAML_RUNNER_FIXTURE/evals"
if "$STRICT_YAML_RUNNER_FIXTURE/scripts/run-codex-routing-evals.rb" \
  --dry-run --case market-vague > "$TEST_ROOT/linked-yaml-parent-runner.log" 2>&1; then
  fail "routing runner followed a linked eval-manifest parent directory without doctor"
fi
grep -q "parent directory must be a real directory" "$TEST_ROOT/linked-yaml-parent-runner.log" ||
  fail "routing runner reported the wrong linked parent-directory failure"

UNSAFE_ROUTING_ID_FIXTURE="$(copy_fixture unsafe-routing-id)"
ruby -ryaml -e '
  path = ARGV.fetch(0)
  document = YAML.safe_load(File.read(path), aliases: false)
  document.fetch("cases").first["id"] = "../../escaped-prompt"
  File.write(path, YAML.dump(document))
' "$UNSAFE_ROUTING_ID_FIXTURE/evals/routing.yaml"
if "$UNSAFE_ROUTING_ID_FIXTURE/scripts/run-codex-routing-evals.rb" \
  --dry-run --case ../../escaped-prompt --output "$TEST_ROOT/unsafe-routing-output" \
  > "$TEST_ROOT/unsafe-routing-id.log" 2>&1; then
  fail "routing runner accepted a path-traversing case id without doctor"
fi
grep -q "routing cases id must be a kebab-case string" "$TEST_ROOT/unsafe-routing-id.log" ||
  fail "routing runner reported the wrong unsafe case-id failure"
[[ ! -e "$TEST_ROOT/escaped-prompt.txt" ]] || fail "routing runner wrote a prompt outside its prompt directory"

UNSAFE_BEHAVIOR_ID_FIXTURE="$(copy_fixture unsafe-behavior-id)"
ruby -ryaml -e '
  path = ARGV.fetch(0)
  document = YAML.safe_load(File.read(path), aliases: false)
  document.fetch("cases").first["id"] = "../../escaped-behavior-prompt"
  File.write(path, YAML.dump(document))
' "$UNSAFE_BEHAVIOR_ID_FIXTURE/evals/cases.yaml"
if "$UNSAFE_BEHAVIOR_ID_FIXTURE/scripts/run-codex-behavioral-evals.rb" \
  --dry-run --case ../../escaped-behavior-prompt --output "$TEST_ROOT/unsafe-behavior-output" \
  > "$TEST_ROOT/unsafe-behavior-id.log" 2>&1; then
  fail "behavioral runner accepted a path-traversing case id without doctor"
fi
grep -q "behavioral cases id must be a kebab-case string" "$TEST_ROOT/unsafe-behavior-id.log" ||
  fail "behavioral runner reported the wrong unsafe case-id failure"
[[ ! -e "$TEST_ROOT/escaped-behavior-prompt.txt" ]] || fail "behavioral runner wrote a prompt outside its prompt directory"

UNSAFE_CATALOG_PATH_FIXTURE="$(copy_fixture unsafe-catalog-path)"
ruby -ryaml -e '
  path = ARGV.fetch(0)
  document = YAML.safe_load(File.read(path), aliases: false)
  document.fetch("skills").find { |entry| entry["status"] == "active" }["path"] = "../outside-skill"
  File.write(path, YAML.dump(document))
' "$UNSAFE_CATALOG_PATH_FIXTURE/catalog.yaml"
if "$UNSAFE_CATALOG_PATH_FIXTURE/scripts/run-codex-routing-evals.rb" \
  --dry-run --case market-vague --output "$TEST_ROOT/unsafe-catalog-output" \
  > "$TEST_ROOT/unsafe-catalog-path.log" 2>&1; then
  fail "routing runner accepted a catalog path outside skills/ without doctor"
fi
grep -q "skill path must stay inside skills/" "$TEST_ROOT/unsafe-catalog-path.log" ||
  fail "routing runner reported the wrong catalog-path failure"

DUPLICATE_CASE_ID_FIXTURE="$(copy_fixture duplicate-case-id)"
ruby -ryaml -e '
  path = ARGV.fetch(0)
  document = YAML.safe_load(File.read(path), aliases: false)
  cases = document.fetch("cases")
  cases.fetch(1)["id"] = cases.fetch(0).fetch("id")
  File.write(path, YAML.dump(document))
' "$DUPLICATE_CASE_ID_FIXTURE/evals/routing.yaml"
if "$DUPLICATE_CASE_ID_FIXTURE/scripts/run-codex-routing-evals.rb" \
  --dry-run --case market-vague > "$TEST_ROOT/duplicate-case-id.log" 2>&1; then
  fail "routing runner accepted duplicate case ids without doctor"
fi
grep -q "routing cases contains duplicate id" "$TEST_ROOT/duplicate-case-id.log" ||
  fail "routing runner reported the wrong duplicate case-id failure"
pass "evaluation runners reject unsafe ids and catalog path escapes before writing"

pass "CLI help, host filters, and evaluation resource bounds fail closed"

if [[ "$TEST_SCOPE" == "smoke" ]]; then
  echo "Smoke tests passed. Full integration suite was not run."
  exit 0
fi

test_heavy_no_ruby_candidate_limits

ruby -I "$ROOT/scripts/lib" -reval_process_supervisor -e '
  supervisor = Zstack::EvalProcessSupervisor
  supervisor.send(:remove_const, :TERM_GRACE_SECONDS)
  supervisor.const_set(:TERM_GRACE_SECONDS, 0.1)
  supervisor.send(:remove_const, :POLL_SECONDS)
  supervisor.const_set(:POLL_SECONDS, 0.01)

  normal_sentinel = ARGV.fetch(0)
  normal_pid = Process.spawn(
    "/bin/sh", "-c",
    %q{(trap "" HUP TERM; sleep 0.3; printf leaked > "$1") & exit 0},
    "zstack-supervisor", normal_sentinel,
    pgroup: true
  )
  status, timed_out, output_limited = supervisor.wait(
    normal_pid,
    started_at: supervisor.monotonic_time,
    timeout_seconds: 2
  )
  abort "normal leader status changed" unless status.success? && !timed_out && !output_limited
  sleep 0.4
  abort "successful leader left a background process" if File.exist?(normal_sentinel)

  timeout_sentinel = ARGV.fetch(1)
  timeout_pid = Process.spawn(
    "/bin/sh", "-c",
    %q{(trap "" HUP TERM; sleep 0.3; printf leaked > "$1") & sleep 10},
    "zstack-supervisor", timeout_sentinel,
    pgroup: true
  )
  _status, timed_out, output_limited = supervisor.wait(
    timeout_pid,
    started_at: supervisor.monotonic_time,
    timeout_seconds: 0.05
  )
  abort "timeout classification changed" unless timed_out && !output_limited
  sleep 0.4
  abort "timed-out leader left a background process" if File.exist?(timeout_sentinel)
' "$TEST_ROOT/supervisor-normal-leak" "$TEST_ROOT/supervisor-timeout-leak"
pass "process supervision reaps background groups after success and timeout"

ruby -I "$ROOT/scripts/lib" -reval_skill_snapshot -rfileutils -rtmpdir -e '
  helper = Zstack::EvalSkillSnapshot
  state = {
    "SKILL.md" => "---\nname: z-test\n---\n\xFF".b.freeze,
    "references/quality-bar.md" => "# Quality bar\n".freeze
  }.freeze
  Dir.mktmpdir("zstack-skill-materialization.") do |workspace|
    target = File.join(workspace, ".zstack-skill", "z-test")
    helper.materialize!(target, state)
    abort "materialized skill changed captured binary bytes" unless File.binread(File.join(target, "SKILL.md")) == state.fetch("SKILL.md")
    abort "exact materialized skill failed verification" if helper.validation_error(target, state)

    File.binwrite(File.join(target, "SKILL.md"), "changed\n")
    error = helper.validation_error(target, state)
    abort "skill verifier accepted changed bytes" unless error&.include?("changed after runner capture")
    File.binwrite(File.join(target, "SKILL.md"), state.fetch("SKILL.md"))

    Dir.mkdir(File.join(target, "unexpected-empty-directory"))
    error = helper.validation_error(target, state)
    abort "skill verifier accepted an unexpected empty directory" unless error&.include?("changed after runner capture")
    Dir.rmdir(File.join(target, "unexpected-empty-directory"))

    linked = File.join(target, "linked.md")
    File.link(File.join(target, "SKILL.md"), linked)
    error = helper.validation_error(target, state)
    abort "skill verifier accepted a multiply linked file" unless error&.include?("multiple hard links")
    File.unlink(linked)
  end
'
pass "behavioral workspaces materialize and verify exact in-memory skill bytes"

WORKSPACE_WATCHDOG_ROOT="$TEST_ROOT/workspace-watchdog"
mkdir -p "$WORKSPACE_WATCHDOG_ROOT/.git" "$WORKSPACE_WATCHDOG_ROOT/.zstack-skill" "$WORKSPACE_WATCHDOG_ROOT/artifacts"
ruby -I "$ROOT/scripts/lib" -reval_workspace_watchdog -rfileutils -e '
  helper = Zstack::EvalWorkspaceWatchdog
  root = ARGV.fetch(0)
  abort "empty artifact workspace failed monitoring" if helper.artifact_error(root, retained_files: 0, retained_bytes: 0)

  file = File.join(root, "artifacts", "new.bin")
  File.binwrite(file, "123456")
  error = helper.artifact_error(
    root,
    retained_files: 0,
    retained_bytes: Zstack::EvalLimits::MAX_RUN_ARTIFACT_BYTES - 5
  )
  abort "watchdog lost the cumulative byte limit" unless error&.include?("retained bytes")
  File.unlink(file)

  101.times { |index| File.write(File.join(root, ".git", format("%03d", index)), "") }
  error = helper.artifact_error(root, retained_files: 0, retained_bytes: 0)
  abort "watchdog accepted unbounded Git state" unless error&.include?("Git directory exceeds 100 files")
  FileUtils.rm_rf(File.join(root, ".git"))
  Dir.mkdir(File.join(root, ".git"))

  copied_skill = File.join(root, ".zstack-skill", "z-test")
  FileUtils.mkdir_p(copied_skill)
  101.times { |index| File.write(File.join(copied_skill, format("%03d", index)), "") }
  error = helper.artifact_error(root, retained_files: 0, retained_bytes: 0, copied_skill: copied_skill)
  abort "watchdog accepted an unbounded copied skill" unless error&.include?("skill package has 101 files")
  FileUtils.rm_rf(copied_skill)

  FileUtils.mkdir_p(copied_skill)
  copied_skill_state = { "SKILL.md" => "captured skill\n".freeze }.freeze
  File.write(File.join(copied_skill, "SKILL.md"), copied_skill_state.fetch("SKILL.md"))
  error = helper.artifact_error(
    root,
    retained_files: 0,
    retained_bytes: 0,
    copied_skill: copied_skill,
    copied_skill_state: copied_skill_state
  )
  abort "watchdog rejected exact copied skill bytes" if error
  File.write(File.join(copied_skill, "SKILL.md"), "runtime drift\n")
  error = helper.artifact_error(
    root,
    retained_files: 0,
    retained_bytes: 0,
    copied_skill: copied_skill,
    copied_skill_state: copied_skill_state
  )
  abort "watchdog accepted copied skill byte drift" unless error&.include?("changed after runner capture")
  FileUtils.rm_rf(copied_skill)

  host_home = "#{root}-host-home"
  Dir.mkdir(host_home)
  201.times { |index| File.write(File.join(host_home, format("%03d", index)), "") }
  error = helper.artifact_error(root, retained_files: 0, retained_bytes: 0, host_home: host_home)
  abort "watchdog accepted an unbounded host home" unless error&.include?("host home exceeds 200 files")

  hardlink_target = "#{root}-hardlink-target"
  hardlink = File.join(root, "artifacts", "linked.bin")
  File.write(hardlink_target, "external inode\n")
  File.link(hardlink_target, hardlink)
  error = helper.artifact_error(root, retained_files: 0, retained_bytes: 0)
  abort "watchdog accepted a multiply linked artifact" unless error&.include?("multiply linked file")
  File.unlink(hardlink)
  File.unlink(hardlink_target)

  File.write(File.join(root, "outside.txt"), "escape\n")
  error = helper.artifact_error(root, retained_files: 0, retained_bytes: 0)
  abort "watchdog accepted a write outside its allowed layout" unless error&.include?("allowed workspace layout")
' "$WORKSPACE_WATCHDOG_ROOT"
ruby -I "$ROOT/scripts/lib" -reval_process_supervisor -e '
  supervisor = Zstack::EvalProcessSupervisor
  pid = Process.spawn("/bin/sh", "-c", "sleep 10", pgroup: true)
  _status, timed_out, output_limited, resource_error = supervisor.wait(
    pid,
    started_at: supervisor.monotonic_time,
    timeout_seconds: 2,
    resource_check: -> { "synthetic workspace limit" }
  )
  unless !timed_out && !output_limited && resource_error == "synthetic workspace limit"
    abort "supervisor lost the workspace-limit classification"
  end
'
pass "artifact workspace watchdog terminates process groups on live budget violations"

SHARED_WORKSPACE_ROOT="$TEST_ROOT/shared-workspace-watchdog"
mkdir -p \
  "$SHARED_WORKSPACE_ROOT/case-00000000000000000000000000000000/.git" \
  "$SHARED_WORKSPACE_ROOT/.grok-homes/case-00000000000000000000000000000000" \
  "$SHARED_WORKSPACE_ROOT/.prompt-files"
chmod 700 "$SHARED_WORKSPACE_ROOT" "$SHARED_WORKSPACE_ROOT/.prompt-files"
printf '%s\n' 'private prompt bytes' > "$SHARED_WORKSPACE_ROOT/.prompt-files/case-00000000000000000000000000000000.txt"
chmod 600 "$SHARED_WORKSPACE_ROOT/.prompt-files/case-00000000000000000000000000000000.txt"
ruby -I "$ROOT/scripts/lib" -reval_workspace_watchdog -e '
  helper = Zstack::EvalWorkspaceWatchdog
  root = ARGV.fetch(0)
  token = "case-#{"0" * 32}"
  workspace = File.join(root, token)
  home = File.join(root, ".grok-homes", token)
  prompt = File.join(root, ".prompt-files", "#{token}.txt")
  state = helper.capture_prompt_state(prompt)
  specs = [{ workspace: workspace, allowed_top_level: [".git"], host_home: home }]
  states = { prompt => state }
  abort "valid shared workspace root failed monitoring" if helper.shared_root_error(root, workspace_specs: specs, prompt_states: states)

  outside = File.join(root, "unexpected-sibling")
  File.write(outside, "escape\n")
  error = helper.shared_root_error(root, workspace_specs: specs, prompt_states: states)
  abort "shared root accepted an unexpected sibling" unless error&.include?("unexpected or missing entries")
  File.unlink(outside)

  File.write(prompt, "changed prompt\n")
  error = helper.shared_root_error(root, workspace_specs: specs, prompt_states: states)
  abort "shared root accepted changed private prompt bytes" unless error&.include?("private prompt changed")
' "$SHARED_WORKSPACE_ROOT"
pass "shared workspace monitoring binds root layout, host-home containers, and private prompts"

BATCH_MONITOR_ROOT="$TEST_ROOT/batch-resource-monitor"
mkdir -p "$BATCH_MONITOR_ROOT"
ruby -I "$ROOT/scripts/lib" -reval_process_supervisor -reval_resource_monitor -e '
  supervisor = Zstack::EvalProcessSupervisor
  marker = File.join(ARGV.fetch(0), "second-job-violation")
  slow_pid = Process.spawn("/bin/sh", "-c", "sleep 10", pgroup: true)
  violating_pid = Process.spawn(
    "/bin/sh", "-c", %q{printf violation > "$1"; sleep 10},
    "zstack-batch-monitor", marker,
    pgroup: true
  )
  monitor = Zstack::EvalResourceMonitor::Batch.new(
    {
      slow_pid => -> { nil },
      violating_pid => -> { File.exist?(marker) ? "second concurrent job exceeded its workspace" : nil }
    },
    poll_seconds: 0.05
  ) { |pid| supervisor.terminate_without_reap(pid) }.start
  violating_status = nil
  begin
    deadline = supervisor.monotonic_time + 2
    until violating_status || supervisor.monotonic_time >= deadline
      violating_status = Process.wait2(violating_pid, Process::WNOHANG)
      sleep 0.02 unless violating_status
    end
    abort "batch monitor did not terminate an unjoined violating process" unless violating_status
    error = monitor.finish(violating_pid)
    abort "batch monitor lost the violating process classification" unless error == "second concurrent job exceeded its workspace"
    abort "batch monitor misclassified a clean sibling" unless monitor.finish(slow_pid).nil?
  ensure
    monitor.stop
    supervisor.terminate_and_reap(slow_pid)
    supervisor.terminate_and_reap(violating_pid) unless violating_status
  end

  dynamic_marker = File.join(ARGV.fetch(0), "dynamic-job-violation")
  dynamic_pid = Process.spawn(
    "/bin/sh", "-c", %q{printf violation > "$1"; sleep 10},
    "zstack-dynamic-batch-monitor", dynamic_marker,
    pgroup: true
  )
  dynamic_monitor = Zstack::EvalResourceMonitor::Batch.new(
    {},
    poll_seconds: 0.05
  ) { |pid| supervisor.terminate_without_reap(pid) }.start
  dynamic_status = nil
  begin
    dynamic_monitor.add(
      dynamic_pid,
      -> { File.exist?(dynamic_marker) ? "dynamically registered job exceeded its workspace" : nil }
    )
    deadline = supervisor.monotonic_time + 2
    until dynamic_status || supervisor.monotonic_time >= deadline
      dynamic_status = Process.wait2(dynamic_pid, Process::WNOHANG)
      sleep 0.02 unless dynamic_status
    end
    abort "dynamic batch monitor did not terminate its newly registered process" unless dynamic_status
    error = dynamic_monitor.finish(dynamic_pid)
    abort "dynamic batch monitor lost the violation" unless error == "dynamically registered job exceeded its workspace"
  ensure
    dynamic_monitor.stop
    supervisor.terminate_and_reap(dynamic_pid) unless dynamic_status
  end
' "$BATCH_MONITOR_ROOT"
pass "batch resource monitoring supervises initial and dynamically registered processes"

BOUNDED_COMMAND_SENTINEL="$TEST_ROOT/bounded-command-leak"
ruby -I "$ROOT/scripts/lib" -reval_bounded_command -rrbconfig -e '
  helper = Zstack::EvalBoundedCommand
  result = helper.capture(
    RbConfig.ruby, "-e", %q{STDOUT.write("ok\n"); STDERR.write("note\n")},
    timeout_seconds: 1,
    max_output_bytes: 1024
  )
  unless result.status.success? && result.stdout == "ok\n" && result.stderr == "note\n"
    abort "bounded command lost successful output"
  end

  sentinel = ARGV.fetch(0)
  result = helper.capture(
    "/bin/sh", "-c",
    %q{(trap "" HUP TERM; sleep 0.3; printf leaked > "$1") & sleep 10},
    "zstack-command", sentinel,
    timeout_seconds: 0.05,
    max_output_bytes: 1024
  )
  abort "bounded command timeout classification changed" unless result.timed_out && !result.output_limited
  sleep 0.4
  abort "bounded command left a background process" if File.exist?(sentinel)

  result = helper.capture(
    RbConfig.ruby, "-e", %q{STDOUT.write("x" * 600); STDERR.write("y" * 600)},
    timeout_seconds: 1,
    max_output_bytes: 1024
  )
  abort "bounded command accepted excessive combined output" unless result.output_limited && !result.timed_out

  begin
    helper.capture(
      RbConfig.ruby, "-e", %q{STDOUT.binmode; STDOUT.write([255].pack("C"))},
      timeout_seconds: 1,
      max_output_bytes: 1024
    )
    abort "bounded command accepted non-UTF-8 output"
  rescue RuntimeError => e
    abort "bounded command reported the wrong encoding failure" unless e.message.include?("command stdout must be valid UTF-8")
  end

  class << helper
    alias zstack_original_read_output read_output

    def read_output(path, max_output_bytes, label)
      unless defined?(@zstack_replaced_output) && @zstack_replaced_output
        displaced = "#{path}.created"
        File.rename(path, displaced)
        File.write(path, "replacement output must survive\n")
        @zstack_replaced_output = [path, displaced]
        return zstack_original_read_output(displaced, max_output_bytes, label)
      end

      zstack_original_read_output(path, max_output_bytes, label)
    end

    attr_reader :zstack_replaced_output
  end
  result = helper.capture(
    RbConfig.ruby, "-e", %q{STDOUT.write("stable\n")},
    timeout_seconds: 1,
    max_output_bytes: 1024
  )
  abort "bounded command lost displaced output bytes" unless result.stdout == "stable\n"
  replacement, displaced = helper.zstack_replaced_output
  unless File.binread(replacement) == "replacement output must survive\n"
    abort "bounded command cleanup removed a replacement output path"
  end
  File.unlink(replacement)
  File.unlink(displaced)

  class << Tempfile
    alias zstack_original_bounded_create create

    def create(*arguments, &block)
      file = zstack_original_bounded_create(*arguments, &block)
      $zstack_failed_temp_path = file.path
      file.define_singleton_method(:chmod) { |_mode| raise Errno::EPERM }
      file
    end
  end
  begin
    helper.capture(
      RbConfig.ruby, "-e", "exit 0",
      timeout_seconds: 1,
      max_output_bytes: 1024
    )
    abort "bounded command accepted a tempfile initialization failure"
  rescue Errno::EPERM
    nil
  end
  if File.exist?($zstack_failed_temp_path) || File.symlink?($zstack_failed_temp_path)
    abort "bounded command leaked a tempfile after initialization failure"
  end
' "$BOUNDED_COMMAND_SENTINEL"
pass "bounded subprocess capture limits resources and preserves replaced cleanup paths"

WORKSPACE_GIT="$TEST_ROOT/workspace-git"
printf '%s\n' \
  '#!/usr/bin/env ruby' \
  'require "fileutils"' \
  'exit 64 unless ARGV.length == 4 && ARGV.take(3) == ["init", "-q", "--template="]' \
  'sleep ENV.fetch("WORKSPACE_GIT_SLEEP", "0").to_f' \
  'bytes = ENV.fetch("WORKSPACE_GIT_BYTES", "0").to_i' \
  'STDOUT.write("x" * bytes) if bytes.positive?' \
  'exit ENV.fetch("WORKSPACE_GIT_EXIT", "0").to_i unless ENV.fetch("WORKSPACE_GIT_EXIT", "0") == "0"' \
  'FileUtils.mkdir_p(File.join(ARGV.last, ".git"))' \
  > "$WORKSPACE_GIT"
chmod +x "$WORKSPACE_GIT"
ruby -I "$ROOT/scripts/lib" -reval_git_workspace -rfileutils -e '
  helper = Zstack::EvalGitWorkspace
  fake_git = ARGV.fetch(0)
  root = ARGV.fetch(1)

  success_workspace = File.join(root, "git-workspace-success")
  Dir.mkdir(success_workspace)
  helper.prepare(success_workspace, git_executable: fake_git, timeout_seconds: 1, max_output_bytes: 1024)
  abort "bounded git init did not create .git" unless File.directory?(File.join(success_workspace, ".git"))

  template = File.join(root, "ambient-git-template")
  FileUtils.mkdir_p(File.join(template, "hooks"))
  File.write(File.join(template, "hooks", "injected"), "must not copy\n")
  isolated_workspace = File.join(root, "git-workspace-template-free")
  Dir.mkdir(isolated_workspace)
  ENV["GIT_TEMPLATE_DIR"] = template
  begin
    helper.prepare(isolated_workspace, timeout_seconds: 2, max_output_bytes: 1024)
  ensure
    ENV.delete("GIT_TEMPLATE_DIR")
  end
  if File.exist?(File.join(isolated_workspace, ".git", "hooks", "injected"))
    abort "git init inherited an ambient template"
  end

  timeout_workspace = File.join(root, "git-workspace-timeout")
  Dir.mkdir(timeout_workspace)
  ENV["WORKSPACE_GIT_SLEEP"] = "1"
  begin
    helper.prepare(timeout_workspace, git_executable: fake_git, timeout_seconds: 0.05, max_output_bytes: 1024)
    abort "git init accepted a stalled executable"
  rescue RuntimeError => e
    abort "git init reported the wrong timeout" unless e.message.include?("timed out after 0.05 seconds")
  ensure
    ENV.delete("WORKSPACE_GIT_SLEEP")
  end

  output_workspace = File.join(root, "git-workspace-output")
  Dir.mkdir(output_workspace)
  ENV["WORKSPACE_GIT_BYTES"] = "1025"
  begin
    helper.prepare(output_workspace, git_executable: fake_git, timeout_seconds: 1, max_output_bytes: 1024)
    abort "git init accepted oversized output"
  rescue RuntimeError => e
    abort "git init reported the wrong output limit" unless e.message.include?("exceeded 1024 output bytes")
  ensure
    ENV.delete("WORKSPACE_GIT_BYTES")
  end
' "$WORKSPACE_GIT" "$TEST_ROOT"
pass "runner git workspaces are template-free, identity-checked, and resource-bounded"

EXECUTABLE_ROOT="$TEST_ROOT/executable-resolution"
mkdir -p "$EXECUTABLE_ROOT/bin"
EXECUTABLE_TARGET="$EXECUTABLE_ROOT/bin/fake-host"
printf '%s\n' '#!/usr/bin/env ruby' 'puts "fake host"' > "$EXECUTABLE_TARGET"
chmod +x "$EXECUTABLE_TARGET"
ln -s "bin/fake-host" "$EXECUTABLE_ROOT/fake-host-link"
ruby -I "$ROOT/scripts/lib" -reval_executable -e '
  helper = Zstack::EvalExecutable
  target = ARGV.fetch(0)
  link = ARGV.fetch(1)
  bin = File.dirname(target)

  snapshot = helper.resolve(link, display_name: "Fake Host")
  abort "host executable symlink was not resolved once" unless snapshot.path == File.realpath(target)
  helper.verify!(snapshot, display_name: "Fake Host")

  previous_path = ENV["PATH"]
  ENV["PATH"] = bin
  begin
    path_snapshot = helper.resolve(File.basename(target), display_name: "Fake Host")
    abort "host executable PATH resolution was not pinned" unless path_snapshot.path == File.realpath(target)
  ensure
    ENV["PATH"] = previous_path
  end

  File.open(target, "ab") { |file| file.write("# drift\n") }
  begin
    helper.verify!(snapshot, display_name: "Fake Host")
    abort "host executable drift was accepted"
  rescue RuntimeError => e
    abort "host executable reported the wrong drift" unless e.message.include?("changed during the run")
  end
' "$EXECUTABLE_TARGET" "$EXECUTABLE_ROOT/fake-host-link"
pass "host executable resolution pins PATH and symlinks to one stable file"

VERSION_PROBE_HOST="$TEST_ROOT/version-probe-host"
printf '%s\n' \
  '#!/usr/bin/env ruby' \
  'exit 64 unless ARGV == ["--version"]' \
  'sleep ENV.fetch("VERSION_PROBE_SLEEP", "0").to_f' \
  'bytes = ENV.fetch("VERSION_PROBE_BYTES", "0").to_i' \
  'STDOUT.write("x" * bytes) if bytes.positive?' \
  'STDOUT.write("fake-host 1.2.3\n") if bytes.zero?' \
  > "$VERSION_PROBE_HOST"
chmod +x "$VERSION_PROBE_HOST"
ruby -I "$ROOT/scripts/lib" -reval_host_version -e '
  helper = Zstack::EvalHostVersion
  executable = ARGV.fetch(0)
  version = helper.probe(executable, display_name: "Fake Host", timeout_seconds: 1, max_output_bytes: 1024)
  abort "bounded version probe lost stdout" unless version == "fake-host 1.2.3"

  ENV["VERSION_PROBE_SLEEP"] = "1"
  begin
    helper.probe(executable, display_name: "Fake Host", timeout_seconds: 0.05, max_output_bytes: 1024)
    abort "version probe accepted a stalled host"
  rescue RuntimeError => e
    abort "version probe reported the wrong timeout" unless e.message.include?("timed out after 0.05 seconds")
  ensure
    ENV.delete("VERSION_PROBE_SLEEP")
  end

  ENV["VERSION_PROBE_BYTES"] = "1025"
  begin
    helper.probe(executable, display_name: "Fake Host", timeout_seconds: 1, max_output_bytes: 1024)
    abort "version probe accepted oversized output"
  rescue RuntimeError => e
    abort "version probe reported the wrong output limit" unless e.message.include?("exceeded 1024 output bytes")
  ensure
    ENV.delete("VERSION_PROBE_BYTES")
  end
' "$VERSION_PROBE_HOST"
pass "host version probes are process-group, timeout, and output bounded"

OUTPUT_FILE_CONTRACT="$TEST_ROOT/output-file-contract"
mkdir -p "$OUTPUT_FILE_CONTRACT"
printf '%s\n' 'stable response' > "$OUTPUT_FILE_CONTRACT/regular.txt"
ln -s "$OUTPUT_FILE_CONTRACT/regular.txt" "$OUTPUT_FILE_CONTRACT/linked.txt"
mkfifo "$OUTPUT_FILE_CONTRACT/response.fifo"
printf '\377' > "$OUTPUT_FILE_CONTRACT/invalid-utf8.txt"
dd if=/dev/zero of="$OUTPUT_FILE_CONTRACT/oversized.txt" bs=$((2 * 1024 * 1024 + 1)) count=1 2>/dev/null
ruby -I "$ROOT/scripts/lib" -reval_output_file -e '
  helper = Zstack::EvalOutputFile
  content, error = helper.read_optional(ARGV.fetch(0))
  abort "regular response was not captured" unless content == "stable response\n" && error.nil?
  ARGV.drop(1).each do |path|
    rejected_content, rejected_error = helper.read_optional(path)
    abort "unsafe response was accepted: #{path}" unless rejected_content.nil? && !rejected_error.to_s.empty?
  end
  binary, binary_error = helper.read_optional(ARGV.fetch(3), require_utf8: false)
  abort "binary evidence input was not captured exactly" unless binary == "\xFF".b && binary_error.nil?
' \
  "$OUTPUT_FILE_CONTRACT/regular.txt" \
  "$OUTPUT_FILE_CONTRACT/linked.txt" \
  "$OUTPUT_FILE_CONTRACT/response.fifo" \
  "$OUTPUT_FILE_CONTRACT/invalid-utf8.txt" \
  "$OUTPUT_FILE_CONTRACT/oversized.txt"
ruby -I "$ROOT/scripts/lib" -reval_output_file -e '
  source, victim, displaced, read_marker = ARGV.map { |path| File.expand_path(path) }
  File.binwrite(source, "original source\n")
  File.binwrite(victim, "replacement content must not be read\n")
  victim_stat = File.stat(victim)
  constants = File::Constants
  nofollow = constants.const_get(:NOFOLLOW) if constants.const_defined?(:NOFOLLOW)
  constants.send(:remove_const, :NOFOLLOW) if nofollow

  begin
  File.singleton_class.class_eval do
    alias_method :zstack_original_open_before_read_test, :open
    define_method(:open) do |path, *arguments, &block|
      expanded = File.expand_path(path.to_s)
      if expanded == source && !File.symlink?(source)
        File.rename(source, displaced)
        File.symlink(victim, source)
      end
      zstack_original_open_before_read_test(path, *arguments, &block)
    end
  end
  File.class_eval do
    alias_method :zstack_original_read_before_read_test, :read
    define_method(:read) do |*arguments|
      opened = stat
      if opened.dev == victim_stat.dev && opened.ino == victim_stat.ino
        File.binwrite(read_marker, "replacement inode was read\n")
      end
      zstack_original_read_before_read_test(*arguments)
    end
  end

  content, error = Zstack::EvalOutputFile.read_optional(source)
  abort "replaced source returned content" unless content.nil? && !error.to_s.empty?
  abort "replacement inode was read before identity rejection" if File.exist?(read_marker)
  ensure
  File.singleton_class.class_eval do
    if method_defined?(:zstack_original_open_before_read_test)
      alias_method :open, :zstack_original_open_before_read_test
      remove_method :zstack_original_open_before_read_test
    end
  end
  File.class_eval do
    if method_defined?(:zstack_original_read_before_read_test)
      alias_method :read, :zstack_original_read_before_read_test
      remove_method :zstack_original_read_before_read_test
    end
  end
  constants.const_set(:NOFOLLOW, nofollow) if nofollow && !constants.const_defined?(:NOFOLLOW)
  end
' \
  "$OUTPUT_FILE_CONTRACT/open-race-source.txt" \
  "$OUTPUT_FILE_CONTRACT/open-race-victim.txt" \
  "$OUTPUT_FILE_CONTRACT/open-race-displaced.txt" \
  "$OUTPUT_FILE_CONTRACT/open-race-read-marker.txt"
ruby -I "$ROOT/scripts/lib" -reval_output_file -e '
  Zstack::EvalOutputFile.write_exclusive(ARGV.fetch(0), "private response\n")
' "$OUTPUT_FILE_CONTRACT/exclusive.txt"
[[ "$(zstack_file_mode_bits "$OUTPUT_FILE_CONTRACT/exclusive.txt")" == "600" ]] || fail "exclusive response writer created a non-private file"
printf '%s\n' 'preserve response target' > "$OUTPUT_FILE_CONTRACT/existing.txt"
if ruby -I "$ROOT/scripts/lib" -reval_output_file -e '
  Zstack::EvalOutputFile.write_exclusive(ARGV.fetch(0), "overwrite")
' "$OUTPUT_FILE_CONTRACT/existing.txt" >/dev/null 2>&1; then
  fail "exclusive response writer replaced an existing target"
fi
grep -qx "preserve response target" "$OUTPUT_FILE_CONTRACT/existing.txt" || fail "exclusive response writer changed an existing target"
ruby -I "$ROOT/scripts/lib" -reval_output_file -e '
  helper = Zstack::EvalOutputFile
  stream = ARGV.fetch(0)
  io = helper.open_exclusive(stream, label: "test host stream")
  io.write("private stream\n")
  io.close
  abort "exclusive stream is not owner-private" unless (File.stat(stream).mode & 0o077).zero?

  begin
    helper.open_exclusive(stream, label: "test host stream")
    abort "exclusive stream replaced an existing file"
  rescue RuntimeError
    nil
  end

  target = ARGV.fetch(1)
  linked = ARGV.fetch(2)
  File.write(target, "preserve target\n")
  File.symlink(target, linked)
  begin
    helper.open_exclusive(linked, label: "test host stream")
    abort "exclusive stream followed a symbolic link"
  rescue RuntimeError
    nil
  end
  abort "exclusive stream changed a link target" unless File.read(target) == "preserve target\n"
' "$OUTPUT_FILE_CONTRACT/exclusive-stream.log" "$OUTPUT_FILE_CONTRACT/stream-target.txt" "$OUTPUT_FILE_CONTRACT/linked-stream.log"
ruby -I "$ROOT/scripts/lib" -reval_output_file -e '
  failure_path = File.expand_path(ARGV.fetch(0))
  Object.const_set(:ZSTACK_FSYNC_FAILURE_PATH, failure_path)
  File.class_eval do
    alias_method :zstack_original_fsync, :fsync
    define_method(:fsync) do
      raise Errno::EIO if File.expand_path(path) == ZSTACK_FSYNC_FAILURE_PATH

      zstack_original_fsync
    end
  end
  begin
    Zstack::EvalOutputFile.write_exclusive(failure_path, "partial response")
    abort "injected response fsync failure was accepted"
  rescue RuntimeError => e
    abort "response writer reported the wrong failure" unless e.message.include?("Errno::EIO")
  end
  abort "failed response write left a partial target" if File.exist?(failure_path) || File.symlink?(failure_path)
' "$OUTPUT_FILE_CONTRACT/fsync-failure.txt"
ruby -I "$ROOT/scripts/lib" -reval_output_file -e '
  helper = Zstack::EvalOutputFile
  invalid_path, oversized_path = ARGV
  begin
    helper.write_exclusive(invalid_path, "\xFF".b)
    abort "invalid UTF-8 response was written"
  rescue ArgumentError
    nil
  end
  begin
    helper.write_exclusive(oversized_path, "x" * (Zstack::EvalLimits::MAX_HOST_OUTPUT_BYTES + 1))
    abort "oversized response was written"
  rescue ArgumentError
    nil
  end
  abort "invalid response validation created a target" if [invalid_path, oversized_path].any? { |path| File.exist?(path) || File.symlink?(path) }
' "$OUTPUT_FILE_CONTRACT/invalid-write.txt" "$OUTPUT_FILE_CONTRACT/oversized-write.txt"
pass "runner output and evidence input files are bounded, stable, encoding-aware, non-link, and exclusive"

PROMPT_WRITER_CONTRACT="$TEST_ROOT/prompt-writer-contract"
mkdir -p "$PROMPT_WRITER_CONTRACT"
ruby -I "$ROOT/scripts/lib" -reval_prompt_writer -e '
  root = ARGV.fetch(0)
  writer = Zstack::EvalPromptWriter::Budget.new(max_bytes_per_prompt: 10, max_bytes_per_run: 15)
  first = File.join(root, "first.txt")
  writer.write(first, "x" * 10)
  abort "prompt writer lost its total" unless writer.total_bytes == 10
  abort "prompt writer did not create a private file" unless (File.stat(first).mode & 0o077).zero?

  total_overflow = File.join(root, "total-overflow.txt")
  begin
    writer.write(total_overflow, "y" * 6)
    abort "prompt writer accepted whole-run overflow"
  rescue RuntimeError => e
    abort "prompt writer reported the wrong whole-run limit" unless e.message.include?("exceeds 15 total bytes")
  end
  abort "whole-run rejection created a file" if File.exist?(total_overflow) || File.symlink?(total_overflow)

  per_prompt = Zstack::EvalPromptWriter::Budget.new(max_bytes_per_prompt: 3, max_bytes_per_run: 10)
  per_overflow = File.join(root, "per-overflow.txt")
  begin
    per_prompt.write(per_overflow, "four")
    abort "prompt writer accepted per-prompt overflow"
  rescue RuntimeError => e
    abort "prompt writer reported the wrong per-prompt limit" unless e.message.include?("exceeds 3 bytes")
  end
  abort "per-prompt rejection created a file" if File.exist?(per_overflow) || File.symlink?(per_overflow)

  existing = File.join(root, "existing.txt")
  File.write(existing, "preserve\n")
  begin
    writer.write(existing, "replace")
    abort "prompt writer replaced an existing target"
  rescue RuntimeError
    nil
  end
  abort "prompt writer changed an existing target" unless File.read(existing) == "preserve\n"

  anonymous = Zstack::EvalPromptWriter.anonymous_input("immutable prompt", max_bytes: 32)
  anonymous_path = anonymous.path
  if anonymous_path && (File.exist?(anonymous_path) || File.symlink?(anonymous_path))
    abort "anonymous prompt input retained a mutable pathname"
  end
  anonymous_stat = anonymous.stat
  unless anonymous_stat.file? && anonymous_stat.uid == Process.uid && anonymous_stat.nlink.zero? &&
         (anonymous_stat.mode & 0o077).zero?
    abort "anonymous prompt input has unsafe descriptor metadata"
  end
  abort "anonymous prompt input lost its bytes" unless anonymous.read == "immutable prompt"
  anonymous.close

  begin
    Zstack::EvalPromptWriter.anonymous_input("four", max_bytes: 3)
    abort "anonymous prompt input accepted oversized bytes"
  rescue ArgumentError => e
    abort "anonymous prompt input reported the wrong size failure" unless e.message.include?("exceeds 3 bytes")
  end
' "$PROMPT_WRITER_CONTRACT"
pass "prompt writer enforces budgets and creates pathname-free stdin descriptors"

OUTPUT_DIRECTORY_CONTRACT="$TEST_ROOT/output-directory-contract"
mkdir -p "$OUTPUT_DIRECTORY_CONTRACT"
chmod 700 "$OUTPUT_DIRECTORY_CONTRACT"
ruby -I "$ROOT/scripts/lib" -r eval_output_directory -r fileutils -e '
  path = ARGV.fetch(0)
  helper = Zstack::EvalOutputDirectory
  first = helper.prepare(path, prefix: "unused-")
  first.verify!
  lease_path = File.join(path, helper::LEASE_NAME)
  abort "output reservation did not create a private lease" unless File.file?(lease_path) && (File.stat(lease_path).mode & 0o077).zero?
  begin
    helper.prepare(path, prefix: "unused-")
    abort "output reservation allowed concurrent reuse"
  rescue RuntimeError => e
    abort "concurrent output reuse reported the wrong failure" unless e.message.include?("must be empty")
  end

  moved_lease = "#{lease_path}.created"
  File.rename(lease_path, moved_lease)
  File.write(lease_path, "replacement must survive\n")
  first.close
  abort "output cleanup removed a replacement lease" unless File.read(lease_path) == "replacement must survive\n"
  File.unlink(lease_path)
  File.unlink(moved_lease)

  second = helper.prepare(path, prefix: "unused-")
  second.close
  abort "output reservation left its lease after close" unless Dir.empty?(path)

  automatic = helper.prepare(nil, prefix: "zstack-output-contract-")
  automatic_path = automatic.path
  abort "automatic output directory is not private" unless (File.stat(automatic_path).mode & 0o077).zero?
  automatic.close
  abort "automatic output reservation left its lease" unless Dir.empty?(automatic_path)
  FileUtils.remove_entry(automatic_path)

  third = helper.prepare(path, prefix: "unused-")
  moved_path = "#{path}.created"
  File.rename(path, moved_path)
  Dir.mkdir(path, 0o700)
  error = third.verification_error
  abort "output reservation accepted a replaced directory" unless error&.include?("output directory changed")
  third.close
  abort "output cleanup changed the replacement directory" unless Dir.empty?(path)
  abort "output cleanup lost the original lease" unless File.file?(File.join(moved_path, helper::LEASE_NAME))
  FileUtils.remove_entry(path)
  FileUtils.remove_entry(moved_path)
' "$OUTPUT_DIRECTORY_CONTRACT"
pass "runner output directories are private, exclusively leased, and replacement-safe"

OUTPUT_TREE_CONTRACT="$TEST_ROOT/output-tree-contract"
mkdir -p "$OUTPUT_TREE_CONTRACT/logs"
chmod 700 "$OUTPUT_TREE_CONTRACT"
printf '%s\n' 'immutable evidence' > "$OUTPUT_TREE_CONTRACT/static.txt"
ruby -I "$ROOT/scripts/lib" -reval_output_tree -e '
  root = ARGV.fetch(0)
  mutable = File.join(root, "logs", "active.log")
  linked = File.join(root, "logs", "linked.log")
  state = Zstack::EvalOutputTree.capture(root, mutable_paths: [mutable, linked])
  File.write(mutable, "bounded live output\n")
  abort "output tree rejected declared mutable output" if state.validation_error

  unexpected = File.join(root, "unexpected.txt")
  File.write(unexpected, "escape\n")
  error = state.validation_error
  abort "output tree accepted an unexpected file" unless error&.include?("unexpected entry")
  File.unlink(unexpected)

  File.link(File.join(root, "static.txt"), linked)
  error = state.validation_error
  abort "output tree accepted a multiply linked file" unless error&.include?("multiply linked file")
  File.unlink(linked)

  File.write(File.join(root, "static.txt"), "changed evidence\n")
  error = state.validation_error
  abort "output tree accepted changed immutable evidence" unless error&.include?("entry changed")
' "$OUTPUT_TREE_CONTRACT"
pass "runner output trees allow only declared mutable files and unchanged prior evidence"

ROUTING_DRY_RUN="$TEST_ROOT/routing-runner-dry"
"$ROOT/scripts/run-codex-routing-evals.rb" \
  --dry-run \
  --case zh-boundary-public-research \
  --case none-code-fix \
  --truncate-descriptions 180 \
  --output "$ROUTING_DRY_RUN" > "$TEST_ROOT/routing-runner-dry.log"
[[ -f "$ROUTING_DRY_RUN/prompts/zh-boundary-public-research.txt" ]] || fail "routing runner omitted a selected prompt"
[[ ! -e "$ROUTING_DRY_RUN/results.json" ]] || fail "routing dry-run invented graded results"
[[ "$(zstack_file_mode_bits "$ROUTING_DRY_RUN")" == "700" ]] || fail "routing runner created a non-private output directory"
ruby -rjson -e '
  controls = JSON.parse(File.read(File.join(ARGV.fetch(0), "controls.json")))
  abort "routing runner omitted prompt budgets" unless controls.fetch("maxPromptBytesPerCase") == 512 * 1024 &&
    controls.fetch("maxPromptBytesPerRun") == 16 * 1024 * 1024 && controls.fetch("promptBytes").positive?
  runtime = %w[maxRuntimeGitFiles maxRuntimeGitTreeEntries maxRuntimeGitBytes maxRuntimeHostHomeFiles maxRuntimeHostHomeTreeEntries maxRuntimeHostHomeBytes].map { |field| controls.fetch(field) }
  abort "routing runner omitted baseline runtime limits" unless controls.fetch("runtimeTreeMonitoring") == true &&
    controls.fetch("concurrentRuntimeMonitoring") == true && controls.fetch("pidMonitoringStartsAtSpawn") == true &&
    controls.fetch("sharedRootMonitoring") == true && controls.fetch("privatePromptIntegrityMonitoring") == false &&
    controls.fetch("outputDirectoryIdentityMonitoring") == true &&
    runtime == [100, 500, 2 * 1024 * 1024, 200, 500, 8 * 1024 * 1024]
  output_runtime = %w[maxRuntimeOutputFiles maxRuntimeOutputTreeEntries maxRuntimeOutputBytes].map { |field| controls.fetch(field) }
  abort "routing runner omitted output-tree limits" unless controls.fetch("outputTreeMonitoring") == true &&
    controls.fetch("exclusiveRunnerOutputs") == true &&
    controls.fetch("workspaceViolationStopsRun") == true &&
    controls.fetch("singleLinkInputFiles") == true &&
    controls.fetch("singleLinkRuntimeFiles") == true &&
    output_runtime == [4_096, 8_192, 640 * 1024 * 1024]
' "$ROUTING_DRY_RUN"
grep -q "上下文预算压力测试" "$ROUTING_DRY_RUN/prompts/zh-boundary-public-research.txt" || fail "routing dry-run omitted its truncation disclosure"
if grep -Rqs "expected_skill" "$ROUTING_DRY_RUN/prompts"; then
  fail "routing runner leaked expected answers into model prompts"
fi
ruby -e '
  File.foreach(ARGV.fetch(0)) do |line|
    description = line.split("\t", 2).fetch(1).chomp
    abort "description was not truncated to 180 characters plus an ellipsis" unless description.length == 181 && description.end_with?("…")
  end
' "$ROUTING_DRY_RUN/candidate-descriptions.txt"
pass "routing runner creates leak-free truncated prompts without invoking Codex"

ROUTING_CASE_LIMIT_FIXTURE="$(copy_fixture routing-runner-case-limit)"
ruby -ryaml -e '
  path = ARGV.fetch(0)
  document = YAML.safe_load(File.read(path), permitted_classes: [], aliases: false)
  document["cases"] = 257.times.map do |index|
    {
      "id" => format("case-limit-%03d", index),
      "prompt" => "Synthetic routing case #{index}",
      "expected_skill" => "z-market-validate"
    }
  end
  File.write(path, YAML.dump(document))
' "$ROUTING_CASE_LIMIT_FIXTURE/evals/routing.yaml"
if "$ROUTING_CASE_LIMIT_FIXTURE/scripts/run-codex-routing-evals.rb" --dry-run \
  > "$TEST_ROOT/routing-runner-case-limit.log" 2>&1; then
  fail "routing runner accepted too many cases in one run"
fi
grep -q "selected run has 257 cases; maximum is 256" "$TEST_ROOT/routing-runner-case-limit.log" ||
  fail "routing runner reported the wrong case-count limit failure"
pass "routing runner bounds total calls per invocation"

FAKE_CODEX="$TEST_ROOT/fake-codex"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'if [[ "${1:-}" == "--version" ]]; then' \
  '  if [[ -n "${FAKE_CODEX_MUTATE_PROMPT_PATH:-}" ]]; then printf "%s\n" "replaced prompt must not reach the host" > "$FAKE_CODEX_MUTATE_PROMPT_PATH"; fi' \
  '  echo "codex-cli fake-1.0"' \
  '  exit 0' \
  'fi' \
  '[[ "${1:-}" == "exec" ]] || exit 64' \
  'if [[ -n "${FAKE_CODEX_EXECUTION_MARKER:-}" ]]; then : > "$FAKE_CODEX_EXECUTION_MARKER"; fi' \
  'if [[ "${REQUIRE_ISOLATED_CODEX_HOME:-0}" == "1" ]]; then' \
  '  [[ -n "${CODEX_HOME:-}" && -f "$CODEX_HOME/auth.json" ]] || exit 67' \
  '  [[ -z "${CODEX_THREAD_ID:-}" && -z "${CODEX_PERMISSION_PROFILE:-}" && -z "${CODEX_INTERNAL_ORIGINATOR_OVERRIDE:-}" ]] || exit 68' \
  '  [[ " $* " == *" -c analytics.enabled=false "* ]] || exit 69' \
  'fi' \
  'output=""' \
  'workspace=""' \
  'for ((index = 1; index <= $#; index++)); do' \
  '  argument="${!index}"' \
  '  if [[ "$argument" == "-o" ]]; then' \
  '    next_index=$((index + 1))' \
  '    output="${!next_index}"' \
  '  elif [[ "$argument" == "-C" ]]; then' \
  '    next_index=$((index + 1))' \
  '    workspace="${!next_index}"' \
  '  fi' \
  'done' \
  '[[ -n "$output" && -n "$workspace" ]] || exit 65' \
  'if [[ "${!#}" == "-" ]]; then prompt="$(cat)"; else prompt="${!#}"; fi' \
  'if [[ "${FAKE_CODEX_WORKSPACE_ESCAPE:-0}" == "1" ]]; then printf "escape\n" > "$workspace/outside.txt"; fi' \
  'if [[ "${FAKE_CODEX_ROOT_ESCAPE:-0}" == "1" ]]; then printf "escape\n" > "$workspace/../outside.txt"; fi' \
  'if [[ "${FAKE_CODEX_OUTPUT_ESCAPE:-0}" == "1" ]]; then printf "escape\n" > "$(dirname "$(dirname "$output")")/unexpected-output.txt"; fi' \
  'sleep "${FAKE_CODEX_SLEEP_SECONDS:-0}"' \
  'if [[ "${FAKE_CODEX_STDOUT_BYTES:-0}" -gt 0 ]]; then' \
  '  dd if=/dev/zero bs="${FAKE_CODEX_STDOUT_BYTES}" count=1 2>/dev/null' \
  'fi' \
  'if [[ -n "${FAKE_CODEX_RESPONSE_SYMLINK_TARGET:-}" ]]; then' \
  '  ln -s "$FAKE_CODEX_RESPONSE_SYMLINK_TARGET" "$output"' \
  '  exit 0' \
  'fi' \
  'if [[ "${FAKE_CODEX_RESPONSE_FIFO:-0}" == "1" ]]; then' \
  '  mkfifo "$output"' \
  '  exit 0' \
  'fi' \
  'selection="${FAKE_CODEX_SELECTION:-}"' \
  'if [[ -z "$selection" ]]; then' \
  '  case "$prompt" in' \
  '    *"自动整理会议纪要并生成发票草稿"*) selection="z-market-validate" ;;' \
  '    *"修复结账服务里失败"*) selection="none" ;;' \
  '    *) selection="none" ;;' \
  '  esac' \
  'fi' \
  'printf "selection: %s\nreason: fake routing reason\n" "$selection" > "$output"' \
  'printf "OpenAI Codex vfake-1.0\n--------\nworkdir: %s\nmodel: gpt-5.6-sol\napproval: never\nsandbox: read-only\nreasoning effort: low\nuser\n%s\ncodex\nselection: %s\nreason: fake routing reason\n" "$workspace" "$prompt" "$selection"' > "$FAKE_CODEX"
chmod +x "$FAKE_CODEX"
FAKE_CODEX_AUTH="$TEST_ROOT/fake-codex-auth.json"
printf '%s\n' '{}' > "$FAKE_CODEX_AUTH"
chmod 600 "$FAKE_CODEX_AUTH"

AUTH_COPY_CONTRACT="$TEST_ROOT/auth-copy-contract"
mkdir -p "$AUTH_COPY_CONTRACT"
ruby -I "$ROOT/scripts/lib" -reval_auth_file -e '
  copied = Zstack::EvalAuthFile.copy_optional(source: ARGV.fetch(0), destination: ARGV.fetch(1))
  abort "auth source was not copied" unless copied
' "$FAKE_CODEX_AUTH" "$AUTH_COPY_CONTRACT/copied.json"
cmp -s "$FAKE_CODEX_AUTH" "$AUTH_COPY_CONTRACT/copied.json" || fail "stable auth copy changed credential bytes"
[[ "$(zstack_file_mode_bits "$AUTH_COPY_CONTRACT/copied.json")" == "600" ]] || fail "stable auth copy created non-private credentials"
printf '%s\n' '{}' > "$AUTH_COPY_CONTRACT/nonprivate.json"
chmod 644 "$AUTH_COPY_CONTRACT/nonprivate.json"
if ruby -I "$ROOT/scripts/lib" -reval_auth_file -e '
  Zstack::EvalAuthFile.copy_optional(source: ARGV.fetch(0), destination: ARGV.fetch(1))
' "$AUTH_COPY_CONTRACT/nonprivate.json" "$AUTH_COPY_CONTRACT/nonprivate-copy.json" > "$AUTH_COPY_CONTRACT/nonprivate.log" 2>&1; then
  fail "auth copy accepted non-private credentials"
fi
[[ ! -e "$AUTH_COPY_CONTRACT/nonprivate-copy.json" ]] || fail "rejected auth copy left credential bytes behind"
ln -s "$FAKE_CODEX_AUTH" "$AUTH_COPY_CONTRACT/linked.json"
if ruby -I "$ROOT/scripts/lib" -reval_auth_file -e '
  Zstack::EvalAuthFile.copy_optional(source: ARGV.fetch(0), destination: ARGV.fetch(1))
' "$AUTH_COPY_CONTRACT/linked.json" "$AUTH_COPY_CONTRACT/linked-copy.json" >/dev/null 2>&1; then
  fail "auth copy accepted a symbolic-link credential source"
fi
printf '%s\n' '{}' > "$AUTH_COPY_CONTRACT/hardlinked.json"
chmod 600 "$AUTH_COPY_CONTRACT/hardlinked.json"
ln "$AUTH_COPY_CONTRACT/hardlinked.json" "$AUTH_COPY_CONTRACT/hardlinked-alias.json"
if ruby -I "$ROOT/scripts/lib" -reval_auth_file -e '
  Zstack::EvalAuthFile.copy_optional(source: ARGV.fetch(0), destination: ARGV.fetch(1))
' "$AUTH_COPY_CONTRACT/hardlinked.json" "$AUTH_COPY_CONTRACT/hardlinked-copy.json" >/dev/null 2>&1; then
  fail "auth copy accepted a multiply linked credential source"
fi
dd if=/dev/zero of="$AUTH_COPY_CONTRACT/oversized.json" bs=1048577 count=1 2>/dev/null
chmod 600 "$AUTH_COPY_CONTRACT/oversized.json"
if ruby -I "$ROOT/scripts/lib" -reval_auth_file -e '
  Zstack::EvalAuthFile.copy_optional(source: ARGV.fetch(0), destination: ARGV.fetch(1))
' "$AUTH_COPY_CONTRACT/oversized.json" "$AUTH_COPY_CONTRACT/oversized-copy.json" >/dev/null 2>&1; then
  fail "auth copy accepted credentials above its byte limit"
fi
printf '%s\n' 'preserve existing destination' > "$AUTH_COPY_CONTRACT/existing.json"
if ruby -I "$ROOT/scripts/lib" -reval_auth_file -e '
  Zstack::EvalAuthFile.copy_optional(source: ARGV.fetch(0), destination: ARGV.fetch(1))
' "$FAKE_CODEX_AUTH" "$AUTH_COPY_CONTRACT/existing.json" >/dev/null 2>&1; then
  fail "auth copy replaced an existing destination"
fi
grep -qx "preserve existing destination" "$AUTH_COPY_CONTRACT/existing.json" || fail "failed auth copy removed an existing destination"
ruby -I "$ROOT/scripts/lib" -reval_auth_file -e '
  source = ARGV.fetch(0)
  destination = File.expand_path(ARGV.fetch(1))
  Object.const_set(:ZSTACK_AUTH_FSYNC_FAILURE_PATH, destination)
  File.class_eval do
    alias_method :zstack_original_auth_fsync, :fsync
    define_method(:fsync) do
      if File.expand_path(path) == ZSTACK_AUTH_FSYNC_FAILURE_PATH
        raise Errno::EIO
      end
      zstack_original_auth_fsync
    end
  end
  begin
    Zstack::EvalAuthFile.copy_optional(source: source, destination: destination)
    abort "injected auth fsync failure was accepted"
  rescue RuntimeError => e
    abort "auth copy reported the wrong injected failure" unless e.message.include?("Errno::EIO")
  end
  abort "failed auth copy left a partial destination" if File.exist?(destination) || File.symlink?(destination)
' "$FAKE_CODEX_AUTH" "$AUTH_COPY_CONTRACT/fsync-failure.json"
ruby -I "$ROOT/scripts/lib" -reval_auth_file -e '
  source = ARGV.fetch(0)
  destination = File.expand_path(ARGV.fetch(1))
  moved = "#{destination}.created"
  Object.const_set(:ZSTACK_AUTH_REPLACEMENT_PATH, destination)
  Object.const_set(:ZSTACK_AUTH_MOVED_PATH, moved)
  File.class_eval do
    alias_method :zstack_original_auth_replacement_fsync, :fsync
    define_method(:fsync) do
      if File.expand_path(path) == ZSTACK_AUTH_REPLACEMENT_PATH
        File.rename(ZSTACK_AUTH_REPLACEMENT_PATH, ZSTACK_AUTH_MOVED_PATH)
        File.write(ZSTACK_AUTH_REPLACEMENT_PATH, "replacement must survive\n")
        raise Errno::EIO
      end
      zstack_original_auth_replacement_fsync
    end
  end
  begin
    Zstack::EvalAuthFile.copy_optional(source: source, destination: destination)
    abort "injected auth replacement failure was accepted"
  rescue RuntimeError => e
    abort "auth replacement reported the wrong failure" unless e.message.include?("Errno::EIO")
  end
  abort "failed auth cleanup removed a replacement target" unless File.read(destination) == "replacement must survive\n"
' "$FAKE_CODEX_AUTH" "$AUTH_COPY_CONTRACT/replaced-destination.json"
pass "evaluation auth copies are private, no-follow, exclusive, and failure-safe"

HOST_HOME_CONTRACT="$TEST_ROOT/host-home-contract"
mkdir -p "$HOST_HOME_CONTRACT"
chmod 700 "$HOST_HOME_CONTRACT"
ruby -I "$ROOT/scripts/lib" -r eval_codex_home -r eval_grok_home -e '
  root, auth, unsafe_auth = ARGV
  codex_token = "case-#{"a" * 32}"
  codex_home, copied = Zstack::EvalCodexHome.prepare(root: root, case_id: codex_token, auth_path: auth)
  abort "Codex home did not copy auth" unless copied && File.file?(File.join(codex_home, "auth.json"))
  abort "Codex home is not owner-private" unless (File.stat(codex_home).mode & 0o077).zero?
  begin
    Zstack::EvalCodexHome.prepare(root: root, case_id: codex_token, auth_path: auth)
    abort "Codex home silently reused a case directory"
  rescue RuntimeError => e
    abort "Codex reuse reported the wrong failure" unless e.message.include?("could not be created safely")
  end
  abort "Codex reuse changed existing auth" unless File.binread(File.join(codex_home, "auth.json")) == File.binread(auth)

  outside = File.join(root, "outside-home")
  Dir.mkdir(outside, 0o700)
  linked_token = "case-#{"b" * 32}"
  linked_home = File.join(root, ".codex-homes", linked_token)
  File.symlink(outside, linked_home)
  begin
    Zstack::EvalCodexHome.prepare(root: root, case_id: linked_token, auth_path: auth)
    abort "Codex home accepted a pre-existing symlink"
  rescue RuntimeError
    nil
  end
  abort "Codex home changed a symlink target" unless Dir.empty?(outside)

  begin
    Zstack::EvalCodexHome.prepare(root: root, case_id: "../escape", auth_path: auth)
    abort "Codex home accepted a semantic or traversing case id"
  rescue RuntimeError => e
    abort "invalid case token reported the wrong failure" unless e.message.include?("opaque private case token")
  end

  grok_token = "case-#{"c" * 32}"
  config = "[tools]\nallowed = []\n"
  grok_home, grok_auth, grok_copied = Zstack::EvalGrokHome.prepare(
    root: root,
    case_id: grok_token,
    auth_path: auth,
    config: config
  )
  config_path = File.join(grok_home, "config.toml")
  abort "Grok home lost exact config bytes" unless File.binread(config_path) == config
  abort "Grok home did not isolate auth" unless grok_copied && File.dirname(grok_auth) == grok_home
  abort "Grok config is not owner-private" unless (File.stat(config_path).mode & 0o077).zero?
  begin
    Zstack::EvalGrokHome.prepare(root: root, case_id: grok_token, auth_path: auth, config: "replacement")
    abort "Grok home silently reused a case directory"
  rescue RuntimeError
    nil
  end
  abort "Grok reuse overwrote config" unless File.binread(config_path) == config

  unsafe_token = "case-#{"d" * 32}"
  begin
    Zstack::EvalGrokHome.prepare(root: root, case_id: unsafe_token, auth_path: unsafe_auth, config: config)
    abort "Grok home accepted unsafe auth"
  rescue RuntimeError
    nil
  end
  abort "Grok home left partial state after auth failure" if File.exist?(File.join(root, ".grok-homes", unsafe_token))

  failure_token = "case-#{"e" * 32}"
  Object.const_set(:ZSTACK_GROK_CONFIG_FAILURE_TOKEN, failure_token)
  File.class_eval do
    alias_method :zstack_original_grok_config_fsync, :fsync
    define_method(:fsync) do
      if File.basename(path) == "config.toml" && path.include?(ZSTACK_GROK_CONFIG_FAILURE_TOKEN)
        raise Errno::EIO
      end
      zstack_original_grok_config_fsync
    end
  end
  begin
    Zstack::EvalGrokHome.prepare(root: root, case_id: failure_token, auth_path: auth, config: config)
    abort "injected Grok config failure was accepted"
  rescue RuntimeError => e
    abort "Grok config failure reported the wrong error" unless e.message.include?("Errno::EIO")
  end
  abort "Grok home left partial state after config failure" if File.exist?(File.join(root, ".grok-homes", failure_token))
' "$HOST_HOME_CONTRACT" "$FAKE_CODEX_AUTH" "$AUTH_COPY_CONTRACT/linked.json"
pass "evaluation host homes are private, exclusive, opaque, and transaction-safe"

ROUTING_FAKE_PASS="$TEST_ROOT/routing-runner-pass"
REQUIRE_ISOLATED_CODEX_HOME=1 \
CODEX_THREAD_ID=ambient-thread \
CODEX_PERMISSION_PROFILE=ambient-profile \
CODEX_INTERNAL_ORIGINATOR_OVERRIDE=ambient-origin \
"$ROOT/scripts/run-codex-routing-evals.rb" \
  --codex "$FAKE_CODEX" \
  --auth-path "$FAKE_CODEX_AUTH" \
  --case zh-market-public \
  --case zh-none-code-fix \
  --jobs 2 \
  --output "$ROUTING_FAKE_PASS" > "$TEST_ROOT/routing-runner-pass.log"
ruby -rjson -e '
  results = JSON.parse(File.read(ARGV.fetch(0)))
  abort "expected two passing routing results" unless results.length == 2 && results.all? { |result| result["pass"] }
  abort "result paths must stay relative" unless results.all? { |result| %w[promptPath responsePath logPath].all? { |field| !result.fetch(field).start_with?("/") } }
' "$ROUTING_FAKE_PASS/results.json"
ruby -rjson -e '
  controls = JSON.parse(File.read(ARGV.fetch(0)))
  abort "routing runner did not isolate Codex host state" unless controls.fetch("isolatedHostHome")
  abort "routing runner did not disable Codex analytics" unless controls.fetch("analyticsEnabled") == false
  expected = %w[CODEX_INTERNAL_ORIGINATOR_OVERRIDE CODEX_PERMISSION_PROFILE CODEX_THREAD_ID]
  abort "routing runner did not record ambient context removal" unless controls.fetch("ambientDesktopContextDisabled") == expected
  abort "routing runner did not record its output limit" unless controls.fetch("maxHostOutputBytesPerCase") == 2 * 1024 * 1024
  abort "routing runner did not record disabled web and subagents" unless controls.fetch("webSearch") == false && controls.fetch("subagents") == false
  runtime = %w[maxRuntimeGitFiles maxRuntimeGitTreeEntries maxRuntimeGitBytes maxRuntimeHostHomeFiles maxRuntimeHostHomeTreeEntries maxRuntimeHostHomeBytes].map { |field| controls.fetch(field) }
  abort "routing runner did not record baseline runtime limits" unless controls.fetch("runtimeTreeMonitoring") == true &&
    controls.fetch("concurrentRuntimeMonitoring") == true && controls.fetch("pidMonitoringStartsAtSpawn") == true &&
    controls.fetch("sharedRootMonitoring") == true && controls.fetch("privatePromptIntegrityMonitoring") == false &&
    controls.fetch("outputDirectoryIdentityMonitoring") == true &&
    runtime == [100, 500, 2 * 1024 * 1024, 200, 500, 8 * 1024 * 1024]
  output_runtime = %w[maxRuntimeOutputFiles maxRuntimeOutputTreeEntries maxRuntimeOutputBytes].map { |field| controls.fetch(field) }
  abort "routing runner did not record output-tree limits" unless controls.fetch("outputTreeMonitoring") == true &&
    controls.fetch("exclusiveRunnerOutputs") == true &&
    controls.fetch("workspaceViolationStopsRun") == true &&
    controls.fetch("singleLinkInputFiles") == true &&
    controls.fetch("singleLinkRuntimeFiles") == true &&
    output_runtime == [4_096, 8_192, 640 * 1024 * 1024]
  abort "routing runner invented a workspace limit failure" unless JSON.parse(File.read(ARGV.fetch(1))).all? { |result| result.fetch("workspaceLimitError").nil? }
' "$ROUTING_FAKE_PASS/controls.json" "$ROUTING_FAKE_PASS/results.json"
grep -q '"hostVersion": "codex-cli fake-1.0"' "$ROUTING_FAKE_PASS/controls.json" || fail "routing runner did not record the host version"
[[ ! -e "$ROUTING_FAKE_PASS/workspace" && ! -e "$ROUTING_FAKE_PASS/workspaces" ]] || fail "routing runner retained disposable workspaces"
pass "routing runner isolates and grades clean fake Codex cases"

ROUTING_GENERATED_PROMPT_DRIFT="$TEST_ROOT/routing-generated-prompt-drift"
ROUTING_GENERATED_PROMPT_EXECUTED="$TEST_ROOT/routing-generated-prompt-executed"
if FAKE_CODEX_MUTATE_PROMPT_PATH="$ROUTING_GENERATED_PROMPT_DRIFT/prompts/zh-market-public.txt" \
  FAKE_CODEX_EXECUTION_MARKER="$ROUTING_GENERATED_PROMPT_EXECUTED" \
  "$ROOT/scripts/run-codex-routing-evals.rb" \
  --codex "$FAKE_CODEX" \
  --case zh-market-public \
  --output "$ROUTING_GENERATED_PROMPT_DRIFT" \
  > "$TEST_ROOT/routing-generated-prompt-drift.log" 2>&1; then
  fail "routing runner accepted a retained prompt changed after generation"
fi
grep -q "retained routing prompt changed after generation" \
  "$TEST_ROOT/routing-generated-prompt-drift.log" ||
  fail "routing runner reported the wrong generated-prompt drift failure"
[[ ! -e "$ROUTING_GENERATED_PROMPT_EXECUTED" ]] ||
  fail "routing runner launched a host after generated-prompt drift"
pass "routing runner binds host stdin and invocation hashes to generation-time prompt bytes"

ROUTING_TIMEOUT="$TEST_ROOT/routing-runner-timeout"
if FAKE_CODEX_SLEEP_SECONDS=5 "$ROOT/scripts/run-codex-routing-evals.rb" \
  --codex "$FAKE_CODEX" \
  --case zh-market-public \
  --timeout-seconds 1 \
  --output "$ROUTING_TIMEOUT" > "$TEST_ROOT/routing-runner-timeout.log" 2>&1; then
  fail "routing runner accepted a timed-out host process"
fi
ruby -rjson -e '
  controls = JSON.parse(File.read(ARGV.fetch(0)))
  result = JSON.parse(File.read(ARGV.fetch(1))).fetch(0)
  abort "routing timeout control was not recorded" unless controls.fetch("timeoutSecondsPerCase") == 1
  abort "routing timeout was not retained" unless result.fetch("timedOut") && !result.fetch("executionCompleted") && !result.fetch("pass")
  abort "routing timeout exceeded its termination grace" unless result.fetch("elapsedSeconds") < 4
' "$ROUTING_TIMEOUT/controls.json" "$ROUTING_TIMEOUT/results.json"
grep -q 'FAIL (timeout 1s)' "$TEST_ROOT/routing-runner-timeout.log" || fail "routing timeout was not reported clearly"
pass "routing runner bounds and records stalled host processes"

ROUTING_WORKSPACE_LIMIT="$TEST_ROOT/routing-runner-workspace-limit"
if FAKE_CODEX_WORKSPACE_ESCAPE=1 "$ROOT/scripts/run-codex-routing-evals.rb" \
  --codex "$FAKE_CODEX" \
  --case zh-market-public \
  --timeout-seconds 5 \
  --output "$ROUTING_WORKSPACE_LIMIT" > "$TEST_ROOT/routing-runner-workspace-limit.log" 2>&1; then
  fail "routing runner accepted a host write outside the allowed workspace layout"
fi
ruby -rjson -e '
  result = JSON.parse(File.read(ARGV.fetch(0))).fetch(0)
  error = result.fetch("workspaceLimitError")
  abort "routing workspace escape lost its classification" unless error&.include?("allowed workspace layout") &&
    result.fetch("errorCategory") == "workspace-limit" && !result.fetch("executionCompleted") && !result.fetch("pass")
  abort "routing workspace watchdog waited for the case timeout" unless result.fetch("elapsedSeconds") < 4
' "$ROUTING_WORKSPACE_LIMIT/results.json"
pass "routing runner terminates hosts that write outside the allowed workspace layout"

ROUTING_ROOT_LIMIT="$TEST_ROOT/routing-runner-root-limit"
if FAKE_CODEX_ROOT_ESCAPE=1 "$ROOT/scripts/run-codex-routing-evals.rb" \
  --codex "$FAKE_CODEX" \
  --case zh-market-public \
  --timeout-seconds 5 \
  --output "$ROUTING_ROOT_LIMIT" > "$TEST_ROOT/routing-runner-root-limit.log" 2>&1; then
  fail "routing runner accepted a host write outside its case directory"
fi
ruby -rjson -e '
  result = JSON.parse(File.read(ARGV.fetch(0))).fetch(0)
  error = result.fetch("workspaceLimitError")
  abort "routing shared-root escape lost its classification" unless error&.include?("shared workspace root") &&
    result.fetch("errorCategory") == "workspace-limit" && !result.fetch("executionCompleted")
' "$ROUTING_ROOT_LIMIT/results.json"
pass "routing runner terminates hosts that write into the shared workspace root"

ROUTING_RESOURCE_STOP="$TEST_ROOT/routing-runner-resource-stop"
if FAKE_CODEX_ROOT_ESCAPE=1 "$ROOT/scripts/run-codex-routing-evals.rb" \
  --codex "$FAKE_CODEX" \
  --case zh-market-public \
  --case zh-none-code-fix \
  --jobs 1 \
  --timeout-seconds 5 \
  --output "$ROUTING_RESOURCE_STOP" > "$TEST_ROOT/routing-runner-resource-stop.log" 2>&1; then
  fail "routing runner continued after a workspace safety violation"
fi
ruby -rjson -e '
  controls = JSON.parse(File.read(ARGV.fetch(0)))
  results = JSON.parse(File.read(ARGV.fetch(1)))
  abort "resource-stop control changed" unless controls.fetch("workspaceViolationStopsRun") == true && controls.fetch("cases").length == 2
  abort "runner scheduled a later batch after a workspace violation" unless results.length == 1 && results.fetch(0).fetch("workspaceLimitError")
' "$ROUTING_RESOURCE_STOP/controls.json" "$ROUTING_RESOURCE_STOP/results.json"
grep -q 'PASS=0/2' "$TEST_ROOT/routing-runner-resource-stop.log" ||
  fail "routing resource-stop summary hid unexecuted cases"
pass "routing runner stops later batches after a workspace safety violation"

ROUTING_OUTPUT_TREE_LIMIT="$TEST_ROOT/routing-runner-output-tree-limit"
if FAKE_CODEX_OUTPUT_ESCAPE=1 "$ROOT/scripts/run-codex-routing-evals.rb" \
  --codex "$FAKE_CODEX" \
  --case zh-market-public \
  --timeout-seconds 5 \
  --output "$ROUTING_OUTPUT_TREE_LIMIT" > "$TEST_ROOT/routing-runner-output-tree-limit.log" 2>&1; then
  fail "routing runner accepted an undeclared output-tree file"
fi
ruby -rjson -e '
  result = JSON.parse(File.read(ARGV.fetch(0))).fetch(0)
  error = result.fetch("workspaceLimitError")
  abort "routing output-tree escape lost its classification" unless error&.include?("runner output tree") &&
    result.fetch("errorCategory") == "workspace-limit" && !result.fetch("executionCompleted")
' "$ROUTING_OUTPUT_TREE_LIMIT/results.json"
pass "routing runner terminates hosts that add undeclared output-tree files"

ROUTING_OUTPUT_LIMIT="$TEST_ROOT/routing-runner-output-limit"
if FAKE_CODEX_STDOUT_BYTES=$((2 * 1024 * 1024 + 1)) \
  "$ROOT/scripts/run-codex-routing-evals.rb" \
  --codex "$FAKE_CODEX" \
  --case zh-market-public \
  --output "$ROUTING_OUTPUT_LIMIT" > "$TEST_ROOT/routing-runner-output-limit.log" 2>&1; then
  fail "routing runner accepted host output above its byte limit"
fi
ruby -rjson -e '
  controls = JSON.parse(File.read(ARGV.fetch(0)))
  result = JSON.parse(File.read(ARGV.fetch(1))).fetch(0)
  limit = controls.fetch("maxHostOutputBytesPerCase")
  abort "routing output limit drifted" unless limit == 2 * 1024 * 1024
  abort "routing output limit was not retained" unless result.fetch("outputLimited") && result.fetch("hostOutputBytes") > limit
  abort "routing output overflow was misclassified" unless result.fetch("errorCategory") == "output-limit"
  abort "routing output overflow was accepted" if result.fetch("timedOut") || result.fetch("executionCompleted") || result.fetch("pass")
' "$ROUTING_OUTPUT_LIMIT/controls.json" "$ROUTING_OUTPUT_LIMIT/results.json"
grep -q 'FAIL (output limit 2097152 bytes)' "$TEST_ROOT/routing-runner-output-limit.log" ||
  fail "routing output limit was not reported clearly"
pass "routing runner terminates and records oversized host output"

ROUTING_ARCHIVE_FIXTURE="$(copy_fixture routing-archive)"
"$ROUTING_ARCHIVE_FIXTURE/scripts/archive-codex-routing-run.rb" \
  --run-dir "$ROUTING_FAKE_PASS" \
  --archive 2026-08-01-fake-routing \
  --phase fake > "$TEST_ROOT/routing-archive.log"
ROUTING_ARCHIVE="$ROUTING_ARCHIVE_FIXTURE/evals/runs/2026-08-01-fake-routing"
[[ -f "$ROUTING_ARCHIVE/run.json" && -f "$ROUTING_ARCHIVE/archive-manifest.txt" ]] || fail "routing archiver omitted schema-v2 control files"
[[ -f "$ROUTING_ARCHIVE/raw/artifact-manifest.txt" ]] || fail "routing archiver omitted the raw manifest"
[[ -f "$ROUTING_ARCHIVE/raw/prompts/zh-market-public.txt" ]] || fail "routing archiver omitted an exact prompt"
[[ -f "$ROUTING_ARCHIVE/raw/responses/zh-none-code-fix.txt" ]] || fail "routing archiver omitted a raw response"
if find "$ROUTING_ARCHIVE" -type f -path '*/logs/*' | grep -q .; then
  fail "routing archiver copied private CLI logs"
fi
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV.fetch(0)))
  defaults = data.fetch("executionDefaults")
  runtime = %w[maxRuntimeGitFiles maxRuntimeGitTreeEntries maxRuntimeGitBytes maxRuntimeHostHomeFiles maxRuntimeHostHomeTreeEntries maxRuntimeHostHomeBytes].map { |field| defaults.fetch(field) }
  abort "routing archive omitted baseline runtime limits" unless defaults.fetch("runtimeTreeMonitoring") == true &&
    defaults.fetch("concurrentRuntimeMonitoring") == true && defaults.fetch("pidMonitoringStartsAtSpawn") == true &&
    defaults.fetch("sharedRootMonitoring") == true && defaults.fetch("privatePromptIntegrityMonitoring") == false &&
    defaults.fetch("outputDirectoryIdentityMonitoring") == true &&
    runtime == [100, 500, 2 * 1024 * 1024, 200, 500, 8 * 1024 * 1024]
  output_runtime = %w[maxRuntimeOutputFiles maxRuntimeOutputTreeEntries maxRuntimeOutputBytes].map { |field| defaults.fetch(field) }
  abort "routing archive omitted output-tree limits" unless defaults.fetch("outputTreeMonitoring") == true &&
    defaults.fetch("exclusiveRunnerOutputs") == true &&
    defaults.fetch("workspaceViolationStopsRun") == true &&
    defaults.fetch("singleLinkInputFiles") == true &&
    defaults.fetch("singleLinkRuntimeFiles") == true &&
    output_runtime == [4_096, 8_192, 640 * 1024 * 1024]
' "$ROUTING_ARCHIVE/run.json"
ruby "$ROUTING_ARCHIVE_FIXTURE/scripts/validate-evidence.rb" >/dev/null

SOURCE_SNAPSHOT_REPLACEMENT_HOOK="$TEST_ROOT/source-snapshot-replacement-hook.rb"
printf '%s\n' \
  'require ENV.fetch("SOURCE_SNAPSHOT_LIBRARY")' \
  'module ZstackSourceSnapshotReplacement' \
  '  def capture(relative_path)' \
  '    path = super' \
  '    return path unless relative_path == ENV.fetch("SOURCE_SNAPSHOT_REPLACE_RELATIVE")' \
  '    return path if instance_variable_defined?(:@zstack_replaced_capture)' \
  '    File.rename(path, "#{path}.captured")' \
  '    File.binwrite(path, ENV.fetch("SOURCE_SNAPSHOT_REPLACEMENT_BYTES"))' \
  '    @zstack_replaced_capture = true' \
  '    path' \
  '  end' \
  'end' \
  'Zstack::EvalSourceSnapshot.prepend(ZstackSourceSnapshotReplacement)' \
  > "$SOURCE_SNAPSHOT_REPLACEMENT_HOOK"
SOURCE_SNAPSHOT_LIBRARY="$ROUTING_ARCHIVE_FIXTURE/scripts/lib/eval_source_snapshot.rb" \
SOURCE_SNAPSHOT_REPLACE_RELATIVE="candidate-descriptions.txt" \
SOURCE_SNAPSHOT_REPLACEMENT_BYTES="replacement snapshot path must not be parsed" \
RUBYOPT="-r$SOURCE_SNAPSHOT_REPLACEMENT_HOOK" \
  "$ROUTING_ARCHIVE_FIXTURE/scripts/archive-codex-routing-run.rb" \
  --run-dir "$ROUTING_FAKE_PASS" \
  --archive 2026-08-01-replaced-source-routing \
  --phase fake > "$TEST_ROOT/routing-archive-replaced-source.log"
cmp -s "$ROUTING_FAKE_PASS/candidate-descriptions.txt" \
  "$ROUTING_ARCHIVE_FIXTURE/evals/runs/2026-08-01-replaced-source-routing/raw/candidate-descriptions.txt" ||
  fail "routing archiver published bytes from a replaced private snapshot path"
pass "routing archiver parses and publishes immutable in-memory source bytes"

ROUTING_RAW_DRIFT_FIXTURE="$(copy_fixture routing-archive-raw-drift)"
mv "$ROUTING_RAW_DRIFT_FIXTURE/scripts/validate-evidence.rb" \
  "$ROUTING_RAW_DRIFT_FIXTURE/scripts/validate-evidence.real.rb"
printf '%s\n' \
  '#!/usr/bin/env ruby' \
  'require "digest"' \
  'require "rbconfig"' \
  'real = File.expand_path("validate-evidence.real.rb", __dir__)' \
  'unless ARGV.include?("--candidate")' \
  '  exec RbConfig.ruby, real, *ARGV' \
  'end' \
  'exit($?.exitstatus || 1) unless system(RbConfig.ruby, real, *ARGV)' \
  'candidate = ARGV.fetch(ARGV.index("--candidate") + 1)' \
  'response = File.join(candidate, "raw", "responses", "zh-market-public.txt")' \
  'File.write(response, "Selection: z-market-validate\nReason: self-consistent post-validation replacement\n")' \
  'def update_entry(manifest, relative, target)' \
  '  content = File.binread(target)' \
  '  replacement = "#{Digest::SHA256.hexdigest(content)}  #{content.bytesize}  #{relative}"' \
  '  lines = File.readlines(manifest, chomp: true)' \
  '  matches = 0' \
  '  lines.map! do |line|' \
  '    if line.match?(/\A[0-9a-f]{64}  \d+  #{Regexp.escape(relative)}\z/)' \
  '      matches += 1' \
  '      replacement' \
  '    else' \
  '      line' \
  '    end' \
  '  end' \
  '  raise "missing manifest entry #{relative}" unless matches == 1' \
  '  File.write(manifest, lines.join("\n") + "\n")' \
  'end' \
  'raw_manifest = File.join(candidate, "raw", "artifact-manifest.txt")' \
  'archive_manifest = File.join(candidate, "archive-manifest.txt")' \
  'update_entry(raw_manifest, "responses/zh-market-public.txt", response)' \
  'update_entry(archive_manifest, "raw/responses/zh-market-public.txt", response)' \
  'update_entry(archive_manifest, "raw/artifact-manifest.txt", raw_manifest)' \
  > "$ROUTING_RAW_DRIFT_FIXTURE/scripts/validate-evidence.rb"
chmod +x "$ROUTING_RAW_DRIFT_FIXTURE/scripts/validate-evidence.rb"
if "$ROUTING_RAW_DRIFT_FIXTURE/scripts/archive-codex-routing-run.rb" \
  --run-dir "$ROUTING_FAKE_PASS" \
  --archive 2026-08-01-raw-drift-routing \
  --phase drift > "$TEST_ROOT/routing-archive-raw-drift.log" 2>&1; then
  fail "routing archiver accepted self-consistent raw replacement after candidate validation"
fi
grep -q 'raw archive file differs from captured bytes: responses/zh-market-public.txt' \
  "$TEST_ROOT/routing-archive-raw-drift.log" ||
  fail "routing archiver reported the wrong captured-raw drift failure"
[[ ! -e "$ROUTING_RAW_DRIFT_FIXTURE/evals/runs/2026-08-01-raw-drift-routing" ]] ||
  fail "routing archiver published self-consistent bytes that differ from runner capture"
raw_drift_temps="$(find "$ROUTING_RAW_DRIFT_FIXTURE/evals/runs" \
  -maxdepth 1 -name '.zstack-routing-archive-*' -print | wc -l | tr -d ' ')"
[[ "$raw_drift_temps" -eq 0 ]] ||
  fail "routing raw-drift rejection left a transaction directory"
pass "routing archiver rejects self-consistent raw drift after candidate validation"

ROUTING_CANDIDATE_TREE_DRIFT_FIXTURE="$(copy_fixture routing-archive-candidate-tree-drift)"
mv "$ROUTING_CANDIDATE_TREE_DRIFT_FIXTURE/scripts/validate-evidence.rb" \
  "$ROUTING_CANDIDATE_TREE_DRIFT_FIXTURE/scripts/validate-evidence.real.rb"
printf '%s\n' \
  '#!/usr/bin/env ruby' \
  'require "digest"' \
  'require "rbconfig"' \
  'real = File.expand_path("validate-evidence.real.rb", __dir__)' \
  'unless ARGV.include?("--candidate")' \
  '  exec RbConfig.ruby, real, *ARGV' \
  'end' \
  'exit($?.exitstatus || 1) unless system(RbConfig.ruby, real, *ARGV)' \
  'candidate = ARGV.fetch(ARGV.index("--candidate") + 1)' \
  'summary = File.join(candidate, "summary.md")' \
  'File.open(summary, "a") { |file| file.write("\nSelf-consistent post-validation summary replacement.\n") }' \
  'manifest = File.join(candidate, "archive-manifest.txt")' \
  'content = File.binread(summary)' \
  'replacement = "#{Digest::SHA256.hexdigest(content)}  #{content.bytesize}  summary.md"' \
  'lines = File.readlines(manifest, chomp: true)' \
  'matches = 0' \
  'lines.map! do |line|' \
  '  if line.match?(/\A[0-9a-f]{64}  \d+  summary\.md\z/)' \
  '    matches += 1' \
  '    replacement' \
  '  else' \
  '    line' \
  '  end' \
  'end' \
  'raise "missing summary manifest entry" unless matches == 1' \
  'File.write(manifest, lines.join("\n") + "\n")' \
  > "$ROUTING_CANDIDATE_TREE_DRIFT_FIXTURE/scripts/validate-evidence.rb"
chmod +x "$ROUTING_CANDIDATE_TREE_DRIFT_FIXTURE/scripts/validate-evidence.rb"
if "$ROUTING_CANDIDATE_TREE_DRIFT_FIXTURE/scripts/archive-codex-routing-run.rb" \
  --run-dir "$ROUTING_FAKE_PASS" \
  --archive 2026-08-01-candidate-tree-drift-routing \
  --phase drift > "$TEST_ROOT/routing-archive-candidate-tree-drift.log" 2>&1; then
  fail "routing archiver accepted self-consistent generated-file drift after candidate validation"
fi
grep -q 'archive candidate changed during pre-publication validation' \
  "$TEST_ROOT/routing-archive-candidate-tree-drift.log" ||
  fail "routing archiver reported the wrong candidate-tree drift failure"
[[ ! -e "$ROUTING_CANDIDATE_TREE_DRIFT_FIXTURE/evals/runs/2026-08-01-candidate-tree-drift-routing" ]] ||
  fail "routing archiver published generated bytes changed after candidate validation"
candidate_tree_drift_temps="$(find "$ROUTING_CANDIDATE_TREE_DRIFT_FIXTURE/evals/runs" \
  -maxdepth 1 -name '.zstack-routing-archive-*' -print | wc -l | tr -d ' ')"
[[ "$candidate_tree_drift_temps" -eq 0 ]] ||
  fail "routing candidate-tree drift rejection left a transaction directory"
pass "routing archiver binds the complete candidate tree across validation"

archive_manifest_before="$(ruby -rdigest -e 'puts Digest::SHA256.file(ARGV.fetch(0)).hexdigest' "$ROUTING_ARCHIVE/archive-manifest.txt")"
if "$ROUTING_ARCHIVE_FIXTURE/scripts/archive-codex-routing-run.rb" \
  --run-dir "$ROUTING_FAKE_PASS" \
  --archive 2026-08-01-fake-routing \
  --phase fake > "$TEST_ROOT/routing-archive-duplicate.log" 2>&1; then
  fail "routing archiver overwrote an existing archive"
fi
[[ "$(ruby -rdigest -e 'puts Digest::SHA256.file(ARGV.fetch(0)).hexdigest' "$ROUTING_ARCHIVE/archive-manifest.txt")" == "$archive_manifest_before" ]] || fail "duplicate routing archive attempt changed existing evidence"

ROUTING_TAMPERED="$TEST_ROOT/routing-runner-tampered"
cp -R "$ROUTING_FAKE_PASS" "$ROUTING_TAMPERED"
printf '%s\n' "session id: 019fbad0-bad0-bad0-bad0-bad0bad0bad0" >> "$ROUTING_TAMPERED/responses/zh-market-public.txt"
if "$ROUTING_ARCHIVE_FIXTURE/scripts/archive-codex-routing-run.rb" \
  --run-dir "$ROUTING_TAMPERED" \
  --archive 2026-08-01-tampered-routing \
  --phase tampered > "$TEST_ROOT/routing-archive-tampered.log" 2>&1; then
  fail "routing archiver accepted a response that drifted after grading"
fi
[[ ! -e "$ROUTING_ARCHIVE_FIXTURE/evals/runs/2026-08-01-tampered-routing" ]] || fail "routing archiver published tampered evidence"

ROUTING_DIAGNOSTIC_TAMPERED="$TEST_ROOT/routing-runner-diagnostic-tampered"
cp -R "$ROUTING_FAKE_PASS" "$ROUTING_DIAGNOSTIC_TAMPERED"
ruby -rjson -e '
  path = ARGV.fetch(0)
  results = JSON.parse(File.read(path))
  results.fetch(0).delete("responseFileError")
  File.write(path, JSON.pretty_generate(results) + "\n")
' "$ROUTING_DIAGNOSTIC_TAMPERED/results.json"
if "$ROUTING_ARCHIVE_FIXTURE/scripts/archive-codex-routing-run.rb" \
  --run-dir "$ROUTING_DIAGNOSTIC_TAMPERED" \
  --archive 2026-08-01-tampered-routing-diagnostic \
  --phase tampered > "$TEST_ROOT/routing-archive-diagnostic-tampered.log" 2>&1; then
  fail "routing archiver accepted a missing response safety diagnostic"
fi
grep -q "result is missing required fields: responseFileError" "$TEST_ROOT/routing-archive-diagnostic-tampered.log" ||
  fail "routing archiver reported the wrong missing-diagnostic failure"
[[ ! -e "$ROUTING_ARCHIVE_FIXTURE/evals/runs/2026-08-01-tampered-routing-diagnostic" ]] ||
  fail "routing archiver published evidence with missing response provenance"

ROUTING_OUTPUT_STATUS_TAMPERED="$TEST_ROOT/routing-runner-output-status-tampered"
cp -R "$ROUTING_FAKE_PASS" "$ROUTING_OUTPUT_STATUS_TAMPERED"
ruby -rjson -e '
  path = ARGV.fetch(0)
  results = JSON.parse(File.read(path))
  results.fetch(0)["outputLimited"] = true
  File.write(path, JSON.pretty_generate(results) + "\n")
' "$ROUTING_OUTPUT_STATUS_TAMPERED/results.json"
if "$ROUTING_ARCHIVE_FIXTURE/scripts/archive-codex-routing-run.rb" \
  --run-dir "$ROUTING_OUTPUT_STATUS_TAMPERED" \
  --archive 2026-08-01-tampered-routing-output-status \
  --phase tampered > "$TEST_ROOT/routing-archive-output-status-tampered.log" 2>&1; then
  fail "routing archiver accepted contradictory output-limit status"
fi
grep -q "outputLimited must be false for archiving" "$TEST_ROOT/routing-archive-output-status-tampered.log" ||
  fail "routing archiver reported the wrong output-status failure"
[[ ! -e "$ROUTING_ARCHIVE_FIXTURE/evals/runs/2026-08-01-tampered-routing-output-status" ]] ||
  fail "routing archiver published contradictory output-limit provenance"

ROUTING_WORKSPACE_STATUS_TAMPERED="$TEST_ROOT/routing-runner-workspace-status-tampered"
cp -R "$ROUTING_FAKE_PASS" "$ROUTING_WORKSPACE_STATUS_TAMPERED"
ruby -rjson -e '
  path = ARGV.fetch(0)
  results = JSON.parse(File.read(path))
  results.fetch(0)["workspaceLimitError"] = "synthetic workspace limit"
  File.write(path, JSON.pretty_generate(results) + "\n")
' "$ROUTING_WORKSPACE_STATUS_TAMPERED/results.json"
if "$ROUTING_ARCHIVE_FIXTURE/scripts/archive-codex-routing-run.rb" \
  --run-dir "$ROUTING_WORKSPACE_STATUS_TAMPERED" \
  --archive 2026-08-01-tampered-routing-workspace-status \
  --phase tampered > "$TEST_ROOT/routing-archive-workspace-status-tampered.log" 2>&1; then
  fail "routing archiver accepted a workspace-limit failure"
fi
grep -q "workspaceLimitError must be null for archiving" "$TEST_ROOT/routing-archive-workspace-status-tampered.log" ||
  fail "routing archiver reported the wrong workspace-status failure"
[[ ! -e "$ROUTING_ARCHIVE_FIXTURE/evals/runs/2026-08-01-tampered-routing-workspace-status" ]] ||
  fail "routing archiver published workspace-limit provenance"

ROUTING_RUNTIME_CONTROLS_TAMPERED="$TEST_ROOT/routing-runner-runtime-controls-tampered"
cp -R "$ROUTING_FAKE_PASS" "$ROUTING_RUNTIME_CONTROLS_TAMPERED"
ruby -rjson -e '
  path = ARGV.fetch(0)
  controls = JSON.parse(File.read(path))
  controls["maxRuntimeGitBytes"] = 1
  File.write(path, JSON.pretty_generate(controls) + "\n")
' "$ROUTING_RUNTIME_CONTROLS_TAMPERED/controls.json"
if "$ROUTING_ARCHIVE_FIXTURE/scripts/archive-codex-routing-run.rb" \
  --run-dir "$ROUTING_RUNTIME_CONTROLS_TAMPERED" \
  --archive 2026-08-01-tampered-routing-runtime-controls \
  --phase tampered > "$TEST_ROOT/routing-archive-runtime-controls-tampered.log" 2>&1; then
  fail "routing archiver accepted tampered runtime tree limits"
fi
grep -q "runtime tree limits must match the runner safety limits" "$TEST_ROOT/routing-archive-runtime-controls-tampered.log" ||
  fail "routing archiver reported the wrong runtime-limit failure"

ROUTING_ELAPSED_TAMPERED="$TEST_ROOT/routing-runner-elapsed-tampered"
cp -R "$ROUTING_FAKE_PASS" "$ROUTING_ELAPSED_TAMPERED"
ruby -rjson -e '
  path = ARGV.fetch(0)
  content = File.read(path)
  replacement = content.sub(/"elapsedSeconds":\s*[0-9]+(?:\.[0-9]+)?/, %q{"elapsedSeconds": 1e309})
  abort "elapsed fixture did not change" if replacement == content
  File.write(path, replacement)
' "$ROUTING_ELAPSED_TAMPERED/results.json"
if "$ROUTING_ARCHIVE_FIXTURE/scripts/archive-codex-routing-run.rb" \
  --run-dir "$ROUTING_ELAPSED_TAMPERED" \
  --archive 2026-08-01-tampered-routing-elapsed \
  --phase tampered > "$TEST_ROOT/routing-archive-elapsed-tampered.log" 2>&1; then
  fail "routing archiver accepted invalid elapsed-time provenance"
fi
grep -q "JSON contains a non-finite number" "$TEST_ROOT/routing-archive-elapsed-tampered.log" ||
  fail "routing archiver reported the wrong elapsed-time failure"
[[ ! -e "$ROUTING_ARCHIVE_FIXTURE/evals/runs/2026-08-01-tampered-routing-elapsed" ]] ||
  fail "routing archiver published invalid elapsed-time provenance"

ROUTING_DUPLICATE_CONTROLS="$TEST_ROOT/routing-runner-duplicate-controls"
cp -R "$ROUTING_FAKE_PASS" "$ROUTING_DUPLICATE_CONTROLS"
ruby -e '
  path = ARGV.fetch(0)
  content = File.read(path)
  replacement = content.sub(/\A\{/, "{\n  \"webSearch\": true,")
  abort "duplicate-key fixture did not change" if replacement == content
  File.write(path, replacement)
' "$ROUTING_DUPLICATE_CONTROLS/controls.json"
if "$ROUTING_ARCHIVE_FIXTURE/scripts/archive-codex-routing-run.rb" \
  --run-dir "$ROUTING_DUPLICATE_CONTROLS" \
  --archive 2026-08-01-duplicate-controls-routing \
  --phase tampered > "$TEST_ROOT/routing-archive-duplicate-controls.log" 2>&1; then
  fail "routing archiver accepted ambiguous duplicate controls"
fi
grep -q "duplicate JSON object key" "$TEST_ROOT/routing-archive-duplicate-controls.log" ||
  fail "routing archiver reported the wrong duplicate-key failure"
[[ ! -e "$ROUTING_ARCHIVE_FIXTURE/evals/runs/2026-08-01-duplicate-controls-routing" ]] ||
  fail "routing archiver published ambiguous duplicate controls"

ROUTING_DUPLICATE_YAML_FIXTURE="$(copy_fixture routing-duplicate-yaml)"
ruby -e '
  path = ARGV.fetch(0)
  content = File.read(path)
  replacement = content.sub(/^(    expected_skill: .+)$/) { |line| "    expected_skill: none\n#{line}" }
  abort "duplicate routing fixture did not change" if replacement == content
  File.write(path, replacement)
' "$ROUTING_DUPLICATE_YAML_FIXTURE/evals/routing.yaml"
if "$ROUTING_DUPLICATE_YAML_FIXTURE/scripts/archive-codex-routing-run.rb" \
  --run-dir "$ROUTING_FAKE_PASS" \
  --archive 2026-08-01-duplicate-yaml-routing \
  --phase tampered > "$TEST_ROOT/routing-archive-duplicate-yaml.log" 2>&1; then
  fail "routing archiver accepted a duplicate eval manifest key without doctor"
fi
grep -q 'duplicate key "expected_skill"' "$TEST_ROOT/routing-archive-duplicate-yaml.log" ||
  fail "routing archiver reported the wrong duplicate eval manifest failure"
[[ ! -e "$ROUTING_DUPLICATE_YAML_FIXTURE/evals/runs/2026-08-01-duplicate-yaml-routing" ]] ||
  fail "routing archiver published evidence from an ambiguous eval manifest"

ROUTING_PROMPT_TAMPERED="$TEST_ROOT/routing-runner-prompt-tampered"
cp -R "$ROUTING_FAKE_PASS" "$ROUTING_PROMPT_TAMPERED"
printf '%s\n' 'Injected instruction outside the canonical wrapper.' \
  > "$ROUTING_PROMPT_TAMPERED/prompts/zh-market-public.txt.next"
cat "$ROUTING_PROMPT_TAMPERED/prompts/zh-market-public.txt" \
  >> "$ROUTING_PROMPT_TAMPERED/prompts/zh-market-public.txt.next"
mv "$ROUTING_PROMPT_TAMPERED/prompts/zh-market-public.txt.next" \
  "$ROUTING_PROMPT_TAMPERED/prompts/zh-market-public.txt"
if "$ROUTING_ARCHIVE_FIXTURE/scripts/archive-codex-routing-run.rb" \
  --run-dir "$ROUTING_PROMPT_TAMPERED" \
  --archive 2026-08-01-tampered-routing-prompt \
  --phase tampered > "$TEST_ROOT/routing-archive-prompt-tampered.log" 2>&1; then
  fail "routing archiver accepted a non-canonical prompt wrapper"
fi
grep -q "prompt differs from the canonical routing wrapper" "$TEST_ROOT/routing-archive-prompt-tampered.log" ||
  fail "routing archiver reported the wrong prompt-wrapper failure"
[[ ! -e "$ROUTING_ARCHIVE_FIXTURE/evals/runs/2026-08-01-tampered-routing-prompt" ]] ||
  fail "routing archiver published a non-canonical prompt"

ROUTING_NETWORK_CONTROLS_TAMPERED="$TEST_ROOT/routing-network-controls-tampered"
cp -R "$ROUTING_FAKE_PASS" "$ROUTING_NETWORK_CONTROLS_TAMPERED"
ruby -rjson -e '
  path = ARGV.fetch(0)
  controls = JSON.parse(File.read(path))
  controls["webSearch"] = true
  File.write(path, JSON.pretty_generate(controls) + "\n")
' "$ROUTING_NETWORK_CONTROLS_TAMPERED/controls.json"
if "$ROUTING_ARCHIVE_FIXTURE/scripts/archive-codex-routing-run.rb" \
  --run-dir "$ROUTING_NETWORK_CONTROLS_TAMPERED" \
  --archive 2026-08-01-tampered-routing-network \
  --phase tampered > "$TEST_ROOT/routing-archive-network-tampered.log" 2>&1; then
  fail "routing archiver accepted enabled web search"
fi
grep -q "webSearch must be false" "$TEST_ROOT/routing-archive-network-tampered.log" ||
  fail "routing archiver reported the wrong web-search control failure"
[[ ! -e "$ROUTING_ARCHIVE_FIXTURE/evals/runs/2026-08-01-tampered-routing-network" ]] ||
  fail "routing archiver published enabled web search"

ROUTING_CONTROLS_TAMPERED="$TEST_ROOT/routing-runner-controls-tampered"
cp -R "$ROUTING_FAKE_PASS" "$ROUTING_CONTROLS_TAMPERED"
ruby -rjson -e '
  path = ARGV.fetch(0)
  controls = JSON.parse(File.read(path))
  controls["model"] = "tampered-model"
  File.write(path, JSON.pretty_generate(controls) + "\n")
' "$ROUTING_CONTROLS_TAMPERED/controls.json"
if "$ROUTING_ARCHIVE_FIXTURE/scripts/archive-codex-routing-run.rb" \
  --run-dir "$ROUTING_CONTROLS_TAMPERED" \
  --archive 2026-08-01-tampered-controls-routing \
  --phase tampered > "$TEST_ROOT/routing-archive-controls-tampered.log" 2>&1; then
  fail "routing archiver trusted controls that disagreed with the private log"
fi
grep -q "runner log model does not match controls.json" "$TEST_ROOT/routing-archive-controls-tampered.log" || fail "routing archiver reported the wrong controls/log mismatch"
[[ ! -e "$ROUTING_ARCHIVE_FIXTURE/evals/runs/2026-08-01-tampered-controls-routing" ]] || fail "routing archiver published false provenance"

ROUTING_LIMIT_TAMPERED="$TEST_ROOT/routing-runner-limit-tampered"
cp -R "$ROUTING_FAKE_PASS" "$ROUTING_LIMIT_TAMPERED"
ruby -rjson -e '
  path = ARGV.fetch(0)
  controls = JSON.parse(File.read(path))
  controls["maxHostOutputBytesPerCase"] = 1
  File.write(path, JSON.pretty_generate(controls) + "\n")
' "$ROUTING_LIMIT_TAMPERED/controls.json"
if "$ROUTING_ARCHIVE_FIXTURE/scripts/archive-codex-routing-run.rb" \
  --run-dir "$ROUTING_LIMIT_TAMPERED" \
  --archive 2026-08-01-tampered-limit-routing \
  --phase tampered > "$TEST_ROOT/routing-archive-limit-tampered.log" 2>&1; then
  fail "routing archiver accepted a tampered host-output limit"
fi
grep -q "maxHostOutputBytesPerCase must match the runner safety limit" "$TEST_ROOT/routing-archive-limit-tampered.log" ||
  fail "routing archiver reported the wrong host-output-limit failure"
[[ ! -e "$ROUTING_ARCHIVE_FIXTURE/evals/runs/2026-08-01-tampered-limit-routing" ]] ||
  fail "routing archiver published tampered output-limit provenance"
pass "routing archiver atomically preserves canonical prompts and responses without private logs"

ROUTING_ROLLBACK_FIXTURE="$(copy_fixture routing-archive-rollback)"
ROLLBACK_COUNTER="$TEST_ROOT/routing-archive-validation-counter"
printf '%s\n' \
  '#!/usr/bin/env ruby' \
  'counter = ENV.fetch("ROUTING_ARCHIVE_VALIDATION_COUNTER")' \
  'count = File.exist?(counter) ? File.read(counter).to_i : 0' \
  'count += 1' \
  'File.write(counter, "#{count}\n")' \
  'if count == 3' \
  '  warn "injected post-publish validation failure"' \
  '  exit 1' \
  'end' \
  'puts "evidence validation #{count} passed"' > "$ROUTING_ROLLBACK_FIXTURE/scripts/validate-evidence.rb"
chmod +x "$ROUTING_ROLLBACK_FIXTURE/scripts/validate-evidence.rb"
if ROUTING_ARCHIVE_VALIDATION_COUNTER="$ROLLBACK_COUNTER" \
  "$ROUTING_ROLLBACK_FIXTURE/scripts/archive-codex-routing-run.rb" \
  --run-dir "$ROUTING_FAKE_PASS" \
  --archive 2026-08-01-rollback-routing \
  --phase rollback > "$TEST_ROOT/routing-archive-rollback.log" 2>&1; then
  fail "routing archiver reported success after post-publish validation failed"
fi
[[ ! -e "$ROUTING_ROLLBACK_FIXTURE/evals/runs/2026-08-01-rollback-routing" ]] || fail "routing archiver left a failed published archive"
[[ "$(cat "$ROLLBACK_COUNTER")" -eq 3 ]] || fail "routing rollback fixture did not reach post-publish validation"
rollback_temps="$(find "$ROUTING_ROLLBACK_FIXTURE/evals/runs" -maxdepth 1 -name '.zstack-routing-archive-*' -print | wc -l | tr -d ' ')"
[[ "$rollback_temps" -eq 0 ]] || fail "routing archiver left a transaction directory after rollback"
pass "routing archiver rolls back post-publish validation failures"

ROUTING_REPLACED_ROLLBACK_FIXTURE="$(copy_fixture routing-archive-replaced-rollback)"
mv "$ROUTING_REPLACED_ROLLBACK_FIXTURE/scripts/validate-evidence.rb" \
  "$ROUTING_REPLACED_ROLLBACK_FIXTURE/scripts/validate-evidence.real.rb"
REPLACED_ROLLBACK_COUNTER="$TEST_ROOT/routing-archive-replaced-validation-counter"
REPLACED_ROLLBACK_ARCHIVE="$ROUTING_REPLACED_ROLLBACK_FIXTURE/evals/runs/2026-08-01-replaced-rollback-routing"
REPLACED_ROLLBACK_MOVED="$TEST_ROOT/routing-archive-created-before-replacement"
printf '%s\n' \
  '#!/usr/bin/env ruby' \
  'require "fileutils"' \
  'require "rbconfig"' \
  'counter = ENV.fetch("ROUTING_REPLACED_VALIDATION_COUNTER")' \
  'count = File.exist?(counter) ? File.read(counter).to_i : 0' \
  'count += 1' \
  'File.write(counter, "#{count}\n")' \
  'if count == 3' \
  '  target = ENV.fetch("ROUTING_REPLACED_ARCHIVE")' \
  '  File.rename(target, ENV.fetch("ROUTING_REPLACED_MOVED"))' \
  '  Dir.mkdir(target, 0o700)' \
  '  File.write(File.join(target, "replacement.txt"), "replacement must survive\n")' \
  '  warn "injected post-publish replacement failure"' \
  '  exit 1' \
  'end' \
  'exec RbConfig.ruby, File.expand_path("validate-evidence.real.rb", __dir__), *ARGV' \
  > "$ROUTING_REPLACED_ROLLBACK_FIXTURE/scripts/validate-evidence.rb"
chmod +x "$ROUTING_REPLACED_ROLLBACK_FIXTURE/scripts/validate-evidence.rb"
if ROUTING_REPLACED_VALIDATION_COUNTER="$REPLACED_ROLLBACK_COUNTER" \
  ROUTING_REPLACED_ARCHIVE="$REPLACED_ROLLBACK_ARCHIVE" \
  ROUTING_REPLACED_MOVED="$REPLACED_ROLLBACK_MOVED" \
  "$ROUTING_REPLACED_ROLLBACK_FIXTURE/scripts/archive-codex-routing-run.rb" \
  --run-dir "$ROUTING_FAKE_PASS" \
  --archive 2026-08-01-replaced-rollback-routing \
  --phase rollback > "$TEST_ROOT/routing-archive-replaced-rollback.log" 2>&1; then
  fail "routing archiver reported success after its published directory was replaced"
fi
grep -q "injected post-publish replacement failure" "$TEST_ROOT/routing-archive-replaced-rollback.log" ||
  fail "routing archiver reported the wrong replacement failure"
grep -qx "replacement must survive" "$REPLACED_ROLLBACK_ARCHIVE/replacement.txt" ||
  fail "routing rollback removed a replacement archive directory"
[[ -f "$REPLACED_ROLLBACK_MOVED/archive-manifest.txt" ]] ||
  fail "routing replacement fixture lost the originally published archive"
pass "routing archiver rollback preserves a concurrently replaced target"

ROUTING_CANDIDATE_FIXTURE="$(copy_fixture routing-archive-candidate)"
mv "$ROUTING_CANDIDATE_FIXTURE/scripts/validate-evidence.rb" \
  "$ROUTING_CANDIDATE_FIXTURE/scripts/validate-evidence.real.rb"
printf '%s\n' \
  '#!/usr/bin/env ruby' \
  'require "rbconfig"' \
  'if ARGV.include?("--candidate")' \
  '  warn "injected candidate validation failure"' \
  '  exit 1' \
  'end' \
  'exec RbConfig.ruby, File.expand_path("validate-evidence.real.rb", __dir__), *ARGV' \
  > "$ROUTING_CANDIDATE_FIXTURE/scripts/validate-evidence.rb"
chmod +x "$ROUTING_CANDIDATE_FIXTURE/scripts/validate-evidence.rb"
if "$ROUTING_CANDIDATE_FIXTURE/scripts/archive-codex-routing-run.rb" \
  --run-dir "$ROUTING_FAKE_PASS" \
  --archive 2026-08-01-invalid-candidate-routing \
  --phase candidate > "$TEST_ROOT/routing-archive-candidate.log" 2>&1; then
  fail "routing archiver published a candidate that failed pre-rename validation"
fi
grep -q "injected candidate validation failure" "$TEST_ROOT/routing-archive-candidate.log" ||
  fail "routing archiver reported the wrong candidate-validation failure"
[[ ! -e "$ROUTING_CANDIDATE_FIXTURE/evals/runs/2026-08-01-invalid-candidate-routing" ]] ||
  fail "routing archiver exposed a candidate that failed pre-rename validation"
candidate_temps="$(find "$ROUTING_CANDIDATE_FIXTURE/evals/runs" -maxdepth 1 -name '.zstack-routing-archive-*' -print | wc -l | tr -d ' ')"
[[ "$candidate_temps" -eq 0 ]] || fail "routing archiver left a rejected candidate directory"
pass "routing archiver validates complete candidates before rename"

ROUTING_MANIFEST_DRIFT_FIXTURE="$(copy_fixture routing-archive-manifest-drift)"
mv "$ROUTING_MANIFEST_DRIFT_FIXTURE/scripts/validate-evidence.rb" \
  "$ROUTING_MANIFEST_DRIFT_FIXTURE/scripts/validate-evidence.real.rb"
printf '%s\n' \
  '#!/usr/bin/env ruby' \
  'require "rbconfig"' \
  'real = File.expand_path("validate-evidence.real.rb", __dir__)' \
  'if ARGV.include?("--candidate")' \
  '  success = system(RbConfig.ruby, real, *ARGV)' \
  '  exit($?.exitstatus || 1) unless success' \
  '  File.open(File.expand_path("../evals/routing.yaml", __dir__), "a") { |file| file.write("\n# injected concurrent routing change\n") }' \
  '  exit 0' \
  'end' \
  'exec RbConfig.ruby, real, *ARGV' \
  > "$ROUTING_MANIFEST_DRIFT_FIXTURE/scripts/validate-evidence.rb"
chmod +x "$ROUTING_MANIFEST_DRIFT_FIXTURE/scripts/validate-evidence.rb"
if "$ROUTING_MANIFEST_DRIFT_FIXTURE/scripts/archive-codex-routing-run.rb" \
  --run-dir "$ROUTING_FAKE_PASS" \
  --archive 2026-08-01-routing-manifest-drift \
  --phase drift > "$TEST_ROOT/routing-archive-manifest-drift.log" 2>&1; then
  fail "routing archiver accepted a manifest change during candidate validation"
fi
grep -q "evals/routing.yaml changed while archive was being prepared" \
  "$TEST_ROOT/routing-archive-manifest-drift.log" ||
  fail "routing archiver reported the wrong concurrent manifest failure"
[[ ! -e "$ROUTING_MANIFEST_DRIFT_FIXTURE/evals/runs/2026-08-01-routing-manifest-drift" ]] ||
  fail "routing archiver published evidence against a changed routing manifest"
manifest_drift_temps="$(find "$ROUTING_MANIFEST_DRIFT_FIXTURE/evals/runs" -maxdepth 1 -name '.zstack-routing-archive-*' -print | wc -l | tr -d ' ')"
[[ "$manifest_drift_temps" -eq 0 ]] || fail "routing archiver left a manifest-drift transaction directory"
pass "routing archiver binds publication to one routing manifest version"

ROUTING_CRASH_FIXTURE="$(copy_fixture routing-archive-crash-window)"
mv "$ROUTING_CRASH_FIXTURE/scripts/validate-evidence.rb" \
  "$ROUTING_CRASH_FIXTURE/scripts/validate-evidence.real.rb"
printf '%s\n' \
  '#!/usr/bin/env ruby' \
  'require "rbconfig"' \
  'counter = ENV.fetch("ZSTACK_CRASH_VALIDATION_COUNTER")' \
  'count = File.exist?(counter) ? File.read(counter).to_i : 0' \
  'count += 1' \
  'File.write(counter, "#{count}\n")' \
  'if count == 3' \
  '  File.write(ENV.fetch("ZSTACK_CRASH_MARKER"), "post-rename\n")' \
  '  Process.kill("KILL", Process.ppid)' \
  '  sleep 0.2' \
  '  exit 1' \
  'end' \
  'exec RbConfig.ruby, File.expand_path("validate-evidence.real.rb", __dir__), *ARGV' \
  > "$ROUTING_CRASH_FIXTURE/scripts/validate-evidence.rb"
chmod +x "$ROUTING_CRASH_FIXTURE/scripts/validate-evidence.rb"
CRASH_COUNTER="$TEST_ROOT/crash-validation-counter"
CRASH_MARKER="$TEST_ROOT/crash-after-rename"
CRASH_TMP="$TEST_ROOT/crash-tmp"
mkdir -p "$CRASH_TMP"
TMPDIR="$CRASH_TMP" \
  ZSTACK_CRASH_VALIDATION_COUNTER="$CRASH_COUNTER" \
  ZSTACK_CRASH_MARKER="$CRASH_MARKER" \
  "$ROUTING_CRASH_FIXTURE/scripts/archive-codex-routing-run.rb" \
  --run-dir "$ROUTING_FAKE_PASS" \
  --archive 2026-08-01-crash-safe-routing \
  --phase crash-safe > "$TEST_ROOT/routing-archive-crash-window.log" 2>&1 &
CRASH_ARCHIVER_PID=$!
if wait "$CRASH_ARCHIVER_PID" 2>/dev/null; then
  fail "routing crash-window fixture did not terminate its publisher"
fi
sleep 0.3
[[ -f "$CRASH_MARKER" && "$(cat "$CRASH_COUNTER")" -eq 3 ]] ||
  fail "routing crash-window fixture did not terminate after rename"
CRASH_SAFE_ARCHIVE="$ROUTING_CRASH_FIXTURE/evals/runs/2026-08-01-crash-safe-routing"
[[ -d "$CRASH_SAFE_ARCHIVE" ]] || fail "post-rename termination lost the validated archive"
ruby "$ROUTING_CRASH_FIXTURE/scripts/validate-evidence.real.rb" >/dev/null ||
  fail "post-rename termination left an invalid archive"
crash_temps="$(find "$ROUTING_CRASH_FIXTURE/evals/runs" -maxdepth 1 -name '.zstack-routing-archive-*' -print | wc -l | tr -d ' ')"
[[ "$crash_temps" -eq 0 ]] || fail "post-rename termination left a repository transaction directory"
pass "post-rename forced termination can leave only a prevalidated archive"

ROUTING_CONCURRENT_FIXTURE="$(copy_fixture routing-archive-concurrent)"
mv "$ROUTING_CONCURRENT_FIXTURE/scripts/validate-evidence.rb" \
  "$ROUTING_CONCURRENT_FIXTURE/scripts/validate-evidence.real.rb"
printf '%s\n' \
  '#!/usr/bin/env ruby' \
  'require "rbconfig"' \
  'marker = ENV["ZSTACK_ARCHIVE_LOCK_MARKER"]' \
  'if marker' \
  '  begin' \
  '    File.open(marker, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |file| file.write("locked\n") }' \
  '    sleep 2' \
  '  rescue Errno::EEXIST' \
  '  end' \
  'end' \
  'exec RbConfig.ruby, File.expand_path("validate-evidence.real.rb", __dir__), *ARGV' \
  > "$ROUTING_CONCURRENT_FIXTURE/scripts/validate-evidence.rb"
chmod +x "$ROUTING_CONCURRENT_FIXTURE/scripts/validate-evidence.rb"
ARCHIVE_LOCK_MARKER="$TEST_ROOT/archive-lock-held"
ZSTACK_ARCHIVE_LOCK_MARKER="$ARCHIVE_LOCK_MARKER" \
  "$ROUTING_CONCURRENT_FIXTURE/scripts/archive-codex-routing-run.rb" \
  --run-dir "$ROUTING_FAKE_PASS" \
  --archive 2026-08-01-concurrent-routing \
  --phase concurrent > "$TEST_ROOT/routing-archive-concurrent-first.log" 2>&1 &
FIRST_ARCHIVER_PID=$!
archive_lock_wait=0
while [[ ! -f "$ARCHIVE_LOCK_MARKER" && "$archive_lock_wait" -lt 50 ]]; do
  sleep 0.1
  archive_lock_wait=$((archive_lock_wait + 1))
done
[[ -f "$ARCHIVE_LOCK_MARKER" ]] || fail "first routing archiver did not acquire its publication lock"
if ZSTACK_ARCHIVE_LOCK_MARKER="$ARCHIVE_LOCK_MARKER" \
  "$ROUTING_CONCURRENT_FIXTURE/scripts/archive-codex-routing-run.rb" \
  --run-dir "$ROUTING_FAKE_PASS" \
  --archive 2026-08-01-concurrent-routing \
  --phase concurrent > "$TEST_ROOT/routing-archive-concurrent-second.log" 2>&1; then
  fail "routing archiver accepted a concurrent publication"
fi
grep -q "another evaluation archive publication is in progress" \
  "$TEST_ROOT/routing-archive-concurrent-second.log" ||
  fail "routing archiver reported the wrong publication-lock failure"
if ! wait "$FIRST_ARCHIVER_PID"; then
  fail "first routing archiver failed after the contending publication exited"
fi
[[ -f "$ROUTING_CONCURRENT_FIXTURE/evals/runs/2026-08-01-concurrent-routing/archive-manifest.txt" ]] ||
  fail "serialized routing publication did not produce one complete archive"
concurrent_archive_count="$(find "$ROUTING_CONCURRENT_FIXTURE/evals/runs" -maxdepth 1 -type d -name '2026-08-01-concurrent-routing' | wc -l | tr -d ' ')"
[[ "$concurrent_archive_count" -eq 1 ]] || fail "concurrent routing publication produced duplicate targets"
pass "routing archiver serializes concurrent publication before target creation"

ROUTING_FAKE_FAIL="$TEST_ROOT/routing-runner-fail"
if FAKE_CODEX_SELECTION=none "$ROOT/scripts/run-codex-routing-evals.rb" \
  --codex "$FAKE_CODEX" \
  --case zh-market-public \
  --output "$ROUTING_FAKE_FAIL" > "$TEST_ROOT/routing-runner-fail.log" 2>&1; then
  fail "routing runner accepted a wrong selection"
fi
ruby -rjson -e '
  result = JSON.parse(File.read(ARGV.fetch(0))).fetch(0)
  abort "wrong selection was not retained as a failed grade" unless result["selected"] == "none" && !result["pass"]
' "$ROUTING_FAKE_FAIL/results.json"

ROUTING_UNSAFE_RESPONSE_TARGET="$TEST_ROOT/routing-unsafe-response-target.txt"
printf '%s\n' 'selection: z-market-validate' 'reason: must not be followed' > "$ROUTING_UNSAFE_RESPONSE_TARGET"
ROUTING_LINKED_RESPONSE="$TEST_ROOT/routing-runner-linked-response"
if FAKE_CODEX_RESPONSE_SYMLINK_TARGET="$ROUTING_UNSAFE_RESPONSE_TARGET" \
  "$ROOT/scripts/run-codex-routing-evals.rb" \
  --codex "$FAKE_CODEX" \
  --auth-path "$FAKE_CODEX_AUTH" \
  --case zh-market-public \
  --output "$ROUTING_LINKED_RESPONSE" > "$TEST_ROOT/routing-runner-linked-response.log" 2>&1; then
  fail "routing runner followed a host-created response symlink"
fi
ruby -rjson -e '
  result = JSON.parse(File.read(ARGV.fetch(0))).fetch(0)
  abort "linked response was not rejected" unless !result.fetch("pass") && result.fetch("responseFileError").include?("regular non-link")
' "$ROUTING_LINKED_RESPONSE/results.json"
grep -qx 'reason: must not be followed' "$ROUTING_UNSAFE_RESPONSE_TARGET" || fail "routing runner changed a response symlink target"

ROUTING_FIFO_RESPONSE="$TEST_ROOT/routing-runner-fifo-response"
if FAKE_CODEX_RESPONSE_FIFO=1 "$ROOT/scripts/run-codex-routing-evals.rb" \
  --codex "$FAKE_CODEX" \
  --auth-path "$FAKE_CODEX_AUTH" \
  --case zh-market-public \
  --output "$ROUTING_FIFO_RESPONSE" > "$TEST_ROOT/routing-runner-fifo-response.log" 2>&1; then
  fail "routing runner accepted a host-created response FIFO"
fi
ruby -rjson -e '
  result = JSON.parse(File.read(ARGV.fetch(0))).fetch(0)
  abort "FIFO response was not rejected" unless !result.fetch("pass") && result.fetch("responseFileError").include?("regular non-link")
' "$ROUTING_FIFO_RESPONSE/results.json"
pass "routing runner rejects host-created response symlinks and FIFOs without following or blocking"

ROUTING_NONEMPTY="$TEST_ROOT/routing-runner-nonempty"
mkdir -p "$ROUTING_NONEMPTY"
printf '%s\n' "keep me" > "$ROUTING_NONEMPTY/owner.txt"
if "$ROOT/scripts/run-codex-routing-evals.rb" --dry-run --case none-code-fix --output "$ROUTING_NONEMPTY" > "$TEST_ROOT/routing-runner-nonempty.log" 2>&1; then
  fail "routing runner reused a non-empty output directory"
fi
grep -q "output directory must be empty" "$TEST_ROOT/routing-runner-nonempty.log" || fail "routing runner reported the wrong output-reuse failure"
ROUTING_NONPRIVATE="$TEST_ROOT/routing-runner-nonprivate"
mkdir -p "$ROUTING_NONPRIVATE"
chmod 755 "$ROUTING_NONPRIVATE"
if "$ROOT/scripts/run-codex-routing-evals.rb" --dry-run --case none-code-fix --output "$ROUTING_NONPRIVATE" > "$TEST_ROOT/routing-runner-nonprivate.log" 2>&1; then
  fail "routing runner accepted a non-private output directory"
fi
grep -q "output directory must be owner-private" "$TEST_ROOT/routing-runner-nonprivate.log" ||
  fail "routing runner reported the wrong output-privacy failure"
[[ -d "$ROUTING_NONPRIVATE" && "$(zstack_file_mode_bits "$ROUTING_NONPRIVATE")" == "755" ]] ||
  fail "routing runner changed a rejected output directory"
if "$ROOT/scripts/run-codex-routing-evals.rb" --dry-run --case missing-case > "$TEST_ROOT/routing-runner-missing.log" 2>&1; then
  fail "routing runner accepted an unknown case selector"
fi
grep -q "unknown routing case" "$TEST_ROOT/routing-runner-missing.log" || fail "routing runner reported the wrong unknown-case failure"
pass "routing runner fails closed on wrong selections and unsafe output reuse"

FAKE_ROUTING_CLAUDE="$TEST_ROOT/fake-routing-claude"
printf '%s\n' \
  '#!/usr/bin/env ruby' \
  'require "json"' \
  'if ARGV.first == "--version"' \
  '  puts "2.1.999 (Claude Code)"' \
  '  exit 0' \
  'end' \
  'exit 64 unless ARGV.first == "-p"' \
  'tools_index = ARGV.index("--tools")' \
  'exit 65 unless tools_index && ARGV.fetch(tools_index + 1) == ""' \
  'prompt = STDIN.read' \
  'selection = prompt.include?("自动整理会议纪要并生成发票草稿") ? "z-market-validate" : "none"' \
  'api_error = ENV.fetch("FAKE_CLAUDE_ROUTING_API_ERROR", "0") == "1"' \
  'answer = "selection: #{selection}\nreason: fake Claude routing reason"' \
  'data = {' \
  '  "type" => "result", "subtype" => "success", "is_error" => api_error,' \
  '  "result" => api_error ? "There is an issue with the selected model (private-routing-model)." : answer,' \
  '  "api_error_status" => api_error ? 404 : nil,' \
  '  "modelUsage" => api_error ? {} : { "claude-fake-routing-1" => { "costUSD" => 0.001 } },' \
  '  "num_turns" => 1, "stop_reason" => api_error ? "stop_sequence" : "end_turn",' \
  '  "terminal_reason" => "completed", "total_cost_usd" => api_error ? 0 : 0.001,' \
  '  "permission_denials" => [], "session_id" => "private-routing-session"' \
  '}' \
  'puts JSON.generate(data)' > "$FAKE_ROUTING_CLAUDE"
chmod +x "$FAKE_ROUTING_CLAUDE"

CLAUDE_ROUTING_FAKE_PASS="$TEST_ROOT/claude-routing-runner-pass"
"$ROOT/scripts/run-claude-routing-evals.rb" \
  --claude "$FAKE_ROUTING_CLAUDE" \
  --model claude-requested-routing-alias \
  --case zh-market-public \
  --case zh-none-code-fix \
  --output "$CLAUDE_ROUTING_FAKE_PASS" > "$TEST_ROOT/claude-routing-runner-pass.log"
ruby -rjson -e '
  controls = JSON.parse(File.read(ARGV.fetch(0)))
  results = JSON.parse(File.read(ARGV.fetch(1)))
  invocation = JSON.parse(File.read(ARGV.fetch(2)))
  abort "Claude routing controls are not isolated" unless controls.fetch("host") == "Claude Code" && controls.fetch("safeMode") && controls.fetch("allowedTools") == []
  abort "Claude routing results lost actual-model provenance" unless results.all? { |result| result.fetch("pass") && result.fetch("actualModels") == ["claude-fake-routing-1"] }
  args = invocation.fetch("arguments")
  tools_index = args.index("--tools")
  abort "Claude routing invocation did not disable tools" unless tools_index && args.fetch(tools_index + 1) == ""
' "$CLAUDE_ROUTING_FAKE_PASS/controls.json" "$CLAUDE_ROUTING_FAKE_PASS/results.json" "$CLAUDE_ROUTING_FAKE_PASS/logs/zh-market-public.invocation.json"

CLAUDE_ROUTING_ARCHIVE_FIXTURE="$(copy_fixture claude-routing-archive)"
"$CLAUDE_ROUTING_ARCHIVE_FIXTURE/scripts/archive-claude-routing-run.rb" \
  --run-dir "$CLAUDE_ROUTING_FAKE_PASS" \
  --archive 2026-08-01-fake-claude-routing \
  --phase fake-claude-routing > "$TEST_ROOT/claude-routing-archive.log"
CLAUDE_ROUTING_ARCHIVE="$CLAUDE_ROUTING_ARCHIVE_FIXTURE/evals/runs/2026-08-01-fake-claude-routing"
ruby -rjson -e '
  run = JSON.parse(File.read(ARGV.fetch(0)))
  abort "Claude routing archive recorded the wrong host" unless run.dig("host", "name") == "Claude Code"
  abort "Claude routing archive lost actual model provenance" unless run.fetch("runs").all? { |entry| entry.fetch("model") == "claude-fake-routing-1" }
' "$CLAUDE_ROUTING_ARCHIVE/run.json"
if find "$CLAUDE_ROUTING_ARCHIVE" -type f \( -name '*.invocation.json' -o -path '*/logs/*' \) | grep -q .; then
  fail "Claude routing archiver copied private host records"
fi
ruby "$CLAUDE_ROUTING_ARCHIVE_FIXTURE/scripts/validate-evidence.rb" >/dev/null

CLAUDE_ROUTING_PROVENANCE_TAMPERED="$TEST_ROOT/claude-routing-provenance-tampered"
cp -R "$CLAUDE_ROUTING_FAKE_PASS" "$CLAUDE_ROUTING_PROVENANCE_TAMPERED"
ruby -rjson -e '
  path = ARGV.fetch(0)
  results = JSON.parse(File.read(path))
  results.fetch(0).delete("isError")
  File.write(path, JSON.pretty_generate(results) + "\n")
' "$CLAUDE_ROUTING_PROVENANCE_TAMPERED/results.json"
if "$CLAUDE_ROUTING_ARCHIVE_FIXTURE/scripts/archive-claude-routing-run.rb" \
  --run-dir "$CLAUDE_ROUTING_PROVENANCE_TAMPERED" \
  --archive 2026-08-01-tampered-claude-routing-provenance \
  --phase tampered > "$TEST_ROOT/claude-routing-provenance-tampered.log" 2>&1; then
  fail "Claude routing archiver accepted missing host provenance"
fi
grep -q "structured-host result is missing required fields: isError" \
  "$TEST_ROOT/claude-routing-provenance-tampered.log" ||
  fail "Claude routing archiver reported the wrong missing-provenance failure"

CLAUDE_ROUTING_API_ERROR="$TEST_ROOT/claude-routing-api-error"
if FAKE_CLAUDE_ROUTING_API_ERROR=1 "$ROOT/scripts/run-claude-routing-evals.rb" \
  --claude "$FAKE_ROUTING_CLAUDE" \
  --case zh-market-public \
  --output "$CLAUDE_ROUTING_API_ERROR" > "$TEST_ROOT/claude-routing-api-error.log" 2>&1; then
  fail "Claude routing runner accepted an API error"
fi
ruby -rjson -e '
  result = JSON.parse(File.read(ARGV.fetch(0))).fetch(0)
  abort "Claude routing API error was marked complete" if result.fetch("executionCompleted")
  abort "Claude routing API error was not safely classified" unless result.fetch("apiErrorStatus") == 404 && result.fetch("errorCategory") == "model-unavailable"
  abort "Claude routing API error was exposed as a routing response" if File.exist?(ARGV.fetch(1))
' "$CLAUDE_ROUTING_API_ERROR/results.json" "$CLAUDE_ROUTING_API_ERROR/responses/zh-market-public.txt"
grep -q 'FAIL (model-unavailable; HTTP 404)' "$TEST_ROOT/claude-routing-api-error.log" || fail "Claude routing runner omitted its safe API diagnosis"
if grep -q 'private-routing-model' "$TEST_ROOT/claude-routing-api-error.log"; then
  fail "Claude routing runner leaked provider error text"
fi
pass "Claude routing adapter disables tools, preserves provenance, and fails closed"

FAKE_ROUTING_GROK="$TEST_ROOT/fake-routing-grok"
printf '%s\n' \
  '#!/usr/bin/env ruby' \
  'require "json"' \
  'if ARGV.first == "--version"' \
  '  puts "grok 0.2.999 (fakerouting)"' \
  '  exit 0' \
  'end' \
  'prompt_path = ARGV.fetch(ARGV.index("--prompt-file") + 1)' \
  'workspace = ARGV.fetch(ARGV.index("--cwd") + 1)' \
  'tools_index = ARGV.index("--tools")' \
  'exit 64 unless tools_index && ARGV.fetch(tools_index + 1) == ""' \
  'exit 65 unless ENV.fetch("GROK_HOME").include?(".grok-homes") && File.directory?(workspace)' \
  'exit 66 unless prompt_path == "/dev/fd/9" && File.stat(prompt_path).nlink == 0' \
  'prompt = File.read(prompt_path)' \
  'selection = prompt.include?("自动整理会议纪要并生成发票草稿") ? "z-market-validate" : "none"' \
  'answer = "selection: #{selection}\nreason: fake Grok routing reason"' \
  'text = ENV.fetch("FAKE_GROK_MISSING_MARKER", "0") == "1" ? answer : "private routing setup narration\nZSTACK_FINAL_RESPONSE_V1\n#{answer}"' \
  'data = {' \
  '  "type" => "result", "text" => text,' \
  '  "num_turns" => 1, "stopReason" => "end_turn", "total_cost_usd" => 0.001,' \
  '  "usage" => { "input_tokens" => 100, "output_tokens" => 20 },' \
  '  "modelUsage" => { "grok-fake-routing-1" => { "costUSD" => 0.001 } }' \
  '}' \
  'puts JSON.generate(data)' > "$FAKE_ROUTING_GROK"
chmod +x "$FAKE_ROUTING_GROK"

GROK_ROUTING_FAKE_PASS="$TEST_ROOT/grok-routing-runner-pass"
"$ROOT/scripts/run-grok-routing-evals.rb" \
  --grok "$FAKE_ROUTING_GROK" \
  --auth-path "$TEST_ROOT/fake-grok-routing-auth.json" \
  --model grok-requested-routing-alias \
  --case zh-market-public \
  --case zh-none-code-fix \
  --output "$GROK_ROUTING_FAKE_PASS" > "$TEST_ROOT/grok-routing-runner-pass.log"
ruby -rjson -e '
  controls = JSON.parse(File.read(ARGV.fetch(0)))
  results = JSON.parse(File.read(ARGV.fetch(1)))
  invocation = JSON.parse(File.read(ARGV.fetch(2)))
  abort "Grok routing controls are not isolated" unless controls.fetch("host") == "Grok Build" && controls.fetch("isolatedHostHome") && controls.fetch("allowedTools") == []
  abort "Grok routing runner omitted private prompt monitoring" unless controls.fetch("pidMonitoringStartsAtSpawn") == true && controls.fetch("sharedRootMonitoring") == true && controls.fetch("privatePromptIntegrityMonitoring") == true && controls.fetch("anonymousPromptDescriptor") == true && controls.fetch("promptDescriptorPath") == "/dev/fd/9"
  abort "Grok routing runner omitted output identity monitoring" unless controls.fetch("outputDirectoryIdentityMonitoring") == true
  abort "Grok routing results lost final-boundary provenance" unless results.all? { |result| result.fetch("pass") && result.fetch("actualModels") == ["grok-fake-routing-1"] && result.fetch("prefinalNarrationBytes").positive? && result.fetch("finalBoundaryError").nil? }
  args = invocation.fetch("arguments")
  tools_index = args.index("--tools")
  abort "Grok routing invocation did not disable tools" unless tools_index && args.fetch(tools_index + 1) == ""
  token = invocation.fetch("privateCaseToken")
  abort "Grok routing private token is malformed" unless token.match?(/\Acase-[0-9a-f]{32}\z/)
  abort "Grok routing workspace leaked its semantic case id" unless File.basename(invocation.fetch("workspace")) == token && !invocation.fetch("workspace").include?("zh-market-public")
  prompt_index = args.index("--prompt-file")
  private_prompt = args.fetch(prompt_index + 1)
  abort "Grok routing prompt did not use its inherited anonymous descriptor" unless private_prompt == "/dev/fd/9"
  marker = controls.fetch("finalResponseBoundary")
  environment = invocation.fetch("environment")
  grok_home = environment.fetch("GROK_HOME")
  grok_auth = environment.fetch("GROK_AUTH_PATH")
  abort "Grok routing auth escaped its isolated home" unless File.dirname(grok_auth) == grok_home && File.basename(grok_auth) == "auth.json"
  abort "Grok routing final-response marker changed" unless marker == "ZSTACK_FINAL_RESPONSE_V1" && controls.fetch("systemPromptOverride").include?(marker)
  response = File.read(File.join(ARGV.fetch(3), "responses/zh-market-public.txt"))
  abort "Grok routing response retained private narration or marker" if response.include?("private routing setup narration") || response.include?(marker)
' "$GROK_ROUTING_FAKE_PASS/controls.json" "$GROK_ROUTING_FAKE_PASS/results.json" "$GROK_ROUTING_FAKE_PASS/logs/zh-market-public.invocation.json" "$GROK_ROUTING_FAKE_PASS"

GROK_ROUTING_ARCHIVE_FIXTURE="$(copy_fixture grok-routing-archive)"
"$GROK_ROUTING_ARCHIVE_FIXTURE/scripts/archive-grok-routing-run.rb" \
  --run-dir "$GROK_ROUTING_FAKE_PASS" \
  --archive 2026-08-01-fake-grok-routing \
  --phase fake-grok-routing > "$TEST_ROOT/grok-routing-archive.log"
GROK_ROUTING_ARCHIVE="$GROK_ROUTING_ARCHIVE_FIXTURE/evals/runs/2026-08-01-fake-grok-routing"
ruby -rjson -e '
  run = JSON.parse(File.read(ARGV.fetch(0)))
  abort "Grok routing archive recorded the wrong host" unless run.dig("host", "name") == "Grok Build"
  abort "Grok routing archive lost actual model provenance" unless run.fetch("runs").all? { |entry| entry.fetch("model") == "grok-fake-routing-1" && entry.fetch("turns") == 1 }
  abort "Grok routing archive omitted discarded narration incidents" unless run.fetch("runnerIncidents").all? { |entry| entry.include?("discarded") && entry.include?("pre-final narration bytes") }
' "$GROK_ROUTING_ARCHIVE/run.json"
if find "$GROK_ROUTING_ARCHIVE" -type f \( -name '*.invocation.json' -o -path '*/logs/*' \) | grep -q .; then
  fail "Grok routing archiver copied private host records"
fi
ruby "$GROK_ROUTING_ARCHIVE_FIXTURE/scripts/validate-evidence.rb" >/dev/null
GROK_ROUTING_BOUNDARY_TAMPERED="$TEST_ROOT/grok-routing-boundary-tampered"
cp -R "$GROK_ROUTING_FAKE_PASS" "$GROK_ROUTING_BOUNDARY_TAMPERED"
ruby -rjson -e '
  run_directory = ARGV.fetch(0)
  path = File.join(run_directory, "logs/zh-market-public.json")
  raw = JSON.parse(File.read(path))
  raw["text"] = raw.fetch("text").sub("ZSTACK_FINAL_RESPONSE_V1\n", "")
  File.write(path, JSON.pretty_generate(raw) + "\n")
  results_path = File.join(run_directory, "results.json")
  results = JSON.parse(File.read(results_path))
  result = results.find { |entry| entry.fetch("id") == "zh-market-public" }
  result["hostOutputBytes"] = File.size(path) + File.size(File.join(run_directory, "logs/zh-market-public.log"))
  File.write(results_path, JSON.pretty_generate(results) + "\n")
' "$GROK_ROUTING_BOUNDARY_TAMPERED"
if "$GROK_ROUTING_ARCHIVE_FIXTURE/scripts/archive-grok-routing-run.rb" \
  --run-dir "$GROK_ROUTING_BOUNDARY_TAMPERED" \
  --archive 2026-08-01-tampered-grok-routing-boundary \
  --phase tampered > "$TEST_ROOT/grok-routing-boundary-tampered.log" 2>&1; then
  fail "Grok routing archiver accepted a raw result without its final-response marker"
fi
grep -q "must contain exactly one final-response marker" "$TEST_ROOT/grok-routing-boundary-tampered.log" || fail "Grok routing archiver reported the wrong final-boundary tamper failure"
pass "Grok routing adapter isolates host state and archives corroborated provenance"

BEHAVIOR_COVERAGE_JSON="$TEST_ROOT/behavior-coverage.json"
"$ROOT/scripts/report-evidence-coverage.rb" --json > "$BEHAVIOR_COVERAGE_JSON"
ruby -rjson -e '
  report = JSON.parse(File.read(ARGV.fetch(0)))
  summary = report.fetch("summary")
  cases = report.fetch("cases")
  abort "coverage report omitted current behavioral cases" unless summary.fetch("cases") == cases.length && cases.length == 20
  abort "coverage report lost archived passes" unless summary.fetch("passingCases") == cases.count { |entry| entry.fetch("hasPass") }
  abort "coverage report complete-pass count is inconsistent" unless summary.fetch("completePassingCases") == cases.count { |entry| entry.fetch("hasCompletePass") }
  abort "coverage report current-pass count is inconsistent" unless summary.fetch("currentCompletePassingCases") == cases.count { |entry| entry.fetch("hasCurrentCompletePass") }
  expected_missing = cases.reject { |entry| entry.fetch("hasCompletePass") }.map { |entry| entry.fetch("id") }
  abort "coverage report missing-case list is inconsistent" unless summary.fetch("missingCompletePass") == expected_missing
  expected_current_missing = cases.reject { |entry| entry.fetch("hasCurrentCompletePass") }.map { |entry| entry.fetch("id") }
  abort "coverage report current missing-case list is inconsistent" unless summary.fetch("missingCurrentCompletePass") == expected_current_missing
  abort "coverage report skill totals are inconsistent" unless report.fetch("skills").sum { |entry| entry.fetch("cases") } == cases.length
  report.fetch("skills").each do |skill|
    skill_cases = cases.select { |entry| entry.fetch("skill") == skill.fetch("skill") }
    expected_hosts = skill_cases.map { |entry| entry.fetch("completePassHostFamilies") }.reduce { |common, families| common & families }.sort
    abort "behavioral skill host coverage uses anything other than a full-case intersection" unless skill.fetch("completePassHostFamilies") == expected_hosts
    expected_current_hosts = skill_cases.map { |entry| entry.fetch("currentCompletePassHostFamilies") }.reduce { |common, families| common & families }.sort
    abort "behavioral current-source host coverage uses anything other than a full-case intersection" unless skill.fetch("currentCompletePassHostFamilies") == expected_current_hosts
  end
  hosts = report.fetch("hosts")
  abort "coverage report omitted supported host families" unless %w[claude codex grok].all? { |family| hosts.any? { |entry| entry.fetch("hostFamily") == family } }
  abort "coverage report host totals are invalid" unless hosts.all? { |entry| entry.fetch("passingCases").between?(0, cases.length) && entry.fetch("completePassingCases").between?(0, cases.length) && entry.fetch("currentCompletePassingCases").between?(0, cases.length) }
' "$BEHAVIOR_COVERAGE_JSON"
"$ROOT/scripts/report-evidence-coverage.rb" --require-complete-pass >/dev/null

BEHAVIOR_REVIEW_CONSISTENCY_FIXTURE="$(copy_fixture behavior-review-consistency)"
mkdir -p "$BEHAVIOR_REVIEW_CONSISTENCY_FIXTURE/evals/runs"
cp -R "$ROOT/evals/runs/2026-08-02-codex-discovery-progressive-disclosure" \
  "$BEHAVIOR_REVIEW_CONSISTENCY_FIXTURE/evals/runs/2026-08-02-codex-discovery-progressive-disclosure"
ruby -rjson -e '
  path = ARGV.fetch(0)
  data = JSON.parse(File.read(path))
  review = data.fetch("cases").find { |entry| entry.fetch("id") == "discovery-fake-interviews" }
  review.fetch("criteria").fetch(1)["observed"] = false
  File.write(path, JSON.generate(data))
' "$BEHAVIOR_REVIEW_CONSISTENCY_FIXTURE/evals/runs/2026-08-02-codex-discovery-progressive-disclosure/runner-review.json"
ruby "$BEHAVIOR_REVIEW_CONSISTENCY_FIXTURE/scripts/generate-evidence-manifests.rb" \
  "$BEHAVIOR_REVIEW_CONSISTENCY_FIXTURE/evals/runs/2026-08-02-codex-discovery-progressive-disclosure" >/dev/null
"$BEHAVIOR_REVIEW_CONSISTENCY_FIXTURE/scripts/report-evidence-coverage.rb" --json \
  > "$TEST_ROOT/behavior-review-consistency.json"
ruby -rjson -e '
  report = JSON.parse(File.read(ARGV.fetch(0)))
  target = report.fetch("cases").find { |entry| entry.fetch("id") == "discovery-fake-interviews" }
  abort "failed review criterion still counted as a current pass" if target.fetch("hasCurrentCompletePass")
' "$TEST_ROOT/behavior-review-consistency.json"
cp "$ROOT/evals/runs/2026-08-02-codex-discovery-progressive-disclosure/runner-review.json" \
  "$BEHAVIOR_REVIEW_CONSISTENCY_FIXTURE/evals/runs/2026-08-02-codex-discovery-progressive-disclosure/runner-review.json"
ruby -e '
  path = ARGV.fetch(0)
  content = File.read(path)
  replacement = content.sub(%q{"grade": "pass"}, %q{"grade": "fail", "grade": "pass"})
  abort "duplicate review fixture did not change" if replacement == content
  File.write(path, replacement)
' "$BEHAVIOR_REVIEW_CONSISTENCY_FIXTURE/evals/runs/2026-08-02-codex-discovery-progressive-disclosure/runner-review.json"
ruby "$BEHAVIOR_REVIEW_CONSISTENCY_FIXTURE/scripts/generate-evidence-manifests.rb" \
  "$BEHAVIOR_REVIEW_CONSISTENCY_FIXTURE/evals/runs/2026-08-02-codex-discovery-progressive-disclosure" >/dev/null
"$BEHAVIOR_REVIEW_CONSISTENCY_FIXTURE/scripts/report-evidence-coverage.rb" --json \
  > "$TEST_ROOT/behavior-duplicate-review.json"
ruby -rjson -e '
  report = JSON.parse(File.read(ARGV.fetch(0)))
  target = report.fetch("cases").find { |entry| entry.fetch("id") == "discovery-fake-interviews" }
  abort "ambiguous duplicate review still counted as current" if target.fetch("hasCurrentCompletePass")
' "$TEST_ROOT/behavior-duplicate-review.json"
cp "$ROOT/evals/runs/2026-08-02-codex-discovery-progressive-disclosure/runner-review.json" \
  "$BEHAVIOR_REVIEW_CONSISTENCY_FIXTURE/evals/runs/2026-08-02-codex-discovery-progressive-disclosure/runner-review.json"
BEHAVIOR_TAMPERED_PROMPT="$BEHAVIOR_REVIEW_CONSISTENCY_FIXTURE/evals/runs/2026-08-02-codex-discovery-progressive-disclosure/raw/prompts/discovery-fake-interviews.txt"
printf '%s\n' 'Injected instruction outside the canonical wrapper.' > "$BEHAVIOR_TAMPERED_PROMPT.next"
cat "$BEHAVIOR_TAMPERED_PROMPT" >> "$BEHAVIOR_TAMPERED_PROMPT.next"
mv "$BEHAVIOR_TAMPERED_PROMPT.next" "$BEHAVIOR_TAMPERED_PROMPT"
refresh_raw_manifest_entry \
  "$BEHAVIOR_TAMPERED_PROMPT" \
  "$BEHAVIOR_REVIEW_CONSISTENCY_FIXTURE/evals/runs/2026-08-02-codex-discovery-progressive-disclosure/raw/artifact-manifest.txt" \
  "prompts/discovery-fake-interviews.txt"
ruby "$BEHAVIOR_REVIEW_CONSISTENCY_FIXTURE/scripts/generate-evidence-manifests.rb" \
  "$BEHAVIOR_REVIEW_CONSISTENCY_FIXTURE/evals/runs/2026-08-02-codex-discovery-progressive-disclosure" >/dev/null
"$BEHAVIOR_REVIEW_CONSISTENCY_FIXTURE/scripts/report-evidence-coverage.rb" --json \
  > "$TEST_ROOT/behavior-prompt-consistency.json"
ruby -rjson -e '
  report = JSON.parse(File.read(ARGV.fetch(0)))
  target = report.fetch("cases").find { |entry| entry.fetch("id") == "discovery-fake-interviews" }
  abort "non-canonical behavioral prompt still counted as current" if target.fetch("hasCurrentCompletePass")
' "$TEST_ROOT/behavior-prompt-consistency.json"

BEHAVIOR_COVERAGE_NOFOLLOW_FIXTURE="$(copy_fixture behavior-coverage-nofollow)"
mkdir -p "$BEHAVIOR_COVERAGE_NOFOLLOW_FIXTURE/evals/runs"
cp -R "$ROOT/evals/runs/2026-08-02-codex-discovery-progressive-disclosure" \
  "$BEHAVIOR_COVERAGE_NOFOLLOW_FIXTURE/evals/runs/2026-08-02-codex-discovery-progressive-disclosure"
printf '%s\n' '#!/usr/bin/env ruby' 'exit 0' \
  > "$BEHAVIOR_COVERAGE_NOFOLLOW_FIXTURE/scripts/validate-evidence.rb"
chmod +x "$BEHAVIOR_COVERAGE_NOFOLLOW_FIXTURE/scripts/validate-evidence.rb"
NOFOLLOW_REVIEW="$BEHAVIOR_COVERAGE_NOFOLLOW_FIXTURE/evals/runs/2026-08-02-codex-discovery-progressive-disclosure/runner-review.json"
mv "$NOFOLLOW_REVIEW" "$TEST_ROOT/external-runner-review.json"
ln -s "$TEST_ROOT/external-runner-review.json" "$NOFOLLOW_REVIEW"
if "$BEHAVIOR_COVERAGE_NOFOLLOW_FIXTURE/scripts/report-evidence-coverage.rb" --json \
  > "$TEST_ROOT/behavior-coverage-nofollow.log" 2>&1; then
  fail "coverage report accepted a linked evidence file after a no-op validator"
fi
grep -q "evidence tree contains a symbolic link" "$TEST_ROOT/behavior-coverage-nofollow.log" ||
  fail "coverage report returned the wrong linked-tree failure"

BEHAVIOR_COVERAGE_TOCTOU_FIXTURE="$(copy_fixture behavior-coverage-toctou)"
mkdir -p "$BEHAVIOR_COVERAGE_TOCTOU_FIXTURE/evals/runs"
cp -R "$ROOT/evals/runs/2026-08-02-codex-discovery-progressive-disclosure" \
  "$BEHAVIOR_COVERAGE_TOCTOU_FIXTURE/evals/runs/2026-08-02-codex-discovery-progressive-disclosure"
printf '%s\n' \
  '#!/usr/bin/env ruby' \
  'root = File.expand_path("..", __dir__)' \
  'target = File.join(root, "evals/runs/2026-08-02-codex-discovery-progressive-disclosure/after-validation.txt")' \
  'File.write(target, "unvalidated evidence\n")' \
  > "$BEHAVIOR_COVERAGE_TOCTOU_FIXTURE/scripts/validate-evidence.rb"
chmod +x "$BEHAVIOR_COVERAGE_TOCTOU_FIXTURE/scripts/validate-evidence.rb"
if "$BEHAVIOR_COVERAGE_TOCTOU_FIXTURE/scripts/report-evidence-coverage.rb" --json \
  > "$TEST_ROOT/behavior-coverage-toctou.log" 2>&1; then
  fail "coverage report accepted an evidence tree changed by its validator"
fi
grep -q "evidence archive tree changed during validation" "$TEST_ROOT/behavior-coverage-toctou.log" ||
  fail "coverage report returned the wrong validator TOCTOU failure"

BEHAVIOR_COVERAGE_GAP_FIXTURE="$(copy_fixture behavior-coverage-gap)"
if "$BEHAVIOR_COVERAGE_GAP_FIXTURE/scripts/report-evidence-coverage.rb" --require-complete-pass > "$TEST_ROOT/behavior-coverage-gap.log" 2>&1; then
  fail "behavioral coverage strict gate accepted a fixture without run archives"
fi
grep -q "missing-complete=20" "$TEST_ROOT/behavior-coverage-gap.log" || fail "behavioral coverage strict gate reported the wrong fixture gap"
if "$BEHAVIOR_COVERAGE_GAP_FIXTURE/scripts/report-evidence-coverage.rb" --require-complete-pass-host claude > "$TEST_ROOT/behavior-coverage-host-gap.log" 2>&1; then
  fail "behavioral coverage host gate accepted a fixture without Claude archives"
fi
grep -q "host:claude" "$TEST_ROOT/behavior-coverage-host-gap.log" || fail "behavioral coverage host gate omitted the requested family"
if "$BEHAVIOR_COVERAGE_GAP_FIXTURE/scripts/report-evidence-coverage.rb" --require-current-complete-pass > "$TEST_ROOT/behavior-current-coverage-gap.log" 2>&1; then
  fail "behavioral current-source gate accepted a fixture without run archives"
fi
grep -q "missing-current=20" "$TEST_ROOT/behavior-current-coverage-gap.log" || fail "behavioral current-source gate reported the wrong fixture gap"

FORGED_COVERAGE_ARCHIVE="$TEST_ROOT/forged-coverage-archive"
mkdir -p "$FORGED_COVERAGE_ARCHIVE" "$BEHAVIOR_COVERAGE_GAP_FIXTURE/evals/runs"
ruby -rjson -ryaml -e '
  cases = YAML.safe_load(File.read(ARGV.fetch(0)), aliases: false).fetch("cases")
  runs = cases.map do |entry|
    id = entry.fetch("id")
    { "id" => "forged-#{id}", "case" => id, "phase" => "forged", "grade" => "pass" }
  end
  data = {
    "suite" => "behavioral",
    "host" => { "name" => "Codex" },
    "provenance" => { "status" => "complete" },
    "runs" => runs
  }
  File.write(ARGV.fetch(1), JSON.generate(data))
' "$BEHAVIOR_COVERAGE_GAP_FIXTURE/evals/cases.yaml" "$FORGED_COVERAGE_ARCHIVE/run.json"
ln -s "$FORGED_COVERAGE_ARCHIVE" "$BEHAVIOR_COVERAGE_GAP_FIXTURE/evals/runs/2026-01-01-forged"
if "$BEHAVIOR_COVERAGE_GAP_FIXTURE/scripts/report-evidence-coverage.rb" \
  --require-complete-pass > "$TEST_ROOT/behavior-coverage-forged-link.log" 2>&1; then
  fail "behavioral coverage gate trusted a linked, unvalidated run archive"
fi
grep -q "evidence tree contains a symbolic link" "$TEST_ROOT/behavior-coverage-forged-link.log" ||
  fail "behavioral coverage gate reported the wrong forged-archive failure"
rm -f "$BEHAVIOR_COVERAGE_GAP_FIXTURE/evals/runs/2026-01-01-forged"
rm -rf "$FORGED_COVERAGE_ARCHIVE"

if "$ROOT/scripts/report-evidence-coverage.rb" --require-complete-pass-host unknown > "$TEST_ROOT/behavior-coverage-unknown-host.log" 2>&1; then
  fail "behavioral coverage report accepted an unknown host family"
fi
grep -q "unknown host family" "$TEST_ROOT/behavior-coverage-unknown-host.log" || fail "behavioral coverage report returned the wrong unknown-host error"
pass "behavioral coverage report rechecks review outcomes before enforcing current provenance"

ROUTING_COVERAGE_JSON="$TEST_ROOT/routing-coverage.json"
"$ROOT/scripts/report-evidence-coverage.rb" --suite routing --json > "$ROUTING_COVERAGE_JSON"
ruby -rjson -e '
  report = JSON.parse(File.read(ARGV.fetch(0)))
  summary = report.fetch("summary")
  cases = report.fetch("cases")
  targets = report.fetch("targets")
  abort "routing coverage report recorded the wrong suite" unless report.fetch("suite") == "routing"
  abort "routing coverage report omitted current cases" unless summary.fetch("cases") == cases.length && cases.length == 25
  abort "routing coverage report target totals are inconsistent" unless targets.sum { |entry| entry.fetch("cases") } == cases.length
  targets.each do |target|
    target_cases = cases.select { |entry| entry.fetch("expectedSkill") == target.fetch("expectedSkill") }
    expected_hosts = target_cases.map { |entry| entry.fetch("completePassHostFamilies") }.reduce { |common, families| common & families }.sort
    abort "routing target host coverage uses anything other than a full-case intersection" unless target.fetch("completePassHostFamilies") == expected_hosts
    expected_current_hosts = target_cases.map { |entry| entry.fetch("currentCompletePassHostFamilies") }.reduce { |common, families| common & families }.sort
    abort "routing current-source host coverage uses anything other than a full-case intersection" unless target.fetch("currentCompletePassHostFamilies") == expected_current_hosts
  end
  hosts = report.fetch("hosts").to_h { |entry| [entry.fetch("hostFamily"), entry] }
  %w[codex grok].each do |family|
    abort "routing coverage is incomplete for #{family}" unless hosts.fetch(family).fetch("completePassingCases") == cases.length
  end
  abort "current Grok routing coverage is incomplete" unless hosts.fetch("grok").fetch("currentCompletePassingCases") == cases.length
' "$ROUTING_COVERAGE_JSON"
"$ROOT/scripts/report-evidence-coverage.rb" --suite routing \
  --require-complete-pass-host codex \
  --require-complete-pass-host grok >/dev/null
"$ROOT/scripts/report-evidence-coverage.rb" --suite routing \
  --require-current-complete-pass-host grok >/dev/null

ROUTING_CURRENT_CONTRACT_FIXTURE="$(copy_fixture routing-current-contract)"
mkdir -p "$ROUTING_CURRENT_CONTRACT_FIXTURE/evals/runs"
cp -R "$ROOT/evals/runs/2026-08-01-grok-routing-full-matrix" \
  "$ROUTING_CURRENT_CONTRACT_FIXTURE/evals/runs/2026-08-01-grok-routing-full-matrix"
ruby -rjson -e '
  path = ARGV.fetch(0)
  data = JSON.parse(File.read(path))
  result = data.find { |entry| entry.fetch("id") == "market-vague" }
  result["selected"] = "none"
  result["pass"] = false
  File.write(path, JSON.generate(data))
' "$ROUTING_CURRENT_CONTRACT_FIXTURE/evals/runs/2026-08-01-grok-routing-full-matrix/runner-results.json"
ruby "$ROUTING_CURRENT_CONTRACT_FIXTURE/scripts/generate-evidence-manifests.rb" \
  "$ROUTING_CURRENT_CONTRACT_FIXTURE/evals/runs/2026-08-01-grok-routing-full-matrix" >/dev/null
"$ROUTING_CURRENT_CONTRACT_FIXTURE/scripts/report-evidence-coverage.rb" --suite routing --json \
  > "$TEST_ROOT/routing-result-consistency.json"
ruby -rjson -e '
  report = JSON.parse(File.read(ARGV.fetch(0)))
  target = report.fetch("cases").find { |entry| entry.fetch("id") == "market-vague" }
  abort "failed routing result still counted as a current pass" if target.fetch("hasCurrentCompletePass")
' "$TEST_ROOT/routing-result-consistency.json"
cp "$ROOT/evals/runs/2026-08-01-grok-routing-full-matrix/runner-results.json" \
  "$ROUTING_CURRENT_CONTRACT_FIXTURE/evals/runs/2026-08-01-grok-routing-full-matrix/runner-results.json"
ROUTING_TAMPERED_PROMPT="$ROUTING_CURRENT_CONTRACT_FIXTURE/evals/runs/2026-08-01-grok-routing-full-matrix/raw/prompts/market-vague.txt"
printf '%s\n' 'Injected instruction outside the canonical wrapper.' > "$ROUTING_TAMPERED_PROMPT.next"
cat "$ROUTING_TAMPERED_PROMPT" >> "$ROUTING_TAMPERED_PROMPT.next"
mv "$ROUTING_TAMPERED_PROMPT.next" "$ROUTING_TAMPERED_PROMPT"
refresh_raw_manifest_entry \
  "$ROUTING_TAMPERED_PROMPT" \
  "$ROUTING_CURRENT_CONTRACT_FIXTURE/evals/runs/2026-08-01-grok-routing-full-matrix/raw/artifact-manifest.txt" \
  "prompts/market-vague.txt"
ruby "$ROUTING_CURRENT_CONTRACT_FIXTURE/scripts/generate-evidence-manifests.rb" \
  "$ROUTING_CURRENT_CONTRACT_FIXTURE/evals/runs/2026-08-01-grok-routing-full-matrix" >/dev/null
"$ROUTING_CURRENT_CONTRACT_FIXTURE/scripts/report-evidence-coverage.rb" --suite routing --json \
  > "$TEST_ROOT/routing-prompt-consistency.json"
ruby -rjson -e '
  report = JSON.parse(File.read(ARGV.fetch(0)))
  target = report.fetch("cases").find { |entry| entry.fetch("id") == "market-vague" }
  abort "non-canonical routing prompt still counted as current" if target.fetch("hasCurrentCompletePass")
' "$TEST_ROOT/routing-prompt-consistency.json"
cp "$ROOT/evals/runs/2026-08-01-grok-routing-full-matrix/raw/prompts/market-vague.txt" "$ROUTING_TAMPERED_PROMPT"
cp "$ROOT/evals/runs/2026-08-01-grok-routing-full-matrix/raw/artifact-manifest.txt" \
  "$ROUTING_CURRENT_CONTRACT_FIXTURE/evals/runs/2026-08-01-grok-routing-full-matrix/raw/artifact-manifest.txt"

ruby -rjson -e '
  path = ARGV.fetch(0)
  data = JSON.parse(File.read(path))
  data.fetch("executionDefaults").delete("ephemeralSession")
  File.write(path, JSON.generate(data))
' "$ROUTING_CURRENT_CONTRACT_FIXTURE/evals/runs/2026-08-01-grok-routing-full-matrix/run.json"
ruby "$ROUTING_CURRENT_CONTRACT_FIXTURE/scripts/generate-evidence-manifests.rb" \
  "$ROUTING_CURRENT_CONTRACT_FIXTURE/evals/runs/2026-08-01-grok-routing-full-matrix" >/dev/null
if "$ROUTING_CURRENT_CONTRACT_FIXTURE/scripts/report-evidence-coverage.rb" \
  --suite routing --require-current-complete-pass-host grok \
  > "$TEST_ROOT/routing-current-contract.log" 2>&1; then
  fail "routing current-source gate accepted an incomplete Grok execution contract"
fi
grep -q "host:grok" "$TEST_ROOT/routing-current-contract.log" ||
  fail "routing current-source gate omitted the incomplete Grok contract"

ruby -rjson -e '
  path = ARGV.fetch(0)
  data = JSON.parse(File.read(path))
  data.fetch("host")["name"] = "Mystery Host"
  data.fetch("executionDefaults")["ephemeralSession"] = true
  File.write(path, JSON.generate(data))
' "$ROUTING_CURRENT_CONTRACT_FIXTURE/evals/runs/2026-08-01-grok-routing-full-matrix/run.json"
ruby "$ROUTING_CURRENT_CONTRACT_FIXTURE/scripts/generate-evidence-manifests.rb" \
  "$ROUTING_CURRENT_CONTRACT_FIXTURE/evals/runs/2026-08-01-grok-routing-full-matrix" >/dev/null
if "$ROUTING_CURRENT_CONTRACT_FIXTURE/scripts/report-evidence-coverage.rb" \
  --suite routing --require-current-complete-pass \
  > "$TEST_ROOT/routing-current-unknown-host.log" 2>&1; then
  fail "routing current-source gate accepted an unsupported host"
fi
grep -q "missing-current=25" "$TEST_ROOT/routing-current-unknown-host.log" ||
  fail "routing current-source gate reported the wrong unsupported-host gap"

if "$ROOT/scripts/report-evidence-coverage.rb" --suite unknown > "$TEST_ROOT/routing-coverage-unknown-suite.log" 2>&1; then
  fail "evidence coverage report accepted an unknown suite"
fi
grep -q "unknown evidence suite" "$TEST_ROOT/routing-coverage-unknown-suite.log" || fail "evidence coverage report returned the wrong suite error"
pass "routing coverage report rechecks canonical prompts, results, and execution contracts"

ruby -I "$ROOT/scripts/lib" -r evidence_handoff_contract -e '
  require "tmpdir"
  contract = Zstack::EvidenceHandoffContract
  valid = <<~MARKDOWN
    | Field | Value |
    |---|---|
    | Current decision | Validate first |
    | Evidence classes | observed experiment / assumption |
    | Supported claims | One bounded claim |
    | Still unproven | Payment |
    | Contradictions / exclusions | Warm traffic |
    | Source anchors | dated export |
    | Next validation | Owner + action + threshold |
  MARKDOWN
  Dir.mktmpdir do |directory|
    path = File.join(directory, "response.txt")
    File.write(path, valid)
    result = contract.evaluate([{ name: "responses/case.txt", path: path }])
    abort "valid Evidence handoff failed" unless result.fetch("passed")

    linked = File.join(directory, "linked.txt")
    File.symlink(path, linked)
    linked_result = contract.evaluate([{ name: "responses/linked.txt", path: linked }])
    abort "Evidence handoff accepted a symbolic link" if linked_result.fetch("passed")
    abort "Evidence handoff reported the wrong symbolic-link failure" unless linked_result.fetch("errors").join(" ").include?("regular non-link")

    hardlinked = File.join(directory, "hardlinked.txt")
    File.link(path, hardlinked)
    hardlink_result = contract.evaluate([{ name: "responses/hardlinked.txt", path: hardlinked }])
    abort "Evidence handoff accepted a hardlink" if hardlink_result.fetch("passed")
    abort "Evidence handoff reported the wrong hardlink failure" unless hardlink_result.fetch("errors").join(" ").include?("one hard link")
    File.unlink(hardlinked)

    oversized = File.join(directory, "oversized.txt")
    File.write(oversized, valid)
    File.open(oversized, "ab") { |file| file.truncate(2 * 1024 * 1024 + 1) }
    oversized_result = contract.evaluate([{ name: "responses/oversized.txt", path: oversized }])
    abort "Evidence handoff accepted an oversized source" if oversized_result.fetch("passed")
    abort "Evidence handoff reported the wrong size-limit failure" unless oversized_result.fetch("errors").join(" ").include?("exceeds 2097152 bytes")

    captured = File.binread(path).force_encoding(Encoding::UTF_8)
    File.write(path, "changed after capture\n")
    result = contract.evaluate([{ name: "responses/case.txt", content: captured }])
    abort "captured Evidence handoff bytes were not preserved" unless result.fetch("passed")
    result = contract.evaluate([{ name: "responses/case.txt", path: path }])
    abort "path-backed Evidence handoff ignored changed bytes" if result.fetch("passed")
    result = contract.evaluate([{ name: "responses/case.txt", path: path, content: captured }])
    abort "ambiguous Evidence handoff source passed" if result.fetch("passed")

    File.write(path, valid.sub("| Field | Value |", "| Evidence handoff | Evidence classes | Detail |").sub("|---|---|", "|---|---|---|").gsub(/\|\n/, "| detail |\n"))
    result = contract.evaluate([{ name: "responses/case.txt", path: path }])
    abort "three-column Evidence handoff passed" if result.fetch("passed")

    File.write(path, valid.sub("| Current decision |", "| **Current decision** |"))
    result = contract.evaluate([{ name: "responses/case.txt", path: path }])
    abort "decorated Evidence handoff label passed" if result.fetch("passed")

    File.write(path, valid.sub("observed experiment / assumption", "customer proof"))
    result = contract.evaluate([{ name: "responses/case.txt", path: path }])
    abort "non-canonical evidence class passed" if result.fetch("passed")

    File.write(path, valid + "\n" + valid)
    result = contract.evaluate([{ name: "responses/case.txt", path: path }])
    abort "duplicate Evidence handoff passed" if result.fetch("passed")
  end
'
pass "Evidence handoff validator rejects structural and vocabulary drift"

ruby -I "$ROOT/scripts/lib" -r eval_private_paths -e '
  ids = %w[first-semantic-case second-semantic-case]
  tokens = Zstack::EvalPrivatePaths.build_tokens(ids)
  abort "private path helper lost case ids" unless tokens.keys == ids
  abort "private path helper produced invalid tokens" unless tokens.values.all? { |token| Zstack::EvalPrivatePaths.token?(token) }
  abort "private path helper reused a token" unless tokens.values.uniq.length == ids.length
  abort "private token leaked a semantic id" unless tokens.none? { |id, token| token.include?(id) }
'
pass "evaluation private paths use unique opaque 128-bit case tokens"

BEHAVIOR_DRY_RUN="$TEST_ROOT/behavior-runner-dry"
"$ROOT/scripts/run-codex-behavioral-evals.rb" \
  --dry-run \
  --case market-tools-blocked \
  --case seo-black-hat \
  --output "$BEHAVIOR_DRY_RUN" > "$TEST_ROOT/behavior-runner-dry.log"
[[ -f "$BEHAVIOR_DRY_RUN/prompts/market-tools-blocked.txt" ]] || fail "behavioral runner omitted a selected prompt"
[[ -f "$BEHAVIOR_DRY_RUN/skill-snapshots/z-market-validate/SKILL.md" ]] || fail "behavioral runner omitted the selected skill snapshot"
[[ ! -e "$BEHAVIOR_DRY_RUN/skill-snapshots/z-write-prd" ]] || fail "behavioral runner copied an unselected skill"
[[ ! -e "$BEHAVIOR_DRY_RUN/results.json" ]] || fail "behavioral dry-run invented execution results"
[[ "$(zstack_file_mode_bits "$BEHAVIOR_DRY_RUN")" == "700" ]] || fail "behavioral runner created a non-private output directory"
ruby -rjson -e 'abort "response default timeout drifted" unless JSON.parse(File.read(ARGV.fetch(0))).fetch("timeoutSecondsPerCase") == 600' "$BEHAVIOR_DRY_RUN/controls.json"
cmp "$ROOT/skills/z-market-validate/SKILL.md" "$BEHAVIOR_DRY_RUN/skill-snapshots/z-market-validate/SKILL.md" >/dev/null ||
  fail "behavioral runner changed the copied skill source"
ruby -ryaml -e '
  manifest = YAML.safe_load(File.read(ARGV.fetch(0)), permitted_classes: [], aliases: false)
  prompts_root = ARGV.fetch(1)
  selected = %w[market-tools-blocked seo-black-hat]
  selected.each do |id|
    entry = manifest.fetch("cases").find { |candidate| candidate.fetch("id") == id }
    prompt = File.read(File.join(prompts_root, "#{id}.txt"))
    (manifest.fetch("contract_must") + entry.fetch("must") + entry.fetch("must_not")).each do |criterion|
      abort "behavioral runner leaked a grading criterion for #{id}" if prompt.include?(criterion)
    end
  end
' "$ROOT/evals/cases.yaml" "$BEHAVIOR_DRY_RUN/prompts"
grep -q 'grading criteria' "$BEHAVIOR_DRY_RUN/prompts/market-tools-blocked.txt" || fail "behavioral runner omitted its anti-leak boundary"
grep -q 'skill-snapshots/z-market-validate/SKILL.md' "$BEHAVIOR_DRY_RUN/skill-snapshot-manifest.txt" || fail "behavioral runner omitted snapshot hashes"
pass "behavioral runner creates exact leak-free skill snapshots and prompts"

BEHAVIOR_CASE_LIMIT_FIXTURE="$(copy_fixture behavior-runner-case-limit)"
ruby -ryaml -e '
  path = ARGV.fetch(0)
  document = YAML.safe_load(File.read(path), permitted_classes: [], aliases: false)
  document["cases"] = 257.times.map do |index|
    {
      "id" => format("case-limit-%03d", index),
      "skill" => "z-market-validate",
      "kind" => "happy-path",
      "execution" => "response",
      "prompt" => "Synthetic behavioral case #{index}",
      "must" => [],
      "must_not" => []
    }
  end
  File.write(path, YAML.dump(document))
' "$BEHAVIOR_CASE_LIMIT_FIXTURE/evals/cases.yaml"
if "$BEHAVIOR_CASE_LIMIT_FIXTURE/scripts/run-codex-behavioral-evals.rb" --dry-run \
  > "$TEST_ROOT/behavior-runner-case-limit.log" 2>&1; then
  fail "behavioral runner accepted too many cases in one run"
fi
grep -q "selected run has 257 cases; maximum is 256" "$TEST_ROOT/behavior-runner-case-limit.log" ||
  fail "behavioral runner reported the wrong case-count limit failure"
pass "behavioral runner bounds total calls per invocation"

SNAPSHOT_LIMIT_FIXTURE="$(copy_fixture snapshot-package-limit)"
SNAPSHOT_LIMIT_FILES="$SNAPSHOT_LIMIT_FIXTURE/skills/z-market-validate/generated"
mkdir -p "$SNAPSHOT_LIMIT_FILES"
for ((snapshot_index = 1; snapshot_index <= 101; snapshot_index++)); do
  : > "$SNAPSHOT_LIMIT_FILES/file-$snapshot_index.txt"
done
if "$SNAPSHOT_LIMIT_FIXTURE/scripts/run-codex-behavioral-evals.rb" \
  --dry-run --case market-tools-blocked > "$TEST_ROOT/snapshot-package-limit.log" 2>&1; then
  fail "behavioral runner copied an oversized skill package"
fi
grep -q "skill snapshot source is outside its safety bounds: skill package has" "$TEST_ROOT/snapshot-package-limit.log" ||
  fail "behavioral runner reported the wrong skill-package limit failure"
pass "behavioral runner bounds skill snapshots independently of doctor"

SNAPSHOT_DRIFT_FIXTURE="$(copy_fixture snapshot-source-drift)"
mv "$SNAPSHOT_DRIFT_FIXTURE/scripts/lib/eval_input_file.rb" \
  "$SNAPSHOT_DRIFT_FIXTURE/scripts/lib/eval_input_file_real.rb"
printf '%s\n' \
  '# frozen_string_literal: true' \
  'require_relative "eval_input_file_real"' \
  'module Zstack' \
  '  module EvalInputFile' \
  '    class << self' \
  '      alias_method :zstack_original_read_for_snapshot_drift_test, :read' \
  '      def read(path, **options)' \
  '        content = zstack_original_read_for_snapshot_drift_test(path, **options)' \
  '        target = File.expand_path(ENV.fetch("SNAPSHOT_DRIFT_TARGET"))' \
  '        if File.expand_path(path) == target && !instance_variable_defined?(:@zstack_snapshot_drift_mutated)' \
  '          instance_variable_set(:@zstack_snapshot_drift_mutated, true)' \
  '          File.open(target, "ab") { |file| file.write("\nInjected concurrent snapshot drift.\n") }' \
  '        end' \
  '        content' \
  '      end' \
  '    end' \
  '  end' \
  'end' \
  > "$SNAPSHOT_DRIFT_FIXTURE/scripts/lib/eval_input_file.rb"
SNAPSHOT_DRIFT_OUTPUT="$TEST_ROOT/snapshot-source-drift-output"
if SNAPSHOT_DRIFT_TARGET="$SNAPSHOT_DRIFT_FIXTURE/skills/z-market-validate/SKILL.md" \
  "$SNAPSHOT_DRIFT_FIXTURE/scripts/run-codex-behavioral-evals.rb" \
  --dry-run \
  --case market-tools-blocked \
  --output "$SNAPSHOT_DRIFT_OUTPUT" > "$TEST_ROOT/snapshot-source-drift.log" 2>&1; then
  fail "behavioral runner accepted a skill source changed during snapshot capture"
fi
grep -q "skill snapshot source changed while it was captured: z-market-validate" \
  "$TEST_ROOT/snapshot-source-drift.log" ||
  fail "behavioral runner reported the wrong concurrent snapshot-source failure"
[[ ! -e "$SNAPSHOT_DRIFT_OUTPUT/skill-snapshot-manifest.txt" ]] ||
  fail "behavioral runner finalized a manifest for a concurrently changed skill snapshot"
pass "behavioral runner binds selected skill snapshots to one stable source state"

FAKE_BEHAVIOR_CODEX="$TEST_ROOT/fake-behavior-codex"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'if [[ "${1:-}" == "--version" ]]; then' \
  '  if [[ -n "${FAKE_BEHAVIOR_RETAINED_SKILL_DRIFT:-}" ]]; then printf "retained drift\n" > "$FAKE_BEHAVIOR_RETAINED_SKILL_DRIFT"; fi' \
  '  echo "codex-cli fake-behavior-1.0"' \
  '  exit 0' \
  'fi' \
  '[[ "${1:-}" == "exec" ]] || exit 64' \
  'if [[ -n "${FAKE_BEHAVIOR_EXECUTION_MARKER:-}" ]]; then : > "$FAKE_BEHAVIOR_EXECUTION_MARKER"; fi' \
  'if [[ "${REQUIRE_ISOLATED_CODEX_HOME:-0}" == "1" ]]; then' \
  '  [[ -n "${CODEX_HOME:-}" && -f "$CODEX_HOME/auth.json" ]] || exit 67' \
  '  [[ -z "${CODEX_THREAD_ID:-}" && -z "${CODEX_PERMISSION_PROFILE:-}" && -z "${CODEX_INTERNAL_ORIGINATOR_OVERRIDE:-}" ]] || exit 68' \
  '  [[ " $* " == *" -c analytics.enabled=false "* ]] || exit 69' \
  'fi' \
  'output=""' \
  'workspace=""' \
  'for ((index = 1; index <= $#; index++)); do' \
  '  argument="${!index}"' \
  '  if [[ "$argument" == "-o" ]]; then' \
  '    next_index=$((index + 1))' \
  '    output="${!next_index}"' \
  '  elif [[ "$argument" == "-C" ]]; then' \
  '    next_index=$((index + 1))' \
  '    workspace="${!next_index}"' \
  '  fi' \
  'done' \
  '[[ -n "$output" && -n "$workspace" ]] || exit 65' \
  '[[ -f "$workspace/.zstack-skill/z-market-validate/SKILL.md" ]] || exit 66' \
  'if [[ "${!#}" == "-" ]]; then prompt="$(cat)"; else prompt="${!#}"; fi' \
  'if [[ "${FAKE_BEHAVIOR_WORKSPACE_ESCAPE:-0}" == "1" ]]; then printf "escape\n" > "$workspace/outside.txt"; fi' \
  'if [[ "${FAKE_BEHAVIOR_SKILL_DRIFT:-0}" == "1" ]]; then printf "runtime drift\n" > "$workspace/.zstack-skill/z-market-validate/SKILL.md"; fi' \
  'sleep "${FAKE_BEHAVIOR_SLEEP_SECONDS:-0}"' \
  'if [[ "${FAKE_BEHAVIOR_STDOUT_BYTES:-0}" -gt 0 ]]; then' \
  '  dd if=/dev/zero bs="${FAKE_BEHAVIOR_STDOUT_BYTES}" count=1 2>/dev/null' \
  'fi' \
  'response="fake complete behavioral answer"' \
  'if [[ "${FAKE_BEHAVIOR_EMPTY:-0}" != "1" ]]; then' \
  '  printf "%s\n" "$response" "" "| Field | Value |" "|---|---|" "| Current decision | Validate first |" "| Evidence classes | assumption |" "| Supported claims | The fixture ran |" "| Still unproven | Product demand |" "| Contradictions / exclusions | None supplied |" "| Source anchors | Fixture response |" "| Next validation | Run a real test |" > "$output"' \
  '  response="$(cat "$output")"' \
  'fi' \
  'printf "OpenAI Codex vfake-behavior-1.0\n--------\nworkdir: %s\nmodel: gpt-5.6-sol\napproval: never\nsandbox: read-only\nreasoning effort: medium\nuser\n%s\ncodex\n%s\n" "$workspace" "$prompt" "$response"' > "$FAKE_BEHAVIOR_CODEX"
chmod +x "$FAKE_BEHAVIOR_CODEX"

BEHAVIOR_RETAINED_SKILL_DRIFT="$TEST_ROOT/behavior-retained-skill-drift"
BEHAVIOR_EXECUTION_MARKER="$TEST_ROOT/behavior-retained-skill-executed"
if FAKE_BEHAVIOR_RETAINED_SKILL_DRIFT="$BEHAVIOR_RETAINED_SKILL_DRIFT/skill-snapshots/z-market-validate/SKILL.md" \
  FAKE_BEHAVIOR_EXECUTION_MARKER="$BEHAVIOR_EXECUTION_MARKER" \
  "$ROOT/scripts/run-codex-behavioral-evals.rb" \
  --codex "$FAKE_BEHAVIOR_CODEX" \
  --case market-competition-composite \
  --output "$BEHAVIOR_RETAINED_SKILL_DRIFT" > "$TEST_ROOT/behavior-retained-skill-drift.log" 2>&1; then
  fail "behavioral runner accepted a retained skill snapshot changed by the host version probe"
fi
grep -q "retained skill snapshot changed after runner capture" \
  "$TEST_ROOT/behavior-retained-skill-drift.log" ||
  fail "behavioral runner reported the wrong retained skill snapshot drift"
[[ ! -e "$BEHAVIOR_EXECUTION_MARKER" ]] ||
  fail "behavioral runner executed the host after retained skill snapshot drift"
pass "behavioral runner revalidates retained skill bytes after host version probes"

BEHAVIOR_FAKE_PASS="$TEST_ROOT/behavior-runner-pass"
REQUIRE_ISOLATED_CODEX_HOME=1 \
CODEX_THREAD_ID=ambient-thread \
CODEX_PERMISSION_PROFILE=ambient-profile \
CODEX_INTERNAL_ORIGINATOR_OVERRIDE=ambient-origin \
"$ROOT/scripts/run-codex-behavioral-evals.rb" \
  --codex "$FAKE_BEHAVIOR_CODEX" \
  --auth-path "$FAKE_CODEX_AUTH" \
  --case market-competition-composite \
  --output "$BEHAVIOR_FAKE_PASS" > "$TEST_ROOT/behavior-runner-pass.log"
ruby -rjson -e '
  controls = JSON.parse(File.read(ARGV.fetch(0)))
  result = JSON.parse(File.read(ARGV.fetch(1))).fetch(0)
  abort "behavioral runner did not record the fake host" unless controls.fetch("hostVersion") == "codex-cli fake-behavior-1.0"
  abort "behavioral runner did not record its output limit" unless controls.fetch("maxHostOutputBytesPerCase") == 2 * 1024 * 1024
  runtime = %w[maxRuntimeGitFiles maxRuntimeGitTreeEntries maxRuntimeGitBytes maxRuntimeHostHomeFiles maxRuntimeHostHomeTreeEntries maxRuntimeHostHomeBytes].map { |field| controls.fetch(field) }
  abort "behavioral runner did not record baseline runtime limits" unless controls.fetch("runtimeTreeMonitoring") == true &&
    controls.fetch("concurrentRuntimeMonitoring") == true && controls.fetch("pidMonitoringStartsAtSpawn") == true &&
    controls.fetch("sharedRootMonitoring") == true && controls.fetch("privatePromptIntegrityMonitoring") == false &&
    controls.fetch("outputDirectoryIdentityMonitoring") == true &&
    runtime == [100, 500, 2 * 1024 * 1024, 200, 500, 8 * 1024 * 1024]
  output_runtime = %w[maxRuntimeOutputFiles maxRuntimeOutputTreeEntries maxRuntimeOutputBytes].map { |field| controls.fetch(field) }
  abort "behavioral runner did not record output-tree limits" unless controls.fetch("outputTreeMonitoring") == true &&
    controls.fetch("exclusiveRunnerOutputs") == true &&
    controls.fetch("workspaceViolationStopsRun") == true &&
    controls.fetch("copiedSkillIntegrityMonitoring") == true &&
    controls.fetch("singleLinkInputFiles") == true &&
    controls.fetch("singleLinkRuntimeFiles") == true &&
    output_runtime == [4_096, 8_192, 640 * 1024 * 1024]
  abort "behavioral runner invented a workspace limit failure" unless result.fetch("workspaceLimitError").nil?
  abort "behavioral runner did not isolate Codex host state" unless controls.fetch("isolatedHostHome")
  abort "behavioral runner did not disable Codex analytics" unless controls.fetch("analyticsEnabled") == false
  abort "behavioral runner did not preserve the no-grading boundary" unless controls.fetch("grading") == "not performed by runner" && result["grade"].nil?
  abort "behavioral runner did not retain a completed execution" unless result.fetch("completed") && result.fetch("exitStatus") == 0
  abort "behavioral runner did not mechanically validate the Evidence handoff" unless result.dig("evidenceHandoffContract", "passed") == true
  abort "behavioral result paths must stay relative" unless %w[promptPath responsePath logPath].all? { |field| !result.fetch(field).start_with?("/") }
' "$BEHAVIOR_FAKE_PASS/controls.json" "$BEHAVIOR_FAKE_PASS/results.json"
ruby -rjson -e '
  path = ARGV.fetch(0)
  review = JSON.parse(File.read(path))
  abort "behavioral runner did not create one review scaffold" unless review.fetch("cases").length == 1
  abort "behavioral runner pregraded its review scaffold" unless review.fetch("reviewer").nil? && review.fetch("cases").fetch(0).fetch("grade").nil?
  contract = "Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names."
  first = review.fetch("cases").fetch(0).fetch("criteria").fetch(0)
  abort "behavioral runner omitted the shared handoff contract" unless first.fetch("expectation") == "present" && first.fetch("criterion") == contract
  abort "behavioral runner did not prefill the mechanical handoff result" unless first.fetch("observed") == true && first.fetch("evidence").include?("Mechanical check found one valid Evidence handoff table")
  applicability = review.fetch("cases").fetch(0).fetch("criteria").fetch(1)
  abort "behavioral runner pregraded Evidence class applicability" unless applicability.fetch("observed").nil? && applicability.fetch("evidence").nil?
  review["reviewer"] = "integration-test semantic review"
  review.fetch("cases").each do |entry|
    entry["grade"] = "pass"
    entry.fetch("criteria").each do |criterion|
      criterion["observed"] = criterion.fetch("expectation") == "present"
      criterion["evidence"] = "Fake response was reviewed against this criterion."
    end
  end
  File.write(path, JSON.pretty_generate(review) + "\n")
' "$BEHAVIOR_FAKE_PASS/review.json"
grep -q 'fake complete behavioral answer' "$BEHAVIOR_FAKE_PASS/responses/market-competition-composite.txt" || fail "behavioral runner lost the final response"
[[ ! -e "$BEHAVIOR_FAKE_PASS/workspace" && ! -e "$BEHAVIOR_FAKE_PASS/workspaces" ]] || fail "behavioral runner retained disposable workspaces"
pass "behavioral runner isolates execution and records ungraded raw responses"

BEHAVIOR_TIMEOUT="$TEST_ROOT/behavior-runner-timeout"
if FAKE_BEHAVIOR_SLEEP_SECONDS=5 "$ROOT/scripts/run-codex-behavioral-evals.rb" \
  --codex "$FAKE_BEHAVIOR_CODEX" \
  --case market-competition-composite \
  --timeout-seconds 1 \
  --output "$BEHAVIOR_TIMEOUT" > "$TEST_ROOT/behavior-runner-timeout.log" 2>&1; then
  fail "behavioral runner accepted a timed-out host process"
fi
ruby -rjson -e '
  controls = JSON.parse(File.read(ARGV.fetch(0)))
  result = JSON.parse(File.read(ARGV.fetch(1))).fetch(0)
  abort "behavioral timeout control was not recorded" unless controls.fetch("timeoutSecondsPerCase") == 1
  abort "behavioral timeout was not retained" unless result.fetch("timedOut") && !result.fetch("completed")
  abort "behavioral timeout exceeded its termination grace" unless result.fetch("elapsedSeconds") < 4
' "$BEHAVIOR_TIMEOUT/controls.json" "$BEHAVIOR_TIMEOUT/results.json"
grep -q 'EXECUTION-FAILED (timeout 1s)' "$TEST_ROOT/behavior-runner-timeout.log" || fail "behavioral timeout was not reported clearly"
pass "behavioral runner bounds and records stalled host processes"

BEHAVIOR_WORKSPACE_LIMIT="$TEST_ROOT/behavior-runner-workspace-limit"
if FAKE_BEHAVIOR_WORKSPACE_ESCAPE=1 "$ROOT/scripts/run-codex-behavioral-evals.rb" \
  --codex "$FAKE_BEHAVIOR_CODEX" \
  --case market-competition-composite \
  --timeout-seconds 5 \
  --output "$BEHAVIOR_WORKSPACE_LIMIT" > "$TEST_ROOT/behavior-runner-workspace-limit.log" 2>&1; then
  fail "behavioral response runner accepted a host write outside the allowed workspace layout"
fi
ruby -rjson -e '
  result = JSON.parse(File.read(ARGV.fetch(0))).fetch(0)
  error = result.fetch("workspaceLimitError")
  abort "behavioral workspace escape lost its classification" unless error&.include?("allowed workspace layout") &&
    result.fetch("errorCategory") == "workspace-limit" && !result.fetch("completed")
  abort "behavioral workspace watchdog waited for the case timeout" unless result.fetch("elapsedSeconds") < 4
' "$BEHAVIOR_WORKSPACE_LIMIT/results.json"
pass "behavioral response runner terminates hosts that write outside the allowed workspace layout"

BEHAVIOR_SKILL_DRIFT="$TEST_ROOT/behavior-runner-skill-drift"
if FAKE_BEHAVIOR_SKILL_DRIFT=1 FAKE_BEHAVIOR_SLEEP_SECONDS=5 \
  "$ROOT/scripts/run-codex-behavioral-evals.rb" \
  --codex "$FAKE_BEHAVIOR_CODEX" \
  --case market-competition-composite \
  --timeout-seconds 6 \
  --output "$BEHAVIOR_SKILL_DRIFT" > "$TEST_ROOT/behavior-runner-skill-drift.log" 2>&1; then
  fail "behavioral response runner accepted copied skill byte drift"
fi
ruby -rjson -e '
  result = JSON.parse(File.read(ARGV.fetch(0))).fetch(0)
  error = result.fetch("workspaceLimitError")
  abort "copied skill drift lost its classification" unless error&.include?("changed after runner capture") &&
    result.fetch("errorCategory") == "workspace-limit" && !result.fetch("completed")
  abort "copied skill watchdog waited for the case timeout" unless result.fetch("elapsedSeconds") < 4
' "$BEHAVIOR_SKILL_DRIFT/results.json"
pass "behavioral runner continuously binds copied skill bytes during execution"

BEHAVIOR_RESOURCE_STOP="$TEST_ROOT/behavior-runner-resource-stop"
if FAKE_BEHAVIOR_WORKSPACE_ESCAPE=1 "$ROOT/scripts/run-codex-behavioral-evals.rb" \
  --codex "$FAKE_BEHAVIOR_CODEX" \
  --case market-competition-composite \
  --case market-tools-blocked \
  --jobs 1 \
  --timeout-seconds 5 \
  --output "$BEHAVIOR_RESOURCE_STOP" > "$TEST_ROOT/behavior-runner-resource-stop.log" 2>&1; then
  fail "behavioral runner continued after a workspace safety violation"
fi
ruby -rjson -e '
  controls = JSON.parse(File.read(ARGV.fetch(0)))
  results = JSON.parse(File.read(ARGV.fetch(1)))
  review = JSON.parse(File.read(ARGV.fetch(2)))
  abort "behavioral resource-stop control changed" unless controls.fetch("workspaceViolationStopsRun") == true && controls.fetch("cases").length == 2
  abort "behavioral runner scheduled a later batch after a workspace violation" unless results.length == 1 && results.fetch(0).fetch("workspaceLimitError")
  missing = review.fetch("cases").find { |entry| entry.fetch("id") == "market-competition-composite" }
  abort "partial behavioral review pregraded an unexecuted case" unless missing && missing.fetch("criteria").all? { |criterion| criterion["observed"].nil? && criterion["evidence"].nil? }
' "$BEHAVIOR_RESOURCE_STOP/controls.json" "$BEHAVIOR_RESOURCE_STOP/results.json" "$BEHAVIOR_RESOURCE_STOP/review.json"
grep -q 'COMPLETED=0/2' "$TEST_ROOT/behavior-runner-resource-stop.log" ||
  fail "behavioral resource-stop summary hid unexecuted cases"
pass "behavioral runner stops later batches and leaves unexecuted reviews blank after a safety violation"

BEHAVIOR_OUTPUT_LIMIT="$TEST_ROOT/behavior-runner-output-limit"
if FAKE_BEHAVIOR_STDOUT_BYTES=$((2 * 1024 * 1024 + 1)) \
  "$ROOT/scripts/run-codex-behavioral-evals.rb" \
  --codex "$FAKE_BEHAVIOR_CODEX" \
  --case market-competition-composite \
  --output "$BEHAVIOR_OUTPUT_LIMIT" > "$TEST_ROOT/behavior-runner-output-limit.log" 2>&1; then
  fail "behavioral runner accepted host output above its byte limit"
fi
ruby -rjson -e '
  controls = JSON.parse(File.read(ARGV.fetch(0)))
  result = JSON.parse(File.read(ARGV.fetch(1))).fetch(0)
  limit = controls.fetch("maxHostOutputBytesPerCase")
  abort "behavioral output limit drifted" unless limit == 2 * 1024 * 1024
  abort "behavioral output limit was not retained" unless result.fetch("outputLimited") && result.fetch("hostOutputBytes") > limit
  abort "behavioral output overflow was misclassified" unless result.fetch("errorCategory") == "output-limit"
  abort "behavioral output overflow was accepted" if result.fetch("timedOut") || result.fetch("completed")
' "$BEHAVIOR_OUTPUT_LIMIT/controls.json" "$BEHAVIOR_OUTPUT_LIMIT/results.json"
grep -q 'EXECUTION-FAILED (output limit 2097152 bytes)' "$TEST_ROOT/behavior-runner-output-limit.log" ||
  fail "behavioral output limit was not reported clearly"
pass "behavioral runner terminates and records oversized host output"

BEHAVIOR_ARCHIVE_FIXTURE="$(copy_fixture behavior-archive)"
"$BEHAVIOR_ARCHIVE_FIXTURE/scripts/archive-codex-behavioral-run.rb" \
  --run-dir "$BEHAVIOR_FAKE_PASS" \
  --archive 2026-08-01-fake-behavioral \
  --phase fake > "$TEST_ROOT/behavior-archive.log"
BEHAVIOR_ARCHIVE="$BEHAVIOR_ARCHIVE_FIXTURE/evals/runs/2026-08-01-fake-behavioral"
[[ -f "$BEHAVIOR_ARCHIVE/run.json" && -f "$BEHAVIOR_ARCHIVE/archive-manifest.txt" ]] || fail "behavioral archiver omitted schema-v2 control files"
[[ -f "$BEHAVIOR_ARCHIVE/runner-review.json" ]] || fail "behavioral archiver omitted the explicit semantic review"
[[ -f "$BEHAVIOR_ARCHIVE/raw/skill-snapshots/z-market-validate/SKILL.md" ]] || fail "behavioral archiver omitted the exact skill snapshot"
[[ -f "$BEHAVIOR_ARCHIVE/raw/prompts/market-competition-composite.txt" && -f "$BEHAVIOR_ARCHIVE/raw/responses/market-competition-composite.txt" ]] || fail "behavioral archiver omitted exact prompt or response bytes"
if find "$BEHAVIOR_ARCHIVE" -type f -path '*/logs/*' | grep -q .; then
  fail "behavioral archiver copied private CLI logs"
fi
ruby "$BEHAVIOR_ARCHIVE_FIXTURE/scripts/validate-evidence.rb" >/dev/null

SOURCE_SNAPSHOT_LIBRARY="$BEHAVIOR_ARCHIVE_FIXTURE/scripts/lib/eval_source_snapshot.rb" \
SOURCE_SNAPSHOT_REPLACE_RELATIVE="review.json" \
SOURCE_SNAPSHOT_REPLACEMENT_BYTES="replacement snapshot path must not be parsed" \
RUBYOPT="-r$SOURCE_SNAPSHOT_REPLACEMENT_HOOK" \
  "$BEHAVIOR_ARCHIVE_FIXTURE/scripts/archive-codex-behavioral-run.rb" \
  --run-dir "$BEHAVIOR_FAKE_PASS" \
  --archive 2026-08-01-replaced-source-behavioral \
  --phase fake > "$TEST_ROOT/behavior-archive-replaced-source.log"
ruby "$BEHAVIOR_ARCHIVE_FIXTURE/scripts/validate-evidence.rb" >/dev/null
[[ -f "$BEHAVIOR_ARCHIVE_FIXTURE/evals/runs/2026-08-01-replaced-source-behavioral/runner-review.json" ]] ||
  fail "behavioral archiver did not publish from immutable in-memory review bytes"
pass "behavioral archiver parses and publishes immutable in-memory source bytes"

behavior_archive_manifest_before="$(ruby -rdigest -e 'puts Digest::SHA256.file(ARGV.fetch(0)).hexdigest' "$BEHAVIOR_ARCHIVE/archive-manifest.txt")"
if "$BEHAVIOR_ARCHIVE_FIXTURE/scripts/archive-codex-behavioral-run.rb" \
  --run-dir "$BEHAVIOR_FAKE_PASS" \
  --archive 2026-08-01-fake-behavioral \
  --phase fake > "$TEST_ROOT/behavior-archive-duplicate.log" 2>&1; then
  fail "behavioral archiver overwrote an existing archive"
fi
[[ "$(ruby -rdigest -e 'puts Digest::SHA256.file(ARGV.fetch(0)).hexdigest' "$BEHAVIOR_ARCHIVE/archive-manifest.txt")" == "$behavior_archive_manifest_before" ]] || fail "duplicate behavioral archive attempt changed existing evidence"

BEHAVIOR_LIMIT_TAMPERED="$TEST_ROOT/behavior-runner-limit-tampered"
cp -R "$BEHAVIOR_FAKE_PASS" "$BEHAVIOR_LIMIT_TAMPERED"
ruby -rjson -e '
  path = ARGV.fetch(0)
  controls = JSON.parse(File.read(path))
  controls["maxHostOutputBytesPerCase"] = 1
  File.write(path, JSON.pretty_generate(controls) + "\n")
' "$BEHAVIOR_LIMIT_TAMPERED/controls.json"
if "$BEHAVIOR_ARCHIVE_FIXTURE/scripts/archive-codex-behavioral-run.rb" \
  --run-dir "$BEHAVIOR_LIMIT_TAMPERED" \
  --archive 2026-08-01-tampered-limit-behavioral \
  --phase tampered > "$TEST_ROOT/behavior-archive-limit-tampered.log" 2>&1; then
  fail "behavioral archiver accepted a tampered host-output limit"
fi
grep -q "maxHostOutputBytesPerCase must match the runner safety limit" "$TEST_ROOT/behavior-archive-limit-tampered.log" ||
  fail "behavioral archiver reported the wrong host-output-limit failure"
[[ ! -e "$BEHAVIOR_ARCHIVE_FIXTURE/evals/runs/2026-08-01-tampered-limit-behavioral" ]] ||
  fail "behavioral archiver published tampered output-limit provenance"

BEHAVIOR_SKILL_MONITOR_TAMPERED="$TEST_ROOT/behavior-runner-skill-monitor-tampered"
cp -R "$BEHAVIOR_FAKE_PASS" "$BEHAVIOR_SKILL_MONITOR_TAMPERED"
ruby -rjson -e '
  path = ARGV.fetch(0)
  controls = JSON.parse(File.read(path))
  controls["copiedSkillIntegrityMonitoring"] = false
  File.write(path, JSON.pretty_generate(controls) + "\n")
' "$BEHAVIOR_SKILL_MONITOR_TAMPERED/controls.json"
if "$BEHAVIOR_ARCHIVE_FIXTURE/scripts/archive-codex-behavioral-run.rb" \
  --run-dir "$BEHAVIOR_SKILL_MONITOR_TAMPERED" \
  --archive 2026-08-01-tampered-skill-monitor-behavioral \
  --phase tampered > "$TEST_ROOT/behavior-archive-skill-monitor-tampered.log" 2>&1; then
  fail "behavioral archiver accepted disabled copied skill integrity monitoring"
fi
grep -q "runtime tree limits must match the runner safety limits" \
  "$TEST_ROOT/behavior-archive-skill-monitor-tampered.log" ||
  fail "behavioral archiver reported the wrong copied skill monitoring failure"
[[ ! -e "$BEHAVIOR_ARCHIVE_FIXTURE/evals/runs/2026-08-01-tampered-skill-monitor-behavioral" ]] ||
  fail "behavioral archiver published disabled copied skill monitoring provenance"

BEHAVIOR_DUPLICATE_CONTROLS="$TEST_ROOT/behavior-runner-duplicate-controls"
cp -R "$BEHAVIOR_FAKE_PASS" "$BEHAVIOR_DUPLICATE_CONTROLS"
ruby -e '
  path = ARGV.fetch(0)
  content = File.read(path)
  replacement = content.sub(/\A\{/, "{\n  \"webSearch\": true,")
  abort "duplicate-key fixture did not change" if replacement == content
  File.write(path, replacement)
' "$BEHAVIOR_DUPLICATE_CONTROLS/controls.json"
if "$BEHAVIOR_ARCHIVE_FIXTURE/scripts/archive-codex-behavioral-run.rb" \
  --run-dir "$BEHAVIOR_DUPLICATE_CONTROLS" \
  --archive 2026-08-01-duplicate-controls-behavioral \
  --phase tampered > "$TEST_ROOT/behavior-archive-duplicate-controls.log" 2>&1; then
  fail "behavioral archiver accepted ambiguous duplicate controls"
fi
grep -q "duplicate JSON object key" "$TEST_ROOT/behavior-archive-duplicate-controls.log" ||
  fail "behavioral archiver reported the wrong duplicate-key failure"
[[ ! -e "$BEHAVIOR_ARCHIVE_FIXTURE/evals/runs/2026-08-01-duplicate-controls-behavioral" ]] ||
  fail "behavioral archiver published ambiguous duplicate controls"

BEHAVIOR_DIAGNOSTIC_TAMPERED="$TEST_ROOT/behavior-runner-diagnostic-tampered"
cp -R "$BEHAVIOR_FAKE_PASS" "$BEHAVIOR_DIAGNOSTIC_TAMPERED"
ruby -rjson -e '
  path = ARGV.fetch(0)
  results = JSON.parse(File.read(path))
  results.fetch(0).delete("artifactPaths")
  File.write(path, JSON.pretty_generate(results) + "\n")
' "$BEHAVIOR_DIAGNOSTIC_TAMPERED/results.json"
if "$BEHAVIOR_ARCHIVE_FIXTURE/scripts/archive-codex-behavioral-run.rb" \
  --run-dir "$BEHAVIOR_DIAGNOSTIC_TAMPERED" \
  --archive 2026-08-01-tampered-behavioral-diagnostic \
  --phase tampered > "$TEST_ROOT/behavior-archive-diagnostic-tampered.log" 2>&1; then
  fail "behavioral archiver accepted a missing response safety diagnostic"
fi
grep -q "result is missing required fields: artifactPaths" "$TEST_ROOT/behavior-archive-diagnostic-tampered.log" ||
  fail "behavioral archiver reported the wrong missing-diagnostic failure"
[[ ! -e "$BEHAVIOR_ARCHIVE_FIXTURE/evals/runs/2026-08-01-tampered-behavioral-diagnostic" ]] ||
  fail "behavioral archiver published evidence with missing response provenance"

BEHAVIOR_HANDOFF_PROVENANCE_TAMPERED="$TEST_ROOT/behavior-runner-handoff-provenance-tampered"
cp -R "$BEHAVIOR_FAKE_PASS" "$BEHAVIOR_HANDOFF_PROVENANCE_TAMPERED"
ruby -rjson -e '
  path = ARGV.fetch(0)
  results = JSON.parse(File.read(path))
  results.fetch(0).delete("evidenceHandoffContract")
  File.write(path, JSON.pretty_generate(results) + "\n")
' "$BEHAVIOR_HANDOFF_PROVENANCE_TAMPERED/results.json"
if "$BEHAVIOR_ARCHIVE_FIXTURE/scripts/archive-codex-behavioral-run.rb" \
  --run-dir "$BEHAVIOR_HANDOFF_PROVENANCE_TAMPERED" \
  --archive 2026-08-01-tampered-behavioral-handoff-provenance \
  --phase tampered > "$TEST_ROOT/behavior-archive-handoff-provenance-tampered.log" 2>&1; then
  fail "behavioral archiver accepted a missing runner handoff check"
fi
grep -q "result is missing required fields: evidenceHandoffContract" \
  "$TEST_ROOT/behavior-archive-handoff-provenance-tampered.log" ||
  fail "behavioral archiver reported the wrong missing handoff-provenance failure"
[[ ! -e "$BEHAVIOR_ARCHIVE_FIXTURE/evals/runs/2026-08-01-tampered-behavioral-handoff-provenance" ]] ||
  fail "behavioral archiver published evidence without runner handoff provenance"

BEHAVIOR_OUTPUT_BYTES_TAMPERED="$TEST_ROOT/behavior-runner-output-bytes-tampered"
cp -R "$BEHAVIOR_FAKE_PASS" "$BEHAVIOR_OUTPUT_BYTES_TAMPERED"
ruby -rjson -e '
  path = ARGV.fetch(0)
  results = JSON.parse(File.read(path))
  results.fetch(0)["hostOutputBytes"] += 1
  File.write(path, JSON.pretty_generate(results) + "\n")
' "$BEHAVIOR_OUTPUT_BYTES_TAMPERED/results.json"
if "$BEHAVIOR_ARCHIVE_FIXTURE/scripts/archive-codex-behavioral-run.rb" \
  --run-dir "$BEHAVIOR_OUTPUT_BYTES_TAMPERED" \
  --archive 2026-08-01-tampered-behavioral-output-bytes \
  --phase tampered > "$TEST_ROOT/behavior-archive-output-bytes-tampered.log" 2>&1; then
  fail "behavioral archiver accepted contradictory host-output bytes"
fi
grep -q "hostOutputBytes does not match retained host output" \
  "$TEST_ROOT/behavior-archive-output-bytes-tampered.log" ||
  fail "behavioral archiver reported the wrong output-byte failure"
[[ ! -e "$BEHAVIOR_ARCHIVE_FIXTURE/evals/runs/2026-08-01-tampered-behavioral-output-bytes" ]] ||
  fail "behavioral archiver published contradictory output-byte provenance"

BEHAVIOR_REVIEW_TAMPERED="$TEST_ROOT/behavior-runner-review-tampered"
cp -R "$BEHAVIOR_FAKE_PASS" "$BEHAVIOR_REVIEW_TAMPERED"
ruby -rjson -e '
  path = ARGV.fetch(0)
  review = JSON.parse(File.read(path))
  review.fetch("cases").fetch(0).fetch("criteria").fetch(0)["observed"] = false
  File.write(path, JSON.pretty_generate(review) + "\n")
' "$BEHAVIOR_REVIEW_TAMPERED/review.json"
if "$BEHAVIOR_ARCHIVE_FIXTURE/scripts/archive-codex-behavioral-run.rb" \
  --run-dir "$BEHAVIOR_REVIEW_TAMPERED" \
  --archive 2026-08-01-tampered-behavioral \
  --phase tampered > "$TEST_ROOT/behavior-archive-review-tampered.log" 2>&1; then
  fail "behavioral archiver accepted a pass that contradicted criterion review"
fi
grep -q "pass grade conflicts with observed criteria" "$TEST_ROOT/behavior-archive-review-tampered.log" || fail "behavioral archiver reported the wrong review failure"
[[ ! -e "$BEHAVIOR_ARCHIVE_FIXTURE/evals/runs/2026-08-01-tampered-behavioral" ]] || fail "behavioral archiver published contradictory review evidence"

BEHAVIOR_HANDOFF_TAMPERED="$TEST_ROOT/behavior-runner-handoff-tampered"
cp -R "$BEHAVIOR_FAKE_PASS" "$BEHAVIOR_HANDOFF_TAMPERED"
ruby -I "$ROOT/scripts/lib" -r evidence_handoff_contract -rjson -e '
  run_directory = ARGV.fetch(0)
  response_path = File.join(run_directory, "responses/market-competition-composite.txt")
  File.write(response_path, "fake complete behavioral answer without a handoff\n")
  results_path = File.join(run_directory, "results.json")
  results = JSON.parse(File.read(results_path))
  results.fetch(0)["evidenceHandoffContract"] = Zstack::EvidenceHandoffContract.evaluate([
    { name: "responses/market-competition-composite.txt", path: response_path }
  ])
  results.fetch(0)["hostOutputBytes"] = File.size(response_path) + File.size(File.join(run_directory, "logs/market-competition-composite.log"))
  File.write(results_path, JSON.pretty_generate(results) + "\n")
' "$BEHAVIOR_HANDOFF_TAMPERED"
if "$BEHAVIOR_ARCHIVE_FIXTURE/scripts/archive-codex-behavioral-run.rb" \
  --run-dir "$BEHAVIOR_HANDOFF_TAMPERED" \
  --archive 2026-08-01-tampered-handoff-behavioral \
  --phase tampered > "$TEST_ROOT/behavior-archive-handoff-tampered.log" 2>&1; then
  fail "behavioral archiver accepted a review that contradicted the mechanical handoff check"
fi
grep -q "Evidence handoff review contradicts the mechanical output check" "$TEST_ROOT/behavior-archive-handoff-tampered.log" || fail "behavioral archiver reported the wrong handoff-review failure"
[[ ! -e "$BEHAVIOR_ARCHIVE_FIXTURE/evals/runs/2026-08-01-tampered-handoff-behavioral" ]] || fail "behavioral archiver published contradictory handoff evidence"

BEHAVIOR_LOCAL_PATH_REVIEW="$TEST_ROOT/behavior-runner-local-path-review"
cp -R "$BEHAVIOR_FAKE_PASS" "$BEHAVIOR_LOCAL_PATH_REVIEW"
ruby -rjson -e '
  path = ARGV.fetch(0)
  review = JSON.parse(File.read(path))
  review.fetch("cases").fetch(0).fetch("criteria").fetch(0)["evidence"] = "Reviewed with /tmp/private-check.rb."
  File.write(path, JSON.pretty_generate(review) + "\n")
' "$BEHAVIOR_LOCAL_PATH_REVIEW/review.json"
if "$BEHAVIOR_ARCHIVE_FIXTURE/scripts/archive-codex-behavioral-run.rb" \
  --run-dir "$BEHAVIOR_LOCAL_PATH_REVIEW" \
  --archive 2026-08-01-local-path-review-behavioral \
  --phase tampered > "$TEST_ROOT/behavior-archive-local-path-review.log" 2>&1; then
  fail "behavioral archiver accepted a machine-local path in public review evidence"
fi
grep -q "evidence must not contain a machine-local path" "$TEST_ROOT/behavior-archive-local-path-review.log" || fail "behavioral archiver reported the wrong public-review path failure"
[[ ! -e "$BEHAVIOR_ARCHIVE_FIXTURE/evals/runs/2026-08-01-local-path-review-behavioral" ]] || fail "behavioral archiver published machine-local review evidence"

BEHAVIOR_SNAPSHOT_TAMPERED="$TEST_ROOT/behavior-runner-snapshot-tampered"
cp -R "$BEHAVIOR_FAKE_PASS" "$BEHAVIOR_SNAPSHOT_TAMPERED"
printf '%s\n' "snapshot drift" >> "$BEHAVIOR_SNAPSHOT_TAMPERED/skill-snapshots/z-market-validate/SKILL.md"
if "$BEHAVIOR_ARCHIVE_FIXTURE/scripts/archive-codex-behavioral-run.rb" \
  --run-dir "$BEHAVIOR_SNAPSHOT_TAMPERED" \
  --archive 2026-08-01-tampered-snapshot-behavioral \
  --phase tampered > "$TEST_ROOT/behavior-archive-snapshot-tampered.log" 2>&1; then
  fail "behavioral archiver accepted a changed skill snapshot"
fi
grep -q "snapshot byte count changed" "$TEST_ROOT/behavior-archive-snapshot-tampered.log" || fail "behavioral archiver reported the wrong snapshot-drift failure"
[[ ! -e "$BEHAVIOR_ARCHIVE_FIXTURE/evals/runs/2026-08-01-tampered-snapshot-behavioral" ]] || fail "behavioral archiver published changed snapshot evidence"

BEHAVIOR_SOURCE_DRIFT_FIXTURE="$(copy_fixture behavior-source-drift)"
printf '%s\n' "new source added after execution" > "$BEHAVIOR_SOURCE_DRIFT_FIXTURE/skills/z-market-validate/references/late-addition.md"
if "$BEHAVIOR_SOURCE_DRIFT_FIXTURE/scripts/archive-codex-behavioral-run.rb" \
  --run-dir "$BEHAVIOR_FAKE_PASS" \
  --archive 2026-08-01-source-drift-behavioral \
  --phase drift > "$TEST_ROOT/behavior-archive-source-drift.log" 2>&1; then
  fail "behavioral archiver accepted a snapshot missing a newly added source file"
fi
grep -q "current skill file inventory differs" "$TEST_ROOT/behavior-archive-source-drift.log" || fail "behavioral archiver reported the wrong source-inventory failure"
[[ ! -e "$BEHAVIOR_SOURCE_DRIFT_FIXTURE/evals/runs/2026-08-01-source-drift-behavioral" ]] || fail "behavioral archiver published stale source-inventory evidence"
pass "behavioral archiver atomically binds reviews, controls, snapshots, prompts, and responses"

BEHAVIOR_SOURCE_ENTRY_LIMIT_FIXTURE="$(copy_fixture behavior-source-entry-limit)"
ruby -e '
  root = ARGV.fetch(0)
  1_001.times { |index| Dir.mkdir(File.join(root, format("empty-%04d", index))) }
' "$BEHAVIOR_SOURCE_ENTRY_LIMIT_FIXTURE/skills/z-market-validate/references"
if "$BEHAVIOR_SOURCE_ENTRY_LIMIT_FIXTURE/scripts/archive-codex-behavioral-run.rb" \
  --run-dir "$BEHAVIOR_FAKE_PASS" \
  --archive 2026-08-01-source-entry-limit-behavioral \
  --phase limits > "$TEST_ROOT/behavior-archive-source-entry-limit.log" 2>&1; then
  fail "behavioral archiver accepted an unbounded current skill directory tree"
fi
grep -q "current skill source exceeds 1000 tree entries: z-market-validate" \
  "$TEST_ROOT/behavior-archive-source-entry-limit.log" ||
  fail "behavioral archiver reported the wrong skill-tree entry-limit failure"
[[ ! -e "$BEHAVIOR_SOURCE_ENTRY_LIMIT_FIXTURE/evals/runs/2026-08-01-source-entry-limit-behavioral" ]] ||
  fail "behavioral archiver published evidence after exceeding the skill-tree entry limit"
pass "behavioral archiver bounds direct current-skill tree enumeration"

BEHAVIOR_CASES_DRIFT_FIXTURE="$(copy_fixture behavior-archive-cases-drift)"
mv "$BEHAVIOR_CASES_DRIFT_FIXTURE/scripts/validate-evidence.rb" \
  "$BEHAVIOR_CASES_DRIFT_FIXTURE/scripts/validate-evidence.real.rb"
printf '%s\n' \
  '#!/usr/bin/env ruby' \
  'require "rbconfig"' \
  'real = File.expand_path("validate-evidence.real.rb", __dir__)' \
  'if ARGV.include?("--candidate")' \
  '  success = system(RbConfig.ruby, real, *ARGV)' \
  '  exit($?.exitstatus || 1) unless success' \
  '  File.open(File.expand_path("../evals/cases.yaml", __dir__), "a") { |file| file.write("\n# injected concurrent behavioral-case change\n") }' \
  '  exit 0' \
  'end' \
  'exec RbConfig.ruby, real, *ARGV' \
  > "$BEHAVIOR_CASES_DRIFT_FIXTURE/scripts/validate-evidence.rb"
chmod +x "$BEHAVIOR_CASES_DRIFT_FIXTURE/scripts/validate-evidence.rb"
if "$BEHAVIOR_CASES_DRIFT_FIXTURE/scripts/archive-codex-behavioral-run.rb" \
  --run-dir "$BEHAVIOR_FAKE_PASS" \
  --archive 2026-08-01-cases-drift-behavioral \
  --phase drift > "$TEST_ROOT/behavior-archive-cases-drift.log" 2>&1; then
  fail "behavioral archiver accepted a case manifest change during candidate validation"
fi
grep -q "evals/cases.yaml changed while archive was being prepared" \
  "$TEST_ROOT/behavior-archive-cases-drift.log" ||
  fail "behavioral archiver reported the wrong concurrent case-manifest failure"
[[ ! -e "$BEHAVIOR_CASES_DRIFT_FIXTURE/evals/runs/2026-08-01-cases-drift-behavioral" ]] ||
  fail "behavioral archiver published evidence against a changed case manifest"

BEHAVIOR_SKILL_DRIFT_FIXTURE="$(copy_fixture behavior-archive-skill-drift)"
mv "$BEHAVIOR_SKILL_DRIFT_FIXTURE/scripts/validate-evidence.rb" \
  "$BEHAVIOR_SKILL_DRIFT_FIXTURE/scripts/validate-evidence.real.rb"
BEHAVIOR_SKILL_DRIFT_COUNTER="$TEST_ROOT/behavior-archive-skill-drift-counter"
printf '%s\n' \
  '#!/usr/bin/env ruby' \
  'require "rbconfig"' \
  'counter = ENV.fetch("BEHAVIOR_SKILL_DRIFT_COUNTER")' \
  'count = File.exist?(counter) ? File.read(counter).to_i : 0' \
  'count += 1' \
  'File.write(counter, "#{count}\n")' \
  'real = File.expand_path("validate-evidence.real.rb", __dir__)' \
  'success = system(RbConfig.ruby, real, *ARGV)' \
  'exit($?.exitstatus || 1) unless success' \
  'if count == 3' \
  '  File.open(File.expand_path("../skills/z-market-validate/SKILL.md", __dir__), "a") { |file| file.write("\nConcurrent source drift.\n") }' \
  'end' \
  'exit 0' \
  > "$BEHAVIOR_SKILL_DRIFT_FIXTURE/scripts/validate-evidence.rb"
chmod +x "$BEHAVIOR_SKILL_DRIFT_FIXTURE/scripts/validate-evidence.rb"
if BEHAVIOR_SKILL_DRIFT_COUNTER="$BEHAVIOR_SKILL_DRIFT_COUNTER" \
  "$BEHAVIOR_SKILL_DRIFT_FIXTURE/scripts/archive-codex-behavioral-run.rb" \
  --run-dir "$BEHAVIOR_FAKE_PASS" \
  --archive 2026-08-01-skill-drift-behavioral \
  --phase drift > "$TEST_ROOT/behavior-archive-skill-drift.log" 2>&1; then
  fail "behavioral archiver accepted a current skill change during post-publish validation"
fi
grep -q "current skill source changed while archive was being prepared: z-market-validate" \
  "$TEST_ROOT/behavior-archive-skill-drift.log" ||
  fail "behavioral archiver reported the wrong concurrent skill-source failure"
[[ "$(cat "$BEHAVIOR_SKILL_DRIFT_COUNTER")" -eq 3 ]] ||
  fail "behavioral skill-drift fixture did not reach post-publish validation"
[[ ! -e "$BEHAVIOR_SKILL_DRIFT_FIXTURE/evals/runs/2026-08-01-skill-drift-behavioral" ]] ||
  fail "behavioral archiver left evidence published against changed skill source"
skill_drift_temps="$(find "$BEHAVIOR_SKILL_DRIFT_FIXTURE/evals/runs" -maxdepth 1 -name '.zstack-behavioral-archive-*' -print | wc -l | tr -d ' ')"
[[ "$skill_drift_temps" -eq 0 ]] || fail "behavioral archiver left a skill-drift transaction directory"
pass "behavioral archiver binds publication to one case manifest and current skill version"

BEHAVIOR_FAKE_EMPTY="$TEST_ROOT/behavior-runner-empty"
if FAKE_BEHAVIOR_EMPTY=1 "$ROOT/scripts/run-codex-behavioral-evals.rb" \
  --codex "$FAKE_BEHAVIOR_CODEX" \
  --case market-tools-blocked \
  --output "$BEHAVIOR_FAKE_EMPTY" > "$TEST_ROOT/behavior-runner-empty.log" 2>&1; then
  fail "behavioral runner accepted a missing final response"
fi
ruby -rjson -e '
  result = JSON.parse(File.read(ARGV.fetch(0))).fetch(0)
  abort "missing final response was not retained as an execution failure" if result.fetch("completed")
' "$BEHAVIOR_FAKE_EMPTY/results.json"

BEHAVIOR_NONEMPTY="$TEST_ROOT/behavior-runner-nonempty"
mkdir -p "$BEHAVIOR_NONEMPTY"
printf '%s\n' "keep me" > "$BEHAVIOR_NONEMPTY/owner.txt"
if "$ROOT/scripts/run-codex-behavioral-evals.rb" --dry-run --case market-tools-blocked --output "$BEHAVIOR_NONEMPTY" > "$TEST_ROOT/behavior-runner-nonempty.log" 2>&1; then
  fail "behavioral runner reused a non-empty output directory"
fi
grep -q "output directory must be empty" "$TEST_ROOT/behavior-runner-nonempty.log" || fail "behavioral runner reported the wrong output-reuse failure"
if "$ROOT/scripts/run-codex-behavioral-evals.rb" --dry-run --case missing-case > "$TEST_ROOT/behavior-runner-missing.log" 2>&1; then
  fail "behavioral runner accepted an unknown case selector"
fi
grep -q "unknown behavioral case" "$TEST_ROOT/behavior-runner-missing.log" || fail "behavioral runner reported the wrong unknown-case failure"
pass "behavioral runner fails closed on missing responses and unsafe selectors"

FAKE_ARTIFACT_CODEX="$TEST_ROOT/fake-artifact-codex"
printf '%s\n' \
  '#!/usr/bin/env ruby' \
  'require "fileutils"' \
  'if ARGV.first == "--version"' \
  '  puts "codex-cli fake-artifact-1.0"' \
  '  exit 0' \
  'end' \
  'exit 64 unless ARGV.first == "exec"' \
  'output = ARGV.fetch(ARGV.index("-o") + 1)' \
  'workspace = ARGV.fetch(ARGV.index("-C") + 1)' \
  'sandbox = ARGV.fetch(ARGV.index("-s") + 1)' \
  'exit 65 unless sandbox == "workspace-write"' \
  'exit 66 unless File.file?(File.join(workspace, ".zstack-skill/z-landing-smoke/SKILL.md"))' \
  'prompt = STDIN.read' \
  'unless ENV.fetch("FAKE_ARTIFACT_EMPTY", "0") == "1"' \
  '  path = File.join(workspace, "artifacts/landing/index.html")' \
  '  FileUtils.mkdir_p(File.dirname(path))' \
  '  File.write(path, "<!doctype html><title>Fake artifact</title>\n")' \
  '  File.binwrite(File.join(workspace, "artifacts/landing/og-card.png"), "\x89PNG\r\n\x1a\n\xff\x00".b)' \
  'end' \
  'if ENV.fetch("FAKE_ARTIFACT_FILE_LIMIT", "0") == "1"' \
  '  File.binwrite(File.join(workspace, "artifacts/landing/oversized.bin"), "\0" * (2 * 1024 * 1024 + 1))' \
  'end' \
  'if ENV.fetch("FAKE_ARTIFACT_COUNT_LIMIT", "0") == "1"' \
  '  directory = File.join(workspace, "artifacts/many")' \
  '  FileUtils.mkdir_p(directory)' \
  '  401.times { |index| File.write(File.join(directory, format("%03d.txt", index)), "") }' \
  'end' \
  'if ENV.fetch("FAKE_ARTIFACT_RUN_COUNT_LIMIT", "0") == "1"' \
  '  directory = File.join(workspace, "artifacts/many-run")' \
  '  FileUtils.mkdir_p(directory)' \
  '  250.times { |index| File.write(File.join(directory, format("%03d.txt", index)), "") }' \
  'end' \
  'if ENV.fetch("FAKE_ARTIFACT_ENTRY_LIMIT", "0") == "1"' \
  '  directory = File.join(workspace, "artifacts/many-directories")' \
  '  FileUtils.mkdir_p(directory)' \
  '  2_001.times { |index| Dir.mkdir(File.join(directory, format("%04d", index))) }' \
  'end' \
  'if ENV.fetch("FAKE_ARTIFACT_UNSAFE_PATH", "0") == "1"' \
  '  File.write(File.join(workspace, "artifacts/landing/unsafe\nname.txt"), "unsafe path\n")' \
  'end' \
  'if ENV.fetch("FAKE_ARTIFACT_TOTAL_LIMIT", "0") == "1"' \
  '  directory = File.join(workspace, "artifacts/large")' \
  '  FileUtils.mkdir_p(directory)' \
  '  4.times { |index| File.binwrite(File.join(directory, "part-#{index}.bin"), "\0" * (2 * 1024 * 1024)) }' \
  'end' \
  'if ENV.fetch("FAKE_ARTIFACT_RUNTIME_LIMIT", "0") == "1"' \
  '  directory = File.join(workspace, "artifacts/runtime-large")' \
  '  FileUtils.mkdir_p(directory)' \
  '  5.times { |index| File.binwrite(File.join(directory, "part-#{index}.bin"), "\0" * (2 * 1024 * 1024)) }' \
  '  sleep 10' \
  'end' \
  'File.write(File.join(workspace, "outside.txt"), "escape\n") if ENV.fetch("FAKE_ARTIFACT_OUTSIDE", "0") == "1"' \
  'handoff = "\n\n| Field | Value |\n|---|---|\n| Current decision | Validate first |\n| Evidence classes | assumption |\n| Supported claims | The fixture ran |\n| Still unproven | Product demand |\n| Contradictions / exclusions | None supplied |\n| Source anchors | Fixture response |\n| Next validation | Run a real test |"' \
  'response = ENV.fetch("FAKE_ARTIFACT_PRIVATE_RESPONSE", "0") == "1" ? "artifact at #{workspace}/artifacts/landing/index.html" : "fake artifact behavioral answer#{handoff}"' \
  'File.write(output, response + "\n")' \
  'puts "OpenAI Codex vfake-artifact-1.0"' \
  'puts "--------"' \
  'puts "workdir: #{workspace}"' \
  'puts "model: gpt-5.6-sol"' \
  'puts "approval: never"' \
  'puts "sandbox: workspace-write [workdir, /tmp, $TMPDIR]"' \
  'puts "reasoning effort: medium"' \
  'puts "user"' \
  'puts prompt' \
  'puts "codex"' \
  'puts response' > "$FAKE_ARTIFACT_CODEX"
chmod +x "$FAKE_ARTIFACT_CODEX"

ARTIFACT_FAKE_PASS="$TEST_ROOT/artifact-runner-pass"
"$ROOT/scripts/run-codex-behavioral-evals.rb" \
  --codex "$FAKE_ARTIFACT_CODEX" \
  --case smoke-complete-pack \
  --output "$ARTIFACT_FAKE_PASS" > "$TEST_ROOT/artifact-runner-pass.log"
ruby -rjson -e '
  controls = JSON.parse(File.read(ARGV.fetch(0)))
  result = JSON.parse(File.read(ARGV.fetch(1))).fetch(0)
  abort "artifact runner did not select workspace-write" unless controls.fetch("executionMode") == "artifact" && controls.fetch("sandbox") == "workspace-write"
  expected_limits = [400, 2 * 1024 * 1024, 8 * 1024 * 1024, 2_000, 400, 8 * 1024 * 1024, 1, true, true]
  actual_limits = %w[maxArtifactFilesPerCase maxArtifactFileBytes maxArtifactBytesPerCase maxArtifactTreeEntriesPerCase maxArtifactFilesPerRun maxArtifactBytesPerRun maxArtifactJobs artifactRuntimeMonitoring artifactManifestFromCapturedBytes].map { |field| controls.fetch(field) }
  abort "artifact runner did not record its capture limits" unless actual_limits == expected_limits
  runtime_limits = %w[maxRuntimeGitFiles maxRuntimeGitTreeEntries maxRuntimeGitBytes maxRuntimeHostHomeFiles maxRuntimeHostHomeTreeEntries maxRuntimeHostHomeBytes].map { |field| controls.fetch(field) }
  abort "artifact runner omitted private-tree runtime limits" unless runtime_limits == [100, 500, 2 * 1024 * 1024, 200, 500, 8 * 1024 * 1024]
  abort "artifact runner did not complete" unless result.fetch("completed") && result.fetch("artifactError").nil?
  abort "artifact runner did not validate the Evidence handoff" unless result.dig("evidenceHandoffContract", "passed") == true
  abort "artifact runner lost its retained files" unless result.fetch("artifactPaths") == ["artifacts/smoke-complete-pack/landing/index.html", "artifacts/smoke-complete-pack/landing/og-card.png"]
' "$ARTIFACT_FAKE_PASS/controls.json" "$ARTIFACT_FAKE_PASS/results.json"
grep -q 'artifacts/smoke-complete-pack/landing/index.html' "$ARTIFACT_FAKE_PASS/artifact-manifest.txt" || fail "artifact runner manifest omitted the retained page"

ARTIFACT_RETAINED_DRIFT_FIXTURE="$(copy_fixture artifact-retained-drift)"
mv "$ARTIFACT_RETAINED_DRIFT_FIXTURE/scripts/lib/eval_input_file.rb" \
  "$ARTIFACT_RETAINED_DRIFT_FIXTURE/scripts/lib/eval_input_file_real.rb"
printf '%s\n' \
  '# frozen_string_literal: true' \
  'require_relative "eval_input_file_real"' \
  'module Zstack' \
  '  module EvalInputFile' \
  '    class << self' \
  '      alias_method :zstack_original_read_for_retained_artifact_drift_test, :read' \
  '      def read(path, **options)' \
  '        if options[:label] == "retained artifact" && path.end_with?("/landing/index.html")' \
  '          @zstack_retained_artifact_reads = @zstack_retained_artifact_reads.to_i + 1' \
  '          File.binwrite(path, "retained artifact drift\n") if @zstack_retained_artifact_reads == 2' \
  '        end' \
  '        zstack_original_read_for_retained_artifact_drift_test(path, **options)' \
  '      end' \
  '    end' \
  '  end' \
  'end' \
  > "$ARTIFACT_RETAINED_DRIFT_FIXTURE/scripts/lib/eval_input_file.rb"
ARTIFACT_RETAINED_DRIFT_OUTPUT="$TEST_ROOT/artifact-retained-drift-output"
if "$ARTIFACT_RETAINED_DRIFT_FIXTURE/scripts/run-codex-behavioral-evals.rb" \
  --codex "$FAKE_ARTIFACT_CODEX" \
  --case smoke-complete-pack \
  --output "$ARTIFACT_RETAINED_DRIFT_OUTPUT" > "$TEST_ROOT/artifact-retained-drift.log" 2>&1; then
  fail "artifact runner accepted retained artifact drift before manifest publication"
fi
grep -q "retained artifact changed after capture: artifacts/smoke-complete-pack/landing/index.html" \
  "$TEST_ROOT/artifact-retained-drift.log" ||
  fail "artifact runner reported the wrong retained artifact drift"
[[ ! -e "$ARTIFACT_RETAINED_DRIFT_OUTPUT/artifact-manifest.txt" ]] ||
  fail "artifact runner published a manifest after retained artifact drift"
pass "artifact manifests remain bound to captured in-memory bytes after host monitoring"

ARTIFACT_RUNTIME_LIMIT="$TEST_ROOT/artifact-runner-runtime-limit"
if FAKE_ARTIFACT_RUNTIME_LIMIT=1 "$ROOT/scripts/run-codex-behavioral-evals.rb" \
  --codex "$FAKE_ARTIFACT_CODEX" \
  --case smoke-complete-pack \
  --jobs 32 \
  --timeout-seconds 10 \
  --output "$ARTIFACT_RUNTIME_LIMIT" > "$TEST_ROOT/artifact-runner-runtime-limit.log" 2>&1; then
  fail "artifact runner accepted a live workspace above its whole-run byte budget"
fi
ruby -rjson -e '
  controls = JSON.parse(File.read(ARGV.fetch(0)))
  result = JSON.parse(File.read(ARGV.fetch(1))).fetch(0)
  abort "artifact runtime monitor did not force one job" unless controls.fetch("jobs") == 1 && controls.fetch("maxArtifactJobs") == 1
  abort "artifact runtime overflow was marked complete" if result.fetch("completed")
  error = result.fetch("workspaceLimitError")
  abort "artifact runtime limit reason was lost" unless error.include?("artifact run exceeds 8388608 retained bytes")
  abort "artifact runtime watchdog waited for the case timeout" unless result.fetch("elapsedSeconds") < 4
' "$ARTIFACT_RUNTIME_LIMIT/controls.json" "$ARTIFACT_RUNTIME_LIMIT/results.json"
grep -q "artifact execution forces --jobs 1" "$TEST_ROOT/artifact-runner-runtime-limit.log" ||
  fail "artifact runner did not disclose its forced monitored concurrency"
pass "artifact runner enforces whole-run file budgets during model execution"

ruby -rjson -e '
  path = ARGV.fetch(0)
  review = JSON.parse(File.read(path))
  review["reviewer"] = "integration-test artifact review"
  review.fetch("cases").each do |entry|
    entry["grade"] = "pass"
    entry.fetch("criteria").each do |criterion|
      criterion["observed"] = criterion.fetch("expectation") == "present"
      criterion["evidence"] = "Fake artifact and response were reviewed against this criterion."
    end
  end
  File.write(path, JSON.pretty_generate(review) + "\n")
' "$ARTIFACT_FAKE_PASS/review.json"

ARTIFACT_ARCHIVE_FIXTURE="$(copy_fixture artifact-behavior-archive)"
"$ARTIFACT_ARCHIVE_FIXTURE/scripts/archive-codex-behavioral-run.rb" \
  --run-dir "$ARTIFACT_FAKE_PASS" \
  --archive 2026-08-01-fake-artifact-behavioral \
  --phase fake-artifact > "$TEST_ROOT/artifact-behavior-archive.log"
ARTIFACT_ARCHIVE="$ARTIFACT_ARCHIVE_FIXTURE/evals/runs/2026-08-01-fake-artifact-behavioral"
[[ -f "$ARTIFACT_ARCHIVE/raw/artifacts/smoke-complete-pack/landing/index.html" ]] || fail "behavioral archiver omitted the retained deployable page"
[[ -f "$ARTIFACT_ARCHIVE/raw/artifacts/smoke-complete-pack/landing/og-card.png" ]] || fail "behavioral archiver omitted the retained binary artifact"
grep -q 'raw/artifacts/smoke-complete-pack/landing/index.html' "$ARTIFACT_ARCHIVE/archive-manifest.txt" || fail "archive manifest omitted the retained deployable page"
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV.fetch(0)))
  defaults = data.fetch("executionDefaults")
  expected = [400, 2 * 1024 * 1024, 8 * 1024 * 1024, 2_000, 400, 8 * 1024 * 1024, 1, true, true]
  actual = %w[maxArtifactFilesPerCase maxArtifactFileBytes maxArtifactBytesPerCase maxArtifactTreeEntriesPerCase maxArtifactFilesPerRun maxArtifactBytesPerRun maxArtifactJobs artifactRuntimeMonitoring artifactManifestFromCapturedBytes].map { |field| defaults.fetch(field) }
  abort "artifact archive omitted capture-limit provenance" unless actual == expected
  runtime = %w[maxRuntimeGitFiles maxRuntimeGitTreeEntries maxRuntimeGitBytes maxRuntimeHostHomeFiles maxRuntimeHostHomeTreeEntries maxRuntimeHostHomeBytes].map { |field| defaults.fetch(field) }
  abort "artifact archive omitted private-tree runtime limits" unless defaults.fetch("concurrentRuntimeMonitoring") == true && defaults.fetch("pidMonitoringStartsAtSpawn") == true &&
    defaults.fetch("sharedRootMonitoring") == true && defaults.fetch("privatePromptIntegrityMonitoring") == false &&
    defaults.fetch("outputDirectoryIdentityMonitoring") == true &&
    runtime == [100, 500, 2 * 1024 * 1024, 200, 500, 8 * 1024 * 1024]
  output_runtime = %w[maxRuntimeOutputFiles maxRuntimeOutputTreeEntries maxRuntimeOutputBytes].map { |field| defaults.fetch(field) }
  abort "artifact archive omitted output-tree runtime limits" unless defaults.fetch("outputTreeMonitoring") == true &&
    defaults.fetch("exclusiveRunnerOutputs") == true &&
    defaults.fetch("workspaceViolationStopsRun") == true &&
    defaults.fetch("copiedSkillIntegrityMonitoring") == true &&
    defaults.fetch("singleLinkInputFiles") == true &&
    defaults.fetch("singleLinkRuntimeFiles") == true &&
    output_runtime == [4_096, 8_192, 640 * 1024 * 1024]
' "$ARTIFACT_ARCHIVE/run.json"
ruby "$ARTIFACT_ARCHIVE_FIXTURE/scripts/validate-evidence.rb" >/dev/null

ARTIFACT_LIMIT_TAMPERED="$TEST_ROOT/artifact-runner-limit-tampered"
cp -R "$ARTIFACT_FAKE_PASS" "$ARTIFACT_LIMIT_TAMPERED"
ruby -rjson -e '
  path = ARGV.fetch(0)
  controls = JSON.parse(File.read(path))
  controls["maxArtifactBytesPerCase"] = 1
  File.write(path, JSON.pretty_generate(controls) + "\n")
' "$ARTIFACT_LIMIT_TAMPERED/controls.json"
if "$ARTIFACT_ARCHIVE_FIXTURE/scripts/archive-codex-behavioral-run.rb" \
  --run-dir "$ARTIFACT_LIMIT_TAMPERED" \
  --archive 2026-08-01-tampered-artifact-limits \
  --phase tampered > "$TEST_ROOT/artifact-limit-tampered.log" 2>&1; then
  fail "artifact archiver accepted tampered capture limits"
fi
grep -q "artifact limits must match the runner safety limits" "$TEST_ROOT/artifact-limit-tampered.log" ||
  fail "artifact archiver reported the wrong capture-limit failure"
[[ ! -e "$ARTIFACT_ARCHIVE_FIXTURE/evals/runs/2026-08-01-tampered-artifact-limits" ]] ||
  fail "artifact archiver published tampered capture-limit provenance"

ARTIFACT_TAMPERED="$TEST_ROOT/artifact-runner-tampered"
cp -R "$ARTIFACT_FAKE_PASS" "$ARTIFACT_TAMPERED"
printf '%s\n' '<!-- changed -->' >> "$ARTIFACT_TAMPERED/artifacts/smoke-complete-pack/landing/index.html"
if "$ARTIFACT_ARCHIVE_FIXTURE/scripts/archive-codex-behavioral-run.rb" \
  --run-dir "$ARTIFACT_TAMPERED" \
  --archive 2026-08-01-tampered-artifact-behavioral \
  --phase tampered > "$TEST_ROOT/artifact-behavior-tampered.log" 2>&1; then
  fail "behavioral archiver accepted a changed retained artifact"
fi
grep -q "artifact byte count changed" "$TEST_ROOT/artifact-behavior-tampered.log" || fail "artifact archiver reported the wrong byte-drift failure"

ARTIFACT_ENTRY_LIMIT_TAMPERED="$TEST_ROOT/artifact-runner-entry-limit-tampered"
cp -R "$ARTIFACT_FAKE_PASS" "$ARTIFACT_ENTRY_LIMIT_TAMPERED"
ruby -e '
  root = ARGV.fetch(0)
  Dir.mkdir(root)
  2_001.times { |index| Dir.mkdir(File.join(root, format("%04d", index))) }
' "$ARTIFACT_ENTRY_LIMIT_TAMPERED/artifacts/smoke-complete-pack/many-directories"
if "$ARTIFACT_ARCHIVE_FIXTURE/scripts/archive-codex-behavioral-run.rb" \
  --run-dir "$ARTIFACT_ENTRY_LIMIT_TAMPERED" \
  --archive 2026-08-01-tampered-artifact-entry-limit \
  --phase tampered > "$TEST_ROOT/artifact-entry-limit-tampered.log" 2>&1; then
  fail "behavioral archiver accepted an artifact tree above its entry limit"
fi
grep -q "artifact tree exceeds 2000 entries: smoke-complete-pack" \
  "$TEST_ROOT/artifact-entry-limit-tampered.log" ||
  fail "behavioral archiver reported the wrong artifact-tree entry-limit failure"
[[ ! -e "$ARTIFACT_ARCHIVE_FIXTURE/evals/runs/2026-08-01-tampered-artifact-entry-limit" ]] ||
  fail "behavioral archiver published an artifact tree above its entry limit"

for artifact_failure in \
  empty:FAKE_ARTIFACT_EMPTY \
  outside:FAKE_ARTIFACT_OUTSIDE \
  file-limit:FAKE_ARTIFACT_FILE_LIMIT \
  count-limit:FAKE_ARTIFACT_COUNT_LIMIT \
  entry-limit:FAKE_ARTIFACT_ENTRY_LIMIT \
  unsafe-path:FAKE_ARTIFACT_UNSAFE_PATH \
  total-limit:FAKE_ARTIFACT_TOTAL_LIMIT; do
  failure_name="${artifact_failure%%:*}"
  env_name="${artifact_failure#*:}"
  failure_dir="$TEST_ROOT/artifact-runner-$failure_name"
  if env "$env_name=1" "$ROOT/scripts/run-codex-behavioral-evals.rb" \
    --codex "$FAKE_ARTIFACT_CODEX" \
    --case smoke-complete-pack \
    --output "$failure_dir" > "$TEST_ROOT/artifact-runner-$failure_name.log" 2>&1; then
    fail "artifact runner accepted $failure_name output"
  fi
  ruby -rjson -e '
    result = JSON.parse(File.read(ARGV.fetch(0))).fetch(0)
    abort "artifact failure was marked complete" if result.fetch("completed")
    errors = [result["artifactError"], result["workspaceLimitError"]].compact
    abort "artifact failure reason was lost" unless errors.any? { |error| error.is_a?(String) && !error.empty? }
  ' "$failure_dir/results.json"
done
ruby -rjson -e '
  expected = {
    "file-limit" => "artifact file exceeds 2097152 bytes",
    "count-limit" => "workspace output has more than 400 regular files",
    "entry-limit" => "workspace output has more than 2000 tree entries",
    "unsafe-path" => "artifact path must be canonical portable UTF-8",
    "total-limit" => "artifact case exceeds 8388608 total bytes"
  }
  expected.each do |name, fragment|
    result = JSON.parse(File.read(File.join(ARGV.fetch(0), "artifact-runner-#{name}", "results.json"))).fetch(0)
    errors = [result["artifactError"], result["workspaceLimitError"]].compact
    unless errors.any? { |error| error.include?(fragment) } ||
           (name == "count-limit" && errors.any? { |error| error.include?("artifact run exceeds 400 retained files") }) ||
           (name == "total-limit" && errors.any? { |error| error.include?("artifact run exceeds 8388608 retained bytes") })
      abort "#{name} reported the wrong artifact limit: #{errors.join("; ")}"
    end
  end
' "$TEST_ROOT"
pass "artifact runner bounds retained file bytes, total bytes, and file count"

ARTIFACT_RUN_LIMIT_FIXTURE="$(copy_fixture artifact-run-whole-limit)"
ruby -ryaml -e '
  path = ARGV.fetch(0)
  document = YAML.safe_load(File.read(path), permitted_classes: [], aliases: false)
  source = document.fetch("cases").find { |entry| entry.fetch("id") == "smoke-complete-pack" }
  duplicate = Marshal.load(Marshal.dump(source))
  duplicate["id"] = "smoke-second-artifact"
  duplicate["prompt"] = "Create a second synthetic deployable smoke-test artifact."
  document.fetch("cases") << duplicate
  File.write(path, YAML.dump(document))
' "$ARTIFACT_RUN_LIMIT_FIXTURE/evals/cases.yaml"
ARTIFACT_RUN_LIMIT_OUTPUT="$TEST_ROOT/artifact-runner-whole-limit"
if FAKE_ARTIFACT_RUN_COUNT_LIMIT=1 \
  "$ARTIFACT_RUN_LIMIT_FIXTURE/scripts/run-codex-behavioral-evals.rb" \
  --codex "$FAKE_ARTIFACT_CODEX" \
  --case smoke-complete-pack \
  --case smoke-second-artifact \
  --output "$ARTIFACT_RUN_LIMIT_OUTPUT" > "$TEST_ROOT/artifact-runner-whole-limit.log" 2>&1; then
  fail "artifact runner accepted per-case-valid files above the whole-run limit"
fi
ruby -rjson -e '
  results = JSON.parse(File.read(ARGV.fetch(0)))
  abort "whole-run artifact fixture lost a completed first case" unless results.fetch(0).fetch("completed")
  overflow = results.fetch(1)
  abort "whole-run artifact overflow was marked complete" if overflow.fetch("completed")
  error = overflow["artifactError"] || overflow["workspaceLimitError"]
  abort "whole-run artifact limit reason was lost" unless error&.include?("artifact run exceeds 400 retained files")
  abort "whole-run artifact paths exceeded the recorded cap" if results.sum { |entry| entry.fetch("artifactPaths").length } > 400
' "$ARTIFACT_RUN_LIMIT_OUTPUT/results.json"
pass "artifact runner applies file and byte budgets across the whole invocation"
ARTIFACT_PRIVATE_RESPONSE="$TEST_ROOT/artifact-runner-private-response"
if FAKE_ARTIFACT_PRIVATE_RESPONSE=1 "$ROOT/scripts/run-codex-behavioral-evals.rb" \
  --codex "$FAKE_ARTIFACT_CODEX" \
  --case smoke-complete-pack \
  --output "$ARTIFACT_PRIVATE_RESPONSE" > "$TEST_ROOT/artifact-runner-private-response.log" 2>&1; then
  fail "artifact runner accepted a private workspace path in the final response"
fi
ruby -rjson -e '
  result = JSON.parse(File.read(ARGV.fetch(0))).fetch(0)
  abort "private response was marked complete" if result.fetch("completed")
  abort "private response reason was lost" unless result.fetch("responsePrivacyError") == "final response contains a private workspace path"
' "$ARTIFACT_PRIVATE_RESPONSE/results.json"
if "$ROOT/scripts/run-codex-behavioral-evals.rb" --dry-run \
  --case smoke-complete-pack --case market-tools-blocked > "$TEST_ROOT/artifact-mixed-mode.log" 2>&1; then
  fail "behavioral runner mixed response and artifact cases"
fi
grep -q "select response and artifact cases in separate" "$TEST_ROOT/artifact-mixed-mode.log" || fail "behavioral runner reported the wrong mixed-mode failure"
ARTIFACT_FILTER_DRY="$TEST_ROOT/artifact-filter-dry"
"$ROOT/scripts/run-codex-behavioral-evals.rb" --dry-run \
  --execution artifact --output "$ARTIFACT_FILTER_DRY" > "$TEST_ROOT/artifact-filter-dry.log"
[[ -f "$ARTIFACT_FILTER_DRY/prompts/smoke-complete-pack.txt" ]] || fail "artifact execution filter omitted its registered case"
grep -q 'below 8 KiB' "$ARTIFACT_FILTER_DRY/prompts/smoke-complete-pack.txt" || fail "artifact runner omitted its bounded-write reliability guidance"
ruby -rjson -e 'abort "artifact default timeout drifted" unless JSON.parse(File.read(ARGV.fetch(0))).fetch("timeoutSecondsPerCase") == 1200' "$ARTIFACT_FILTER_DRY/controls.json"
[[ "$(find "$ARTIFACT_FILTER_DRY/prompts" -type f | wc -l | tr -d ' ')" == "1" ]] || fail "artifact execution filter retained response cases"
if "$ROOT/scripts/run-codex-behavioral-evals.rb" --dry-run \
  --execution response --case smoke-complete-pack > "$TEST_ROOT/artifact-filter-empty.log" 2>&1; then
  fail "behavioral execution filter accepted a mismatched explicit case"
fi
grep -q "no behavioral cases matched --execution response" "$TEST_ROOT/artifact-filter-empty.log" || fail "behavioral execution filter reported the wrong empty-selection failure"
pass "artifact behavioral mode retains only hashed in-boundary deliverables"

FAKE_BEHAVIOR_CLAUDE="$TEST_ROOT/fake-behavior-claude"
printf '%s\n' \
  '#!/usr/bin/env ruby' \
  'require "fileutils"' \
  'require "json"' \
  'if ARGV.first == "--version"' \
  '  puts "2.1.999 (Claude Code)"' \
  '  exit 0' \
  'end' \
  'exit 64 unless ARGV.first == "-p"' \
  'market = File.file?(File.join(Dir.pwd, ".zstack-skill/z-market-validate/SKILL.md"))' \
  'landing = File.file?(File.join(Dir.pwd, ".zstack-skill/z-landing-smoke/SKILL.md"))' \
  'exit 65 unless market || landing' \
  'prompt = STDIN.read' \
  'skill = landing ? "z-landing-smoke" : "z-market-validate"' \
  'exit 66 unless prompt.include?(".zstack-skill/#{skill}/SKILL.md")' \
  'api_error = ENV.fetch("FAKE_CLAUDE_API_ERROR", "0") == "1"' \
  'if landing && !api_error' \
  '  artifact = File.join(Dir.pwd, "artifacts/landing/index.html")' \
  '  FileUtils.mkdir_p(File.dirname(artifact))' \
  '  File.write(artifact, "<!doctype html><title>Fake Claude artifact</title>\n")' \
  'end' \
  'handoff = "\n\n| Field | Value |\n|---|---|\n| Current decision | Validate first |\n| Evidence classes | assumption |\n| Supported claims | The fixture ran |\n| Still unproven | Product demand |\n| Contradictions / exclusions | None supplied |\n| Source anchors | Fixture response |\n| Next validation | Run a real test |"' \
  'answer = (landing ? "Created artifacts/landing/index.html" : "fake Claude behavioral answer") + handoff' \
  'data = {' \
  '  "type" => "result", "subtype" => "success", "is_error" => api_error,' \
  '  "result" => api_error ? "There is an issue with the selected model (private-fake-model)." : answer,' \
  '  "api_error_status" => api_error ? 404 : nil,' \
  '  "modelUsage" => api_error ? {} : { "claude-fake-1" => { "costUSD" => 0.01 } },' \
  '  "num_turns" => api_error ? 1 : 2, "stop_reason" => api_error ? "stop_sequence" : "end_turn",' \
  '  "terminal_reason" => "completed", "total_cost_usd" => api_error ? 0 : 0.01,' \
  '  "permission_denials" => [], "session_id" => "private-fake-session"' \
  '}' \
  'puts JSON.generate(data)' > "$FAKE_BEHAVIOR_CLAUDE"
chmod +x "$FAKE_BEHAVIOR_CLAUDE"

CLAUDE_BEHAVIOR_FAKE_PASS="$TEST_ROOT/claude-behavior-runner-pass"
"$ROOT/scripts/run-claude-behavioral-evals.rb" \
  --claude "$FAKE_BEHAVIOR_CLAUDE" \
  --model claude-requested-alias \
  --case market-tools-blocked \
  --output "$CLAUDE_BEHAVIOR_FAKE_PASS" > "$TEST_ROOT/claude-behavior-runner-pass.log"
ruby -rjson -e '
  controls = JSON.parse(File.read(ARGV.fetch(0)))
  result = JSON.parse(File.read(ARGV.fetch(1))).fetch(0)
  invocation = JSON.parse(File.read(ARGV.fetch(2)))
  abort "Claude runner did not record safe-mode controls" unless controls.fetch("host") == "Claude Code" && controls.fetch("safeMode") && controls.fetch("allowedTools") == ["Read"]
  abort "Claude runner did not record the actual model" unless result.fetch("actualModels") == ["claude-fake-1"]
  abort "Claude runner lost turn or stop provenance" unless result.fetch("numTurns") == 2 && result.fetch("stopReason") == "end_turn"
  abort "Claude runner did not retain a completed execution" unless result.fetch("completed") && result.fetch("exitStatus") == 0
  args = invocation.fetch("arguments")
  abort "Claude runner omitted safe mode from its invocation" unless args.include?("--safe-mode")
  tools_index = args.index("--tools")
  abort "Claude runner tool allowlist changed" unless tools_index && args.fetch(tools_index + 1) == "Read"
' "$CLAUDE_BEHAVIOR_FAKE_PASS/controls.json" "$CLAUDE_BEHAVIOR_FAKE_PASS/results.json" "$CLAUDE_BEHAVIOR_FAKE_PASS/logs/market-tools-blocked.invocation.json"
ruby -rjson -e '
  path = ARGV.fetch(0)
  review = JSON.parse(File.read(path))
  review["reviewer"] = "integration-test Claude semantic review"
  review.fetch("cases").each do |entry|
    entry["grade"] = "pass"
    entry.fetch("criteria").each do |criterion|
      criterion["observed"] = criterion.fetch("expectation") == "present"
      criterion["evidence"] = "Fake Claude response was reviewed against this criterion."
    end
  end
  File.write(path, JSON.pretty_generate(review) + "\n")
' "$CLAUDE_BEHAVIOR_FAKE_PASS/review.json"

CLAUDE_BEHAVIOR_ARCHIVE_FIXTURE="$(copy_fixture claude-behavior-archive)"
"$CLAUDE_BEHAVIOR_ARCHIVE_FIXTURE/scripts/archive-claude-behavioral-run.rb" \
  --run-dir "$CLAUDE_BEHAVIOR_FAKE_PASS" \
  --archive 2026-08-01-fake-claude-behavioral \
  --phase fake-claude > "$TEST_ROOT/claude-behavior-archive.log"
CLAUDE_BEHAVIOR_ARCHIVE="$CLAUDE_BEHAVIOR_ARCHIVE_FIXTURE/evals/runs/2026-08-01-fake-claude-behavioral"
ruby -rjson -e '
  run = JSON.parse(File.read(ARGV.fetch(0)))
  entry = run.fetch("runs").fetch(0)
  abort "Claude archive recorded the wrong host" unless run.dig("host", "name") == "Claude Code"
  abort "Claude archive lost actual model or turns" unless entry.fetch("model") == "claude-fake-1" && entry.fetch("turns") == 2
' "$CLAUDE_BEHAVIOR_ARCHIVE/run.json"
if find "$CLAUDE_BEHAVIOR_ARCHIVE" -type f \( -name '*.invocation.json' -o -path '*/logs/*' \) | grep -q .; then
  fail "Claude behavioral archiver copied private invocation or host-result records"
fi
ruby "$CLAUDE_BEHAVIOR_ARCHIVE_FIXTURE/scripts/validate-evidence.rb" >/dev/null

CLAUDE_ARTIFACT_FAKE_PASS="$TEST_ROOT/claude-artifact-runner-pass"
"$ROOT/scripts/run-claude-behavioral-evals.rb" \
  --claude "$FAKE_BEHAVIOR_CLAUDE" \
  --model claude-requested-alias \
  --case smoke-complete-pack \
  --output "$CLAUDE_ARTIFACT_FAKE_PASS" > "$TEST_ROOT/claude-artifact-runner-pass.log"
ruby -rjson -e '
  controls = JSON.parse(File.read(ARGV.fetch(0)))
  result = JSON.parse(File.read(ARGV.fetch(1))).fetch(0)
  invocation = JSON.parse(File.read(ARGV.fetch(2)))
  abort "Claude artifact runner lost its write controls" unless controls.fetch("executionMode") == "artifact" && controls.fetch("sandbox") == "workspace-write" && controls.fetch("allowedTools") == %w[Read Write Edit]
  abort "Claude artifact runner did not retain its exact file" unless result.fetch("completed") && result.fetch("artifactPaths") == ["artifacts/smoke-complete-pack/landing/index.html"]
  args = invocation.fetch("arguments")
  tools_index = args.index("--tools")
  abort "Claude artifact invocation changed its tool allowlist" unless tools_index && args.fetch(tools_index + 1) == "Read,Write,Edit"
' "$CLAUDE_ARTIFACT_FAKE_PASS/controls.json" "$CLAUDE_ARTIFACT_FAKE_PASS/results.json" "$CLAUDE_ARTIFACT_FAKE_PASS/logs/smoke-complete-pack.invocation.json"
ruby -rjson -e '
  path = ARGV.fetch(0)
  review = JSON.parse(File.read(path))
  review["reviewer"] = "integration-test Claude artifact review"
  review.fetch("cases").each do |entry|
    entry["grade"] = "pass"
    entry.fetch("criteria").each do |criterion|
      criterion["observed"] = criterion.fetch("expectation") == "present"
      criterion["evidence"] = "Fake Claude artifact and response were reviewed against this criterion."
    end
  end
  File.write(path, JSON.pretty_generate(review) + "\n")
' "$CLAUDE_ARTIFACT_FAKE_PASS/review.json"
"$CLAUDE_BEHAVIOR_ARCHIVE_FIXTURE/scripts/archive-claude-behavioral-run.rb" \
  --run-dir "$CLAUDE_ARTIFACT_FAKE_PASS" \
  --archive 2026-08-01-fake-claude-artifact \
  --phase fake-claude-artifact > "$TEST_ROOT/claude-artifact-archive.log"
CLAUDE_ARTIFACT_ARCHIVE="$CLAUDE_BEHAVIOR_ARCHIVE_FIXTURE/evals/runs/2026-08-01-fake-claude-artifact"
ruby -rjson -e '
  run = JSON.parse(File.read(ARGV.fetch(0)))
  entry = run.fetch("runs").fetch(0)
  abort "Claude artifact archive recorded the wrong execution mode" unless run.dig("executionDefaults", "executionMode") == "artifact"
  abort "Claude artifact archive lost exact permissions" unless run.dig("executionDefaults", "permissions") == "safe mode; Read, Write, and Edit tools only; writes limited by prompt and post-run audit to artifacts/; permission mode dontAsk"
  abort "Claude artifact archive lost actual model provenance" unless entry.fetch("model") == "claude-fake-1" && entry.fetch("turns") == 2
' "$CLAUDE_ARTIFACT_ARCHIVE/run.json"
[[ -f "$CLAUDE_ARTIFACT_ARCHIVE/raw/artifacts/smoke-complete-pack/landing/index.html" ]] || fail "Claude artifact archive omitted the exact retained deliverable"
if find "$CLAUDE_ARTIFACT_ARCHIVE" -type f \( -name '*.invocation.json' -o -path '*/logs/*' \) | grep -q .; then
  fail "Claude artifact archiver copied private invocation or host-result records"
fi
ruby "$CLAUDE_BEHAVIOR_ARCHIVE_FIXTURE/scripts/validate-evidence.rb" >/dev/null

CLAUDE_BEHAVIOR_INVOCATION_TAMPERED="$TEST_ROOT/claude-behavior-invocation-tampered"
cp -R "$CLAUDE_BEHAVIOR_FAKE_PASS" "$CLAUDE_BEHAVIOR_INVOCATION_TAMPERED"
ruby -rjson -e '
  path = ARGV.fetch(0)
  invocation = JSON.parse(File.read(path))
  invocation.fetch("arguments").delete("--safe-mode")
  File.write(path, JSON.pretty_generate(invocation) + "\n")
' "$CLAUDE_BEHAVIOR_INVOCATION_TAMPERED/logs/market-tools-blocked.invocation.json"
if "$CLAUDE_BEHAVIOR_ARCHIVE_FIXTURE/scripts/archive-claude-behavioral-run.rb" \
  --run-dir "$CLAUDE_BEHAVIOR_INVOCATION_TAMPERED" \
  --archive 2026-08-01-tampered-claude-behavioral \
  --phase tampered > "$TEST_ROOT/claude-behavior-invocation-tampered.log" 2>&1; then
  fail "Claude behavioral archiver accepted changed invocation controls"
fi
grep -q "invocation arguments do not match" "$TEST_ROOT/claude-behavior-invocation-tampered.log" || fail "Claude archiver reported the wrong invocation-tamper failure"

CLAUDE_BEHAVIOR_API_ERROR="$TEST_ROOT/claude-behavior-api-error"
if FAKE_CLAUDE_API_ERROR=1 "$ROOT/scripts/run-claude-behavioral-evals.rb" \
  --claude "$FAKE_BEHAVIOR_CLAUDE" \
  --case market-tools-blocked \
  --output "$CLAUDE_BEHAVIOR_API_ERROR" > "$TEST_ROOT/claude-behavior-api-error.log" 2>&1; then
  fail "Claude behavioral runner accepted is_error=true with a zero CLI exit"
fi
ruby -rjson -e '
  result = JSON.parse(File.read(ARGV.fetch(0))).fetch(0)
  abort "Claude API error was not retained as an execution failure" if result.fetch("completed")
  abort "Claude API error flag was lost" unless result.fetch("isError") == true
  abort "Claude API status was lost" unless result.fetch("apiErrorStatus") == 404
  abort "Claude API error was not safely classified" unless result.fetch("errorCategory") == "model-unavailable"
  abort "Claude API error was exposed as a semantic response" if File.exist?(ARGV.fetch(1))
' "$CLAUDE_BEHAVIOR_API_ERROR/results.json" "$CLAUDE_BEHAVIOR_API_ERROR/responses/market-tools-blocked.txt"
grep -q 'EXECUTION-FAILED (model-unavailable; HTTP 404)' "$TEST_ROOT/claude-behavior-api-error.log" || fail "Claude runner omitted its safe API failure diagnosis"
if grep -q 'private-fake-model' "$TEST_ROOT/claude-behavior-api-error.log"; then
  fail "Claude runner leaked the provider error text into console output"
fi
pass "Claude behavioral adapter fails closed and archives only corroborated private provenance"

FAKE_BEHAVIOR_GROK="$TEST_ROOT/fake-behavior-grok"
printf '%s\n' \
  '#!/usr/bin/env ruby' \
  'require "fileutils"' \
  'require "json"' \
  'if ARGV.first == "--version"' \
  '  puts "grok 0.2.999 (fakegrok)"' \
  '  exit 0' \
  'end' \
  'prompt_path = ARGV.fetch(ARGV.index("--prompt-file") + 1)' \
  'workspace = ARGV.fetch(ARGV.index("--cwd") + 1)' \
  'sandbox = ARGV.fetch(ARGV.index("--sandbox") + 1)' \
  'tools = ARGV.fetch(ARGV.index("--tools") + 1)' \
  'permission = ARGV.fetch(ARGV.index("--permission-mode") + 1)' \
  'exit 64 unless File.file?(File.join(ENV.fetch("GROK_HOME"), "config.toml"))' \
  'exit 65 unless File.expand_path(ENV.fetch("GROK_AUTH_PATH")).start_with?("/")' \
  'exit 66 unless ENV["GROK_MANAGED_MCPS_ENABLED"] == "0" && ENV["GROK_OFFICIAL_MARKETPLACE_AUTO_REGISTER"] == "0"' \
  'market = File.file?(File.join(workspace, ".zstack-skill/z-market-validate/SKILL.md"))' \
  'landing = File.file?(File.join(workspace, ".zstack-skill/z-landing-smoke/SKILL.md"))' \
  'exit 67 unless market || landing' \
  'exit 68 unless sandbox == (landing ? "workspace" : "read-only")' \
  'exit 69 unless tools == (landing ? "Read,Write,Edit" : "Read")' \
  'exit 72 unless permission == (landing ? "bypassPermissions" : "dontAsk")' \
  'exit 70 unless STDIN.read.empty?' \
  'exit 73 unless prompt_path == "/dev/fd/9" && File.stat(prompt_path).nlink == 0' \
  'prompt = File.read(prompt_path)' \
  'skill = landing ? "z-landing-smoke" : "z-market-validate"' \
  'exit 71 unless prompt.include?(".zstack-skill/#{skill}/SKILL.md")' \
  'api_error = ENV.fetch("FAKE_GROK_API_ERROR", "0") == "1"' \
  'if landing && !api_error' \
  '  artifact = File.join(workspace, "artifacts/landing/index.html")' \
  '  FileUtils.mkdir_p(File.dirname(artifact))' \
  '  File.write(artifact, "<!doctype html><title>Fake Grok artifact</title>\n")' \
  'end' \
  'if api_error' \
  '  puts JSON.generate({ "type" => "error", "message" => "Unauthorized (401) from https://example.invalid: no auth context; private fake credential detail" })' \
  'else' \
  '  handoff = "\n\n| Field | Value |\n|---|---|\n| Current decision | Validate first |\n| Evidence classes | assumption |\n| Supported claims | The fixture ran |\n| Still unproven | Product demand |\n| Contradictions / exclusions | None supplied |\n| Source anchors | Fixture response |\n| Next validation | Run a real test |"' \
  '  answer = (landing ? "Created artifacts/landing/index.html" : "fake Grok behavioral answer") + handoff' \
  '  answer += "\nprivate token #{File.basename(workspace)}" if ENV.fetch("FAKE_GROK_LEAK_TOKEN", "0") == "1"' \
  '  text = ENV.fetch("FAKE_GROK_MISSING_MARKER", "0") == "1" ? answer : "private behavioral tool narration\nZSTACK_FINAL_RESPONSE_V1\n#{answer}"' \
  '  data = {' \
  '    "text" => text, "stopReason" => "end_turn",' \
  '    "sessionId" => "private-fake-session", "requestId" => "private-fake-request",' \
  '    "thought" => "private fake thought",' \
  '    "usage" => { "input_tokens" => 100, "output_tokens" => 20, "reasoning_tokens" => 5, "total_tokens" => 125 },' \
  '    "num_turns" => 2, "total_cost_usd" => 0.02,' \
  '    "modelUsage" => { "grok-fake-1" => { "inputTokens" => 100, "outputTokens" => 20, "modelCalls" => 1, "costUSD" => 0.02 } }' \
  '  }' \
  '  puts JSON.generate(data)' \
  'end' \
  'warn "fake Grok private stderr"' > "$FAKE_BEHAVIOR_GROK"
chmod +x "$FAKE_BEHAVIOR_GROK"

GROK_BEHAVIOR_FAKE_PASS="$TEST_ROOT/grok-behavior-runner-pass"
"$ROOT/scripts/run-grok-behavioral-evals.rb" \
  --grok "$FAKE_BEHAVIOR_GROK" \
  --model grok-requested-alias \
  --reasoning low \
  --case market-tools-blocked \
  --output "$GROK_BEHAVIOR_FAKE_PASS" > "$TEST_ROOT/grok-behavior-runner-pass.log"
ruby -rjson -e '
  controls = JSON.parse(File.read(ARGV.fetch(0)))
  result = JSON.parse(File.read(ARGV.fetch(1))).fetch(0)
  invocation = JSON.parse(File.read(ARGV.fetch(2)))
  abort "Grok runner lost its isolation controls" unless controls.fetch("host") == "Grok Build" && controls.fetch("isolatedHostHome") && controls.fetch("sandbox") == "read-only" && controls.fetch("allowedTools") == ["Read"]
  abort "Grok runner omitted private prompt monitoring" unless controls.fetch("pidMonitoringStartsAtSpawn") == true && controls.fetch("sharedRootMonitoring") == true && controls.fetch("privatePromptIntegrityMonitoring") == true && controls.fetch("anonymousPromptDescriptor") == true && controls.fetch("promptDescriptorPath") == "/dev/fd/9"
  abort "Grok runner omitted copied skill integrity monitoring" unless controls.fetch("copiedSkillIntegrityMonitoring") == true
  abort "Grok runner omitted output identity monitoring" unless controls.fetch("outputDirectoryIdentityMonitoring") == true
  abort "Grok behavioral turn budget regressed" unless controls.fetch("maxTurnsPerCase") == 8
  abort "Grok runner omitted opaque private identifiers" unless controls.fetch("privateCaseIdentifiers").include?("random opaque 128-bit tokens")
  marker = controls.fetch("finalResponseBoundary")
  abort "Grok behavioral final-response marker changed" unless marker == "ZSTACK_FINAL_RESPONSE_V1" && controls.fetch("systemPromptOverride").include?(marker)
  abort "Grok runner omitted its ambient-skill disclosure" unless controls.fetch("ambientAgentSkillsMayBeDiscovered") == true
  abort "Grok runner did not record the actual model" unless result.fetch("actualModels") == ["grok-fake-1"]
  abort "Grok runner lost turn, stop, or token provenance" unless result.fetch("numTurns") == 2 && result.fetch("stopReason") == "end_turn" && result.dig("tokenUsage", "total_tokens") == 125
  abort "Grok runner did not retain a completed execution" unless result.fetch("completed") && result.fetch("exitStatus") == 0
  abort "Grok runner lost final-boundary provenance" unless result.fetch("prefinalNarrationBytes").positive? && result.fetch("finalBoundaryError").nil?
  response = File.read(ARGV.fetch(3))
  abort "Grok behavioral response retained private narration or marker" if response.include?("private behavioral tool narration") || response.include?(marker)
  args = invocation.fetch("arguments")
  prompt_index = args.index("--prompt-file")
  token = invocation.fetch("privateCaseToken")
  abort "Grok behavioral private token is malformed" unless token.match?(/\Acase-[0-9a-f]{32}\z/)
  abort "Grok workspace leaked its semantic case id" unless File.basename(invocation.fetch("workspace")) == token && !invocation.fetch("workspace").include?("market-tools-blocked")
  private_prompt = prompt_index && args.fetch(prompt_index + 1)
  abort "Grok runner did not transport exact prompt bytes through its inherited anonymous descriptor" unless private_prompt == "/dev/fd/9"
  tools_index = args.index("--tools")
  abort "Grok runner tool allowlist changed" unless tools_index && args.fetch(tools_index + 1) == "Read"
  turns_index = args.index("--max-turns")
  abort "Grok runner invocation lost its default turn budget" unless turns_index && args.fetch(turns_index + 1) == "8"
  env = invocation.fetch("environment")
  abort "Grok runner lost its private auth indirection" unless env.fetch("GROK_AUTH_PATH").start_with?("/") && env.fetch("GROK_HOME").include?("zstack-grok-behavioral-workspaces-") && File.basename(env.fetch("GROK_HOME")) == token
' "$GROK_BEHAVIOR_FAKE_PASS/controls.json" "$GROK_BEHAVIOR_FAKE_PASS/results.json" "$GROK_BEHAVIOR_FAKE_PASS/logs/market-tools-blocked.invocation.json" "$GROK_BEHAVIOR_FAKE_PASS/responses/market-tools-blocked.txt"
ruby -rjson -e '
  path = ARGV.fetch(0)
  review = JSON.parse(File.read(path))
  review["reviewer"] = "integration-test Grok semantic review"
  review.fetch("cases").each do |entry|
    entry["grade"] = "pass"
    entry.fetch("criteria").each do |criterion|
      criterion["observed"] = criterion.fetch("expectation") == "present"
      criterion["evidence"] = "Fake Grok response was reviewed against this criterion."
    end
  end
  File.write(path, JSON.pretty_generate(review) + "\n")
' "$GROK_BEHAVIOR_FAKE_PASS/review.json"

GROK_BEHAVIOR_ARCHIVE_FIXTURE="$(copy_fixture grok-behavior-archive)"
"$GROK_BEHAVIOR_ARCHIVE_FIXTURE/scripts/archive-grok-behavioral-run.rb" \
  --run-dir "$GROK_BEHAVIOR_FAKE_PASS" \
  --archive 2026-08-01-fake-grok-behavioral \
  --phase fake-grok > "$TEST_ROOT/grok-behavior-archive.log"
GROK_BEHAVIOR_ARCHIVE="$GROK_BEHAVIOR_ARCHIVE_FIXTURE/evals/runs/2026-08-01-fake-grok-behavioral"
ruby -rjson -e '
  run = JSON.parse(File.read(ARGV.fetch(0)))
  entry = run.fetch("runs").fetch(0)
  abort "Grok archive recorded the wrong host" unless run.dig("host", "name") == "Grok Build" && run.dig("host", "version") == "0.2.999" && run.dig("host", "revision") == "fakegrok"
  abort "Grok archive lost actual model or turns" unless entry.fetch("model") == "grok-fake-1" && entry.fetch("turns") == 2
  abort "Grok archive lost the token record" unless entry.dig("tokenUsage", "total_tokens") == 125
  abort "Grok archive lost its ambient-skill disclosure" unless run.dig("executionDefaults", "ambientAgentSkillsMayBeDiscovered") == true
  abort "Grok archive omitted discarded narration incidents" unless run.fetch("runnerIncidents").any? { |incident| incident.include?("discarded") && incident.include?("pre-final narration bytes") }
' "$GROK_BEHAVIOR_ARCHIVE/run.json"
grep -q "standard Agent Skills hub" "$GROK_BEHAVIOR_ARCHIVE/summary.md" || fail "Grok archive summary omitted the host discovery limitation"
if find "$GROK_BEHAVIOR_ARCHIVE" -type f \( -name '*.invocation.json' -o -path '*/logs/*' \) | grep -q .; then
  fail "Grok behavioral archiver copied private invocation or host-result records"
fi
ruby "$GROK_BEHAVIOR_ARCHIVE_FIXTURE/scripts/validate-evidence.rb" >/dev/null

GROK_BEHAVIOR_PROVENANCE_TAMPERED="$TEST_ROOT/grok-behavior-provenance-tampered"
cp -R "$GROK_BEHAVIOR_FAKE_PASS" "$GROK_BEHAVIOR_PROVENANCE_TAMPERED"
ruby -rjson -e '
  path = ARGV.fetch(0)
  results = JSON.parse(File.read(path))
  results.fetch(0).delete("errorType")
  File.write(path, JSON.pretty_generate(results) + "\n")
' "$GROK_BEHAVIOR_PROVENANCE_TAMPERED/results.json"
if "$GROK_BEHAVIOR_ARCHIVE_FIXTURE/scripts/archive-grok-behavioral-run.rb" \
  --run-dir "$GROK_BEHAVIOR_PROVENANCE_TAMPERED" \
  --archive 2026-08-01-tampered-grok-behavior-provenance \
  --phase tampered > "$TEST_ROOT/grok-behavior-provenance-tampered.log" 2>&1; then
  fail "Grok behavioral archiver accepted missing host provenance"
fi
grep -q "structured-host result is missing required fields: errorType" \
  "$TEST_ROOT/grok-behavior-provenance-tampered.log" ||
  fail "Grok behavioral archiver reported the wrong missing-provenance failure"

GROK_BEHAVIOR_BOUNDARY_TAMPERED="$TEST_ROOT/grok-behavior-boundary-tampered"
cp -R "$GROK_BEHAVIOR_FAKE_PASS" "$GROK_BEHAVIOR_BOUNDARY_TAMPERED"
ruby -rjson -e '
  run_directory = ARGV.fetch(0)
  path = File.join(run_directory, "logs/market-tools-blocked.json")
  raw = JSON.parse(File.read(path))
  raw["text"] = raw.fetch("text").sub("ZSTACK_FINAL_RESPONSE_V1\n", "")
  File.write(path, JSON.pretty_generate(raw) + "\n")
  results_path = File.join(run_directory, "results.json")
  results = JSON.parse(File.read(results_path))
  results.fetch(0)["hostOutputBytes"] = File.size(path) + File.size(File.join(run_directory, "logs/market-tools-blocked.log"))
  File.write(results_path, JSON.pretty_generate(results) + "\n")
' "$GROK_BEHAVIOR_BOUNDARY_TAMPERED"
if "$GROK_BEHAVIOR_ARCHIVE_FIXTURE/scripts/archive-grok-behavioral-run.rb" \
  --run-dir "$GROK_BEHAVIOR_BOUNDARY_TAMPERED" \
  --archive 2026-08-01-tampered-grok-behavior-boundary \
  --phase tampered > "$TEST_ROOT/grok-behavior-boundary-tampered.log" 2>&1; then
  fail "Grok behavioral archiver accepted a raw result without its final-response marker"
fi
grep -q "must contain exactly one final-response marker" "$TEST_ROOT/grok-behavior-boundary-tampered.log" || fail "Grok behavioral archiver reported the wrong final-boundary tamper failure"

GROK_ARTIFACT_FAKE_PASS="$TEST_ROOT/grok-artifact-runner-pass"
"$ROOT/scripts/run-grok-behavioral-evals.rb" \
  --grok "$FAKE_BEHAVIOR_GROK" \
  --model grok-requested-alias \
  --reasoning low \
  --case smoke-complete-pack \
  --output "$GROK_ARTIFACT_FAKE_PASS" > "$TEST_ROOT/grok-artifact-runner-pass.log"
ruby -rjson -e '
  controls = JSON.parse(File.read(ARGV.fetch(0)))
  result = JSON.parse(File.read(ARGV.fetch(1))).fetch(0)
  invocation = JSON.parse(File.read(ARGV.fetch(2)))
  abort "Grok artifact runner lost its write controls" unless controls.fetch("executionMode") == "artifact" && controls.fetch("sandbox") == "workspace" && controls.fetch("approvalPolicy") == "bypassPermissions" && controls.fetch("allowedTools") == %w[Read Write Edit]
  abort "Grok artifact runner did not retain its exact file" unless result.fetch("completed") && result.fetch("artifactPaths") == ["artifacts/smoke-complete-pack/landing/index.html"]
  args = invocation.fetch("arguments")
  tools_index = args.index("--tools")
  abort "Grok artifact invocation changed its tool allowlist" unless tools_index && args.fetch(tools_index + 1) == "Read,Write,Edit"
' "$GROK_ARTIFACT_FAKE_PASS/controls.json" "$GROK_ARTIFACT_FAKE_PASS/results.json" "$GROK_ARTIFACT_FAKE_PASS/logs/smoke-complete-pack.invocation.json"
ruby -rjson -e '
  path = ARGV.fetch(0)
  review = JSON.parse(File.read(path))
  review["reviewer"] = "integration-test Grok artifact review"
  review.fetch("cases").each do |entry|
    entry["grade"] = "pass"
    entry.fetch("criteria").each do |criterion|
      criterion["observed"] = criterion.fetch("expectation") == "present"
      criterion["evidence"] = "Fake Grok artifact and response were reviewed against this criterion."
    end
  end
  File.write(path, JSON.pretty_generate(review) + "\n")
' "$GROK_ARTIFACT_FAKE_PASS/review.json"
"$GROK_BEHAVIOR_ARCHIVE_FIXTURE/scripts/archive-grok-behavioral-run.rb" \
  --run-dir "$GROK_ARTIFACT_FAKE_PASS" \
  --archive 2026-08-01-fake-grok-artifact \
  --phase fake-grok-artifact > "$TEST_ROOT/grok-artifact-archive.log"
GROK_ARTIFACT_ARCHIVE="$GROK_BEHAVIOR_ARCHIVE_FIXTURE/evals/runs/2026-08-01-fake-grok-artifact"
[[ -f "$GROK_ARTIFACT_ARCHIVE/raw/artifacts/smoke-complete-pack/landing/index.html" ]] || fail "Grok artifact archive omitted the exact retained deliverable"
ruby -rjson -e '
  run = JSON.parse(File.read(ARGV.fetch(0)))
  expected = "workspace sandbox; Read, Write, and Edit tools only; writes limited by prompt and post-run audit to artifacts/; permission mode bypassPermissions"
  abort "Grok artifact archive lost exact sandbox permissions" unless run.dig("executionDefaults", "permissions") == expected
' "$GROK_ARTIFACT_ARCHIVE/run.json"
ruby "$GROK_BEHAVIOR_ARCHIVE_FIXTURE/scripts/validate-evidence.rb" >/dev/null

GROK_BEHAVIOR_TOKEN_TAMPERED="$TEST_ROOT/grok-behavior-token-tampered"
cp -R "$GROK_BEHAVIOR_FAKE_PASS" "$GROK_BEHAVIOR_TOKEN_TAMPERED"
ruby -rjson -e '
  path = ARGV.fetch(0)
  invocation = JSON.parse(File.read(path))
  invocation["privateCaseToken"] = "case-00000000000000000000000000000000"
  File.write(path, JSON.pretty_generate(invocation) + "\n")
' "$GROK_BEHAVIOR_TOKEN_TAMPERED/logs/market-tools-blocked.invocation.json"
if "$GROK_BEHAVIOR_ARCHIVE_FIXTURE/scripts/archive-grok-behavioral-run.rb" \
  --run-dir "$GROK_BEHAVIOR_TOKEN_TAMPERED" \
  --archive 2026-08-01-tampered-grok-private-token \
  --phase tampered > "$TEST_ROOT/grok-behavior-token-tampered.log" 2>&1; then
  fail "Grok behavioral archiver accepted a tampered private case token"
fi
grep -q "workspace is not the isolated case workspace" "$TEST_ROOT/grok-behavior-token-tampered.log" || fail "Grok archiver reported the wrong private-token tamper failure"

GROK_BEHAVIOR_INVOCATION_TAMPERED="$GROK_BEHAVIOR_FAKE_PASS"
ruby -rjson -e '
  path = ARGV.fetch(0)
  invocation = JSON.parse(File.read(path))
  invocation.fetch("environment")["GROK_MANAGED_MCPS_ENABLED"] = "1"
  File.write(path, JSON.pretty_generate(invocation) + "\n")
' "$GROK_BEHAVIOR_INVOCATION_TAMPERED/logs/market-tools-blocked.invocation.json"
if "$GROK_BEHAVIOR_ARCHIVE_FIXTURE/scripts/archive-grok-behavioral-run.rb" \
  --run-dir "$GROK_BEHAVIOR_INVOCATION_TAMPERED" \
  --archive 2026-08-01-tampered-grok-behavioral \
  --phase tampered > "$TEST_ROOT/grok-behavior-invocation-tampered.log" 2>&1; then
  fail "Grok behavioral archiver accepted changed environment controls"
fi
grep -q "environment isolation flags changed" "$TEST_ROOT/grok-behavior-invocation-tampered.log" || fail "Grok archiver reported the wrong environment-tamper failure"

GROK_BEHAVIOR_API_ERROR="$TEST_ROOT/grok-behavior-api-error"
if FAKE_GROK_API_ERROR=1 "$ROOT/scripts/run-grok-behavioral-evals.rb" \
  --grok "$FAKE_BEHAVIOR_GROK" \
  --case market-tools-blocked \
  --output "$GROK_BEHAVIOR_API_ERROR" > "$TEST_ROOT/grok-behavior-api-error.log" 2>&1; then
  fail "Grok behavioral runner accepted type=error with a zero CLI exit"
fi
ruby -rjson -e '
  result = JSON.parse(File.read(ARGV.fetch(0))).fetch(0)
  abort "Grok API error was not retained as an execution failure" if result.fetch("completed")
  abort "Grok API error flag was lost" unless result.fetch("isError") == true
  abort "Grok API error was not safely classified" unless result.fetch("apiErrorStatus") == 401 && result.fetch("errorCategory") == "authentication"
  abort "Grok API error was exposed as a semantic response" if File.exist?(ARGV.fetch(1))
' "$GROK_BEHAVIOR_API_ERROR/results.json" "$GROK_BEHAVIOR_API_ERROR/responses/market-tools-blocked.txt"
grep -q 'EXECUTION-FAILED (authentication; HTTP 401)' "$TEST_ROOT/grok-behavior-api-error.log" || fail "Grok runner omitted its safe API failure diagnosis"
if grep -q 'private fake credential detail' "$TEST_ROOT/grok-behavior-api-error.log"; then
  fail "Grok runner leaked the provider error text into console output"
fi

GROK_BEHAVIOR_MISSING_MARKER="$TEST_ROOT/grok-behavior-missing-marker"
if FAKE_GROK_MISSING_MARKER=1 "$ROOT/scripts/run-grok-behavioral-evals.rb" \
  --grok "$FAKE_BEHAVIOR_GROK" \
  --case market-tools-blocked \
  --output "$GROK_BEHAVIOR_MISSING_MARKER" > "$TEST_ROOT/grok-behavior-missing-marker.log" 2>&1; then
  fail "Grok behavioral runner accepted a result without its final-response marker"
fi
ruby -rjson -e '
  result = JSON.parse(File.read(ARGV.fetch(0))).fetch(0)
  abort "missing Grok marker was not retained as an execution failure" if result.fetch("completed")
  abort "missing Grok marker was not safely classified" unless result.fetch("errorCategory") == "final-boundary-invalid" && result.fetch("finalBoundaryError") == "missing-final-marker"
  abort "unmarked Grok text was exposed as a semantic response" if File.exist?(ARGV.fetch(1))
' "$GROK_BEHAVIOR_MISSING_MARKER/results.json" "$GROK_BEHAVIOR_MISSING_MARKER/responses/market-tools-blocked.txt"

GROK_BEHAVIOR_TOKEN_LEAK="$TEST_ROOT/grok-behavior-token-leak"
if FAKE_GROK_LEAK_TOKEN=1 "$ROOT/scripts/run-grok-behavioral-evals.rb" \
  --grok "$FAKE_BEHAVIOR_GROK" \
  --case market-tools-blocked \
  --output "$GROK_BEHAVIOR_TOKEN_LEAK" > "$TEST_ROOT/grok-behavior-token-leak.log" 2>&1; then
  fail "Grok behavioral runner accepted a leaked private case token"
fi
ruby -rjson -e '
  result = JSON.parse(File.read(ARGV.fetch(0))).fetch(0)
  abort "private token leak was not retained as an execution failure" if result.fetch("completed")
  abort "private token leak was not diagnosed" unless result.fetch("responsePrivacyError") == "final response contains a private workspace path"
' "$GROK_BEHAVIOR_TOKEN_LEAK/results.json"
pass "Grok behavioral adapter isolates host state and archives corroborated response and artifact evidence"

INSTALL_FIXTURE="$(copy_fixture install)"
[[ ! -e "$INSTALL_FIXTURE/evals/runs" ]] || fail "mutation fixture copied immutable run archives"
pass "mutation fixtures omit immutable run archives"

SETUP_TEMP_REPLACEMENT_HOME="$TEST_ROOT/setup-temp-replacement-home"
SETUP_TEMP_REPLACEMENT_COUNTER="$TEST_ROOT/setup-temp-replacement-counter"
SETUP_TEMP_REPLACEMENT_RECORD="$TEST_ROOT/setup-temp-replacement-record"
SETUP_TEMP_REPLACEMENT_MOVED="$TEST_ROOT/setup-temp-replacement-moved"
if (
  ZSTACK_REAL_MKTEMP="$(command -v mktemp)"
  export ZSTACK_REAL_MKTEMP SETUP_TEMP_REPLACEMENT_HOME \
    SETUP_TEMP_REPLACEMENT_COUNTER SETUP_TEMP_REPLACEMENT_RECORD \
    SETUP_TEMP_REPLACEMENT_MOVED
  # Invoked indirectly by the child Bash after export.
  # shellcheck disable=SC2329
  mktemp() {
    local argument path first count=0
    for argument in "$@"; do
      [[ "$argument" == "$SETUP_TEMP_REPLACEMENT_HOME/.zstack/"* ]] || continue
      [[ -f "$SETUP_TEMP_REPLACEMENT_COUNTER" ]] && count="$(cat "$SETUP_TEMP_REPLACEMENT_COUNTER")"
      count=$((count + 1))
      printf '%s\n' "$count" > "$SETUP_TEMP_REPLACEMENT_COUNTER"
      if [[ "$count" -eq 1 ]]; then
        path="$("$ZSTACK_REAL_MKTEMP" "$@")" || return
        printf '%s\n' "$path" > "$SETUP_TEMP_REPLACEMENT_RECORD"
        printf '%s\n' "$path"
        return 0
      fi
      first="$(cat "$SETUP_TEMP_REPLACEMENT_RECORD")"
      mv "$first" "$SETUP_TEMP_REPLACEMENT_MOVED"
      printf '%s\n' 'replacement setup temp must survive' > "$first"
      return 74
    done
    "$ZSTACK_REAL_MKTEMP" "$@"
  }
  export -f mktemp
  HOME="$SETUP_TEMP_REPLACEMENT_HOME" "$INSTALL_FIXTURE/scripts/setup.sh" --hosts agents \
    > "$TEST_ROOT/setup-temp-replacement.log" 2>&1
); then
  fail "setup accepted a failed state transaction allocation"
fi
SETUP_TEMP_REPLACEMENT_PATH="$(cat "$SETUP_TEMP_REPLACEMENT_RECORD")"
grep -qx 'replacement setup temp must survive' "$SETUP_TEMP_REPLACEMENT_PATH" ||
  fail "setup trap removed a replacement transaction file"
[[ -f "$SETUP_TEMP_REPLACEMENT_MOVED" ]] || fail "setup trap lost its displaced transaction file"
[[ ! -e "$SETUP_TEMP_REPLACEMENT_HOME/.zstack/operations.lock" ]] ||
  fail "setup temp allocation failure left the operation lock"
rm -f "$SETUP_TEMP_REPLACEMENT_PATH" "$SETUP_TEMP_REPLACEMENT_MOVED"
pass "setup state transactions clean temporary files by captured identity"

awk '
  /^  - id: z-seo-plan$/ { target = 1 }
  target && /^    status: active$/ { $0 = "    status: draft"; target = 0 }
  { print }
' "$INSTALL_FIXTURE/catalog.yaml" > "$INSTALL_FIXTURE/catalog.yaml.next"
mv "$INSTALL_FIXTURE/catalog.yaml.next" "$INSTALL_FIXTURE/catalog.yaml"
route_fixture_skill_to_none "$INSTALL_FIXTURE" z-seo-plan
awk '
  /^  - id:/ { in_write_prd = ($0 == "  - id: z-write-prd") }
  in_write_prd && /^      - codex$/ { next }
  { print }
' "$INSTALL_FIXTURE/catalog.yaml" > "$INSTALL_FIXTURE/catalog.yaml.next"
mv "$INSTALL_FIXTURE/catalog.yaml.next" "$INSTALL_FIXTURE/catalog.yaml"

OPTIONAL_HOME="$TEST_ROOT/optional-home"
HOME="$OPTIONAL_HOME" "$INSTALL_FIXTURE/scripts/setup.sh" > "$TEST_ROOT/default-hosts.log" 2>&1
grep -q '^zstack doctor ' "$TEST_ROOT/default-hosts.log" || fail "setup did not validate source before installing"
[[ -L "$OPTIONAL_HOME/.agents/skills/z-market-validate" ]] || fail "default setup omitted the Agent Skills hub"
[[ -L "$OPTIONAL_HOME/.claude/skills/z-market-validate" ]] || fail "default setup omitted Claude Code"
[[ ! -e "$OPTIONAL_HOME/.codex/skills/z-market-validate" ]] || fail "default setup installed the legacy Codex root"
[[ ! -e "$OPTIONAL_HOME/.grok/skills/z-market-validate" ]] || fail "default setup installed the optional Grok root"
grep -q "codex (disabled)" "$TEST_ROOT/default-hosts.log" || fail "default setup did not report the disabled Codex profile"
grep -q "grok (disabled)" "$TEST_ROOT/default-hosts.log" || fail "default setup did not report the disabled Grok profile"
pass "default setup installs only current required discovery roots"

HOME="$OPTIONAL_HOME" "$INSTALL_FIXTURE/scripts/setup.sh" --hosts grok > "$TEST_ROOT/optional-grok.log" 2>&1
[[ -L "$OPTIONAL_HOME/.grok/skills/z-market-validate" ]] || fail "explicit host selection did not enable the optional Grok profile"
grep -q "explicit opt-in" "$TEST_ROOT/optional-grok.log" || fail "optional host install was not labeled as explicit opt-in"
HOME="$OPTIONAL_HOME" "$INSTALL_FIXTURE/scripts/setup.sh" >/dev/null
[[ -L "$OPTIONAL_HOME/.grok/skills/z-market-validate" ]] || fail "default setup changed an unselected optional host"
HOME="$OPTIONAL_HOME" "$INSTALL_FIXTURE/scripts/unlink.sh" >/dev/null
pass "explicit host selection enables and preserves optional profiles"

ENUMERATION_HOME="$TEST_ROOT/enumeration-home"
ENUMERATION_LINK="$ENUMERATION_HOME/.agents/skills/z-market-validate"
mkdir -p "$ENUMERATION_HOME/.agents/skills" "$ENUMERATION_HOME/.zstack"
ln -s "$INSTALL_FIXTURE/skills/z-market-validate" "$ENUMERATION_LINK"
printf '%s|%s\n' "$INSTALL_FIXTURE" "$ENUMERATION_LINK" > "$ENUMERATION_HOME/.zstack/links"
printf '%s\n' "$INSTALL_FIXTURE" > "$ENUMERATION_HOME/.zstack/root"
chmod 700 "$ENUMERATION_HOME/.zstack"
chmod 600 "$ENUMERATION_HOME/.zstack/links" "$ENUMERATION_HOME/.zstack/root"
if ! (
  ZSTACK_REAL_AWK="$(command -v awk)"
  export ZSTACK_REAL_AWK
  # Invoked indirectly by the child Bash after export.
  # shellcheck disable=SC2329
  awk() {
    local argument
    for argument in "$@"; do
      [[ "$argument" == "host=agents" ]] && return 74
    done
    "$ZSTACK_REAL_AWK" "$@"
  }
  export -f awk
  HOME="$ENUMERATION_HOME" "$INSTALL_FIXTURE/scripts/setup.sh" --hosts agents > "$TEST_ROOT/setup-catalog-snapshot.log" 2>&1
); then
  fail "setup still depended on a fallible per-host catalog subprocess"
fi
[[ -L "$ENUMERATION_LINK" ]] || fail "a per-host catalog subprocess failure removed a managed link"
pass "setup snapshots catalog entries once before reconciling links"

SCOPE_FAILURE_HOME="$TEST_ROOT/scope-failure-home"
if (
  ZSTACK_REAL_GREP="$(command -v grep)"
  export ZSTACK_REAL_GREP
  # Invoked indirectly by the child Bash after export.
  # shellcheck disable=SC2329
  grep() {
    local argument
    for argument in "$@"; do
      [[ "$argument" == */scopes.pending.* ]] && return 74
    done
    "$ZSTACK_REAL_GREP" "$@"
  }
  export -f grep
  HOME="$SCOPE_FAILURE_HOME" "$INSTALL_FIXTURE/scripts/setup.sh" --hosts agents \
    > "$TEST_ROOT/setup-scope-read-failure.log" 2>&1
); then
  fail "setup treated a scope-snapshot read failure as a missing line"
fi
grep -q "Could not inspect the setup scope snapshot; refusing to continue" \
  "$TEST_ROOT/setup-scope-read-failure.log" || fail "setup reported the wrong scope-snapshot failure"
[[ ! -e "$SCOPE_FAILURE_HOME/.agents" ]] || fail "setup linked skills after a scope-snapshot read failure"
pass "setup distinguishes missing scope records from snapshot read failures"

DESIRED_FAILURE_HOME="$TEST_ROOT/desired-failure-home"
DESIRED_FAILURE_LINK="$DESIRED_FAILURE_HOME/.agents/skills/z-market-validate"
mkdir -p "$DESIRED_FAILURE_HOME/.agents/skills" "$DESIRED_FAILURE_HOME/.zstack"
ln -s "$INSTALL_FIXTURE/skills/z-market-validate" "$DESIRED_FAILURE_LINK"
printf '%s|%s\n' "$INSTALL_FIXTURE" "$DESIRED_FAILURE_LINK" > "$DESIRED_FAILURE_HOME/.zstack/links"
printf '%s\n' "$INSTALL_FIXTURE" > "$DESIRED_FAILURE_HOME/.zstack/root"
chmod 700 "$DESIRED_FAILURE_HOME/.zstack"
chmod 600 "$DESIRED_FAILURE_HOME/.zstack/links" "$DESIRED_FAILURE_HOME/.zstack/root"
if (
  ZSTACK_REAL_GREP="$(command -v grep)"
  export ZSTACK_REAL_GREP
  # Invoked indirectly by the child Bash after export.
  # shellcheck disable=SC2329
  grep() {
    local argument
    for argument in "$@"; do
      [[ "$argument" == */links.pending.* ]] && return 74
    done
    "$ZSTACK_REAL_GREP" "$@"
  }
  export -f grep
  HOME="$DESIRED_FAILURE_HOME" "$INSTALL_FIXTURE/scripts/setup.sh" --hosts agents \
    > "$TEST_ROOT/setup-desired-read-failure.log" 2>&1
); then
  fail "setup treated a desired-link snapshot failure as a non-match"
fi
grep -q "Could not inspect the desired-link snapshot; refusing to reconcile links" \
  "$TEST_ROOT/setup-desired-read-failure.log" || fail "setup reported the wrong desired-link snapshot failure"
[[ -L "$DESIRED_FAILURE_LINK" ]] || fail "setup removed a desired link after its snapshot became unreadable"
grep -Fqx "$INSTALL_FIXTURE|$DESIRED_FAILURE_LINK" "$DESIRED_FAILURE_HOME/.zstack/links" ||
  fail "setup changed install state after a desired-link snapshot failure"
pass "setup fails closed when desired-link membership cannot be read"

HOST_SNAPSHOT_FIXTURE="$(copy_fixture host-snapshot)"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$HOST_SNAPSHOT_FIXTURE/scripts/doctor.sh"
chmod +x "$HOST_SNAPSHOT_FIXTURE/scripts/doctor.sh"

HOST_SETUP_HOME="$TEST_ROOT/host-snapshot-setup-home"
if (
  ZSTACK_REAL_AWK="$(command -v awk)"
  export ZSTACK_REAL_AWK
  # Invoked indirectly by the child Bash after export.
  # shellcheck disable=SC2329
  awk() {
    local argument
    for argument in "$@"; do
      [[ "$argument" == */host.claude.source.* ]] && return 74
    done
    "$ZSTACK_REAL_AWK" "$@"
  }
  export -f awk
  HOME="$HOST_SETUP_HOME" "$HOST_SNAPSHOT_FIXTURE/scripts/setup.sh" --hosts agents > "$TEST_ROOT/setup-host-snapshot.log" 2>&1
); then
  fail "setup accepted a failed host-profile snapshot"
fi
grep -q "Could not snapshot host profiles; no links were changed" "$TEST_ROOT/setup-host-snapshot.log" ||
  fail "setup reported the wrong host-profile snapshot failure"
[[ ! -e "$HOST_SETUP_HOME/.agents" ]] || fail "setup linked skills before every host profile was snapshotted"
if find "$HOST_SETUP_HOME/.zstack" -name 'hosts.pending.*' -print -quit 2>/dev/null | grep -q .; then
  fail "setup left a failed host-profile snapshot behind"
fi

HOST_UNLINK_HOME="$TEST_ROOT/host-snapshot-unlink-home"
HOST_UNLINK_LINK="$HOST_UNLINK_HOME/.agents/skills/z-market-validate"
mkdir -p "$HOST_UNLINK_HOME/.agents/skills" "$HOST_UNLINK_HOME/.zstack"
ln -s "$HOST_SNAPSHOT_FIXTURE/skills/z-market-validate" "$HOST_UNLINK_LINK"
printf '%s|%s\n' "$HOST_SNAPSHOT_FIXTURE" "$HOST_UNLINK_LINK" > "$HOST_UNLINK_HOME/.zstack/links"
printf '%s\n' "$HOST_SNAPSHOT_FIXTURE" > "$HOST_UNLINK_HOME/.zstack/root"
chmod 700 "$HOST_UNLINK_HOME/.zstack"
chmod 600 "$HOST_UNLINK_HOME/.zstack/links" "$HOST_UNLINK_HOME/.zstack/root"
if (
  ZSTACK_REAL_AWK="$(command -v awk)"
  export ZSTACK_REAL_AWK
  # Invoked indirectly by the child Bash after export.
  # shellcheck disable=SC2329
  awk() {
    local argument
    for argument in "$@"; do
      [[ "$argument" == */host.claude.source.* ]] && return 74
    done
    "$ZSTACK_REAL_AWK" "$@"
  }
  export -f awk
  HOME="$HOST_UNLINK_HOME" "$HOST_SNAPSHOT_FIXTURE/scripts/unlink.sh" > "$TEST_ROOT/unlink-host-snapshot.log" 2>&1
); then
  fail "unlink accepted a failed host-profile snapshot"
fi
grep -q "Could not snapshot host profiles; no links were removed" "$TEST_ROOT/unlink-host-snapshot.log" ||
  fail "unlink reported the wrong host-profile snapshot failure"
[[ -L "$HOST_UNLINK_LINK" ]] || fail "unlink removed a managed link before every host profile was snapshotted"
[[ -f "$HOST_UNLINK_HOME/.zstack/links" ]] || fail "unlink replaced the manifest before every host profile was snapshotted"
if find "$HOST_UNLINK_HOME/.zstack" -name 'hosts.pending.*' -print -quit | grep -q .; then
  fail "unlink left a failed host-profile snapshot behind"
fi
pass "setup and unlink snapshot host profiles before mutating links"

UNLINK_HOST_SOURCE_FIXTURE="$(copy_fixture unlink-host-source-drift)"
UNLINK_HOST_SOURCE_HOME="$TEST_ROOT/unlink-host-source-home"
UNLINK_HOST_SOURCE_MARKER="$TEST_ROOT/unlink-host-source-marker"
UNLINK_HOST_SOURCE_LINK="$UNLINK_HOST_SOURCE_HOME/.agents/skills/z-market-validate"
HOME="$UNLINK_HOST_SOURCE_HOME" \
  "$UNLINK_HOST_SOURCE_FIXTURE/scripts/setup.sh" --hosts agents >/dev/null
if (
  ZSTACK_REAL_AWK="$(command -v awk)"
  HOST_SOURCE_PATH="$UNLINK_HOST_SOURCE_FIXTURE/hosts/agents.yaml"
  export ZSTACK_REAL_AWK HOST_SOURCE_PATH UNLINK_HOST_SOURCE_MARKER
  # Invoked indirectly by the child Bash after export.
  # shellcheck disable=SC2329
  awk() {
    local argument status=0
    "$ZSTACK_REAL_AWK" "$@" || status=$?
    for argument in "$@"; do
      if [[ "$argument" == */host.agents.source.* && ! -e "$UNLINK_HOST_SOURCE_MARKER" ]]; then
        printf '%s\n' '# external host edit must survive' >> "$HOST_SOURCE_PATH"
        : > "$UNLINK_HOST_SOURCE_MARKER"
      fi
    done
    return "$status"
  }
  export -f awk
  HOME="$UNLINK_HOST_SOURCE_HOME" \
    "$UNLINK_HOST_SOURCE_FIXTURE/scripts/unlink.sh" \
    > "$TEST_ROOT/unlink-host-source-drift.log" 2>&1
); then
  fail "unlink accepted a host profile changed after raw snapshot parsing"
fi
tail -n 1 "$UNLINK_HOST_SOURCE_FIXTURE/hosts/agents.yaml" |
  grep -qx '# external host edit must survive' ||
  fail "unlink discarded an external host source edit"
[[ -L "$UNLINK_HOST_SOURCE_LINK" ]] ||
  fail "unlink removed a managed link after host source drift"
[[ -f "$UNLINK_HOST_SOURCE_HOME/.zstack/links" ]] ||
  fail "unlink replaced the manifest after host source drift"
[[ -f "$UNLINK_HOST_SOURCE_HOME/.zstack/root" ]] ||
  fail "unlink removed the root record after host source drift"
[[ ! -e "$UNLINK_HOST_SOURCE_HOME/.zstack/operations.lock" ]] ||
  fail "unlink host source drift left the operation lock"
grep -q 'Host profile source changed after snapshot validation' "$TEST_ROOT/unlink-host-source-drift.log" ||
  fail "unlink reported the wrong post-parse host source drift failure"
unlink_host_source_temps="$(find "$UNLINK_HOST_SOURCE_HOME/.zstack" -maxdepth 1 \( -name '*.pending.*' -o -name '*.source.*' -o -name '*.next.*' -o -name '*.expected.*' \) -print | wc -l | tr -d ' ')"
[[ "$unlink_host_source_temps" -eq 0 ]] ||
  fail "unlink host source drift left transaction files"
pass "unlink binds host parsing to exact raw source snapshots"

awk '
  /^  - id: z-market-validate$/ { target = 1 }
  target && /^    path:/ { $0 = "    path: skills/../../outside-zstack"; target = 0 }
  { print }
' "$HOST_SNAPSHOT_FIXTURE/catalog.yaml" > "$HOST_SNAPSHOT_FIXTURE/catalog.yaml.next"
mv "$HOST_SNAPSHOT_FIXTURE/catalog.yaml.next" "$HOST_SNAPSHOT_FIXTURE/catalog.yaml"
SNAPSHOT_SAFETY_HOME="$TEST_ROOT/snapshot-safety-home"
if HOME="$SNAPSHOT_SAFETY_HOME" "$HOST_SNAPSHOT_FIXTURE/scripts/setup.sh" --hosts agents > "$TEST_ROOT/snapshot-safety.log" 2>&1; then
  fail "setup accepted a catalog path that escaped the snapshotted skill root"
fi
grep -q "Source snapshots failed mutation safety checks; no links were changed" "$TEST_ROOT/snapshot-safety.log" ||
  fail "setup reported the wrong mutation-snapshot safety failure"
[[ ! -e "$SNAPSHOT_SAFETY_HOME/.agents" ]] || fail "setup mutated a host root before validating the catalog snapshot"
pass "setup revalidates mutation-critical source invariants after doctor"

RAW_SOURCE_FIXTURE="$(copy_fixture raw-source-drift)"
RAW_SOURCE_HOME="$TEST_ROOT/raw-source-home"
RAW_SOURCE_MARKER="$TEST_ROOT/raw-source-marker"
if (
  ZSTACK_REAL_AWK="$(command -v awk)"
  CATALOG_SOURCE_PATH="$RAW_SOURCE_FIXTURE/catalog.yaml"
  export ZSTACK_REAL_AWK CATALOG_SOURCE_PATH RAW_SOURCE_MARKER
  # Invoked indirectly by the child Bash after export.
  # shellcheck disable=SC2329
  awk() {
    local argument status=0
    "$ZSTACK_REAL_AWK" "$@" || status=$?
    for argument in "$@"; do
      if [[ "$argument" == */catalog.source.* && ! -e "$RAW_SOURCE_MARKER" ]]; then
        printf '%s\n' '# external catalog edit must survive' >> "$CATALOG_SOURCE_PATH"
        : > "$RAW_SOURCE_MARKER"
      fi
    done
    return "$status"
  }
  export -f awk
  HOME="$RAW_SOURCE_HOME" "$RAW_SOURCE_FIXTURE/scripts/setup.sh" --hosts agents \
    > "$TEST_ROOT/raw-source-drift.log" 2>&1
); then
  fail "setup accepted a catalog changed after raw snapshot parsing"
fi
tail -n 1 "$RAW_SOURCE_FIXTURE/catalog.yaml" |
  grep -qx '# external catalog edit must survive' ||
  fail "setup discarded an external catalog source edit"
[[ ! -e "$RAW_SOURCE_HOME/.agents" ]] ||
  fail "setup changed host roots after catalog source drift"
[[ ! -e "$RAW_SOURCE_HOME/.zstack/operations.lock" ]] ||
  fail "setup catalog source drift left the operation lock"
grep -q 'Catalog source changed after snapshot validation' "$TEST_ROOT/raw-source-drift.log" ||
  fail "setup reported the wrong post-parse catalog source drift failure"
raw_source_temps="$(find "$RAW_SOURCE_HOME/.zstack" -maxdepth 1 \( -name '*.pending.*' -o -name '*.source.*' -o -name '*.next.*' -o -name '*.merged.*' -o -name '*.expected.*' \) -print | wc -l | tr -d ' ')"
[[ "$raw_source_temps" -eq 0 ]] ||
  fail "setup catalog source drift left transaction files"
pass "setup binds catalog parsing to one exact raw source snapshot"

TEST_HOME="$TEST_ROOT/home"
mkdir -p "$TEST_HOME/.zstack/operations.lock"
printf '%s\n' "$$" > "$TEST_HOME/.zstack/operations.lock/pid"
chmod 700 "$TEST_HOME/.zstack/operations.lock"
chmod 600 "$TEST_HOME/.zstack/operations.lock/pid"
if HOME="$TEST_HOME" "$INSTALL_FIXTURE/scripts/setup.sh" --hosts agents > "$TEST_ROOT/setup-lock.log" 2>&1; then
  fail "setup ignored an active shared operation lock"
fi
grep -q "Another zstack setup/unlink operation is in progress" "$TEST_ROOT/setup-lock.log" || fail "setup reported the wrong operation-lock failure"
[[ ! -e "$TEST_HOME/.agents" ]] || fail "locked setup changed host roots"
if HOME="$TEST_HOME" "$INSTALL_FIXTURE/scripts/doctor.sh" > "$TEST_ROOT/doctor-lock.log" 2>&1; then
  fail "doctor audited installed links during an active mutation"
fi
grep -q "installed-link audit could not acquire the mutation lock" "$TEST_ROOT/doctor-lock.log" || fail "doctor reported the wrong active-mutation failure"
if grep -q "install manifest:" "$TEST_ROOT/doctor-lock.log"; then
  fail "doctor reported manifest health without a stable mutation snapshot"
fi
[[ -f "$TEST_HOME/.zstack/operations.lock/pid" ]] || fail "doctor removed another process's active mutation lock"
unlink "$TEST_HOME/.zstack/operations.lock/pid"
rmdir "$TEST_HOME/.zstack/operations.lock"
pass "setup rejects concurrent mutation and doctor skips unstable link audits"

mkdir -p "$TEST_HOME/.agents/skills/z-market-validate"
printf '%s\n' "keep me" > "$TEST_HOME/.agents/skills/z-market-validate/owner.txt"

if HOME="$TEST_HOME" "$INSTALL_FIXTURE/scripts/setup.sh" --hosts agents > "$TEST_ROOT/conflict.log" 2>&1; then
  fail "setup reported success after skipping a conflict"
fi
[[ ! -L "$TEST_HOME/.agents/skills/z-market-validate" ]] || fail "setup replaced a conflict without --force"
[[ -L "$TEST_HOME/.agents/skills/z-write-prd" ]] || fail "setup did not install an active Agent Skill"
[[ ! -e "$TEST_HOME/.agents/skills/z-seo-plan" ]] || fail "setup installed a draft skill"
grep -q "Setup incomplete" "$TEST_ROOT/conflict.log" || fail "setup did not report an incomplete install"
pass "setup respects conflicts and reports partial installation"

HOME="$TEST_HOME" "$INSTALL_FIXTURE/scripts/setup.sh" --hosts agents --force >/dev/null
[[ -L "$TEST_HOME/.agents/skills/z-market-validate" ]] || fail "--force did not install over a backed-up conflict"
backup_count="$(find "$TEST_HOME/.agents/skills" -maxdepth 1 -type d -name 'z-market-validate.zstack-backup-*' | wc -l | tr -d ' ')"
[[ "$backup_count" -eq 1 ]] || fail "--force did not preserve exactly one backup"
backup_path="$(find "$TEST_HOME/.agents/skills" -maxdepth 1 -type d -name 'z-market-validate.zstack-backup-*' -print -quit)"
[[ -f "$backup_path/original/owner.txt" ]] || fail "--force backup did not retain the original conflict inside its reserved container"
pass "--force preserves conflicting content in a backup"

BACKUP_RESERVATION_HOME="$TEST_ROOT/backup-reservation-home"
mkdir -p "$BACKUP_RESERVATION_HOME/.agents/skills/z-market-validate"
printf '%s\n' 'preserve on reservation failure' > "$BACKUP_RESERVATION_HOME/.agents/skills/z-market-validate/owner.txt"
if (
  ZSTACK_REAL_MKTEMP="$(command -v mktemp)"
  export ZSTACK_REAL_MKTEMP
  # Invoked indirectly by the child Bash after export.
  # shellcheck disable=SC2329
  mktemp() {
    local argument
    for argument in "$@"; do
      [[ "$argument" == *".zstack-backup-"* ]] && return 74
    done
    "$ZSTACK_REAL_MKTEMP" "$@"
  }
  export -f mktemp
  HOME="$BACKUP_RESERVATION_HOME" "$INSTALL_FIXTURE/scripts/setup.sh" --hosts agents --force > "$TEST_ROOT/backup-reservation.log" 2>&1
); then
  fail "setup accepted a failed collision-free backup reservation"
fi
grep -q "could not reserve a collision-free backup" "$TEST_ROOT/backup-reservation.log" ||
  fail "setup reported the wrong backup-reservation failure"
[[ -f "$BACKUP_RESERVATION_HOME/.agents/skills/z-market-validate/owner.txt" ]] ||
  fail "setup changed a conflict after backup reservation failed"
pass "--force fails safely when a collision-free backup cannot be reserved"

grep -qF "$INSTALL_FIXTURE|$TEST_HOME/.agents/skills/z-market-validate" "$TEST_HOME/.zstack/links" || fail "setup did not record an installed link"
pass "setup records managed links for safe uninstall"

[[ "$(zstack_file_mode_bits "$TEST_HOME/.zstack")" == "700" ]] || fail "setup left install state visible to other local users"
[[ "$(zstack_file_mode_bits "$TEST_HOME/.zstack/root")" == "600" ]] || fail "setup created a non-private root record"
[[ "$(zstack_file_mode_bits "$TEST_HOME/.zstack/links")" == "600" ]] || fail "setup created a non-private install manifest"
pass "setup keeps install state private to the current user"

chmod 755 "$TEST_HOME/.zstack"
chmod 644 "$TEST_HOME/.zstack/root" "$TEST_HOME/.zstack/links"
HOME="$TEST_HOME" "$INSTALL_FIXTURE/scripts/doctor.sh" > "$TEST_ROOT/state-permissions.log" 2>&1 || fail "doctor treated repairable state permissions as fatal"
grep -q "zstack state directory permissions are 755" "$TEST_ROOT/state-permissions.log" || fail "doctor missed a non-private state directory"
grep -q "zstack root record permissions are 644" "$TEST_ROOT/state-permissions.log" || fail "doctor missed a non-private root record"
grep -q "zstack install manifest permissions are 644" "$TEST_ROOT/state-permissions.log" || fail "doctor missed a non-private install manifest"
chmod 700 "$TEST_HOME/.zstack"
chmod 600 "$TEST_HOME/.zstack/root" "$TEST_HOME/.zstack/links"
pass "doctor reports repairable state-permission drift"

HOME="$TEST_HOME" "$INSTALL_FIXTURE/scripts/doctor.sh" >/dev/null 2>&1 || fail "doctor returned failure for a healthy locked install snapshot"
[[ ! -e "$TEST_HOME/.zstack/operations.lock" ]] || fail "doctor left its installed-link snapshot lock"
pass "doctor returns success and releases its installed-link snapshot lock"

cp "$TEST_HOME/.zstack/links" "$TEST_ROOT/links.before"
cp "$TEST_HOME/.zstack/root" "$TEST_ROOT/root.before"
printf '%s|%s\n' "$INSTALL_FIXTURE" "$TEST_HOME/missing-project-link" >> "$TEST_HOME/.zstack/links"
printf '%s|%s\n' "$INSTALL_FIXTURE" "${TEST_HOME}/control"$'\t'"link" >> "$TEST_HOME/.zstack/links"
printf '%s\n' $'/tmp/unsafe\033[31m-root' > "$TEST_HOME/.zstack/root"
if HOME="$TEST_HOME" "$INSTALL_FIXTURE/scripts/doctor.sh" > "$TEST_ROOT/manifest.log" 2>&1; then
  fail "doctor accepted an unsafe root record"
fi
grep -q "tracked link is missing or no longer a symlink" "$TEST_ROOT/manifest.log" || fail "doctor did not audit a stale manifest entry"
grep -q "install manifest line .* has unsafe path fields" "$TEST_ROOT/manifest.log" || fail "doctor accepted a control character in the install manifest"
grep -q "zstack root record must contain exactly one safe absolute path" "$TEST_ROOT/manifest.log" || fail "doctor reported the wrong unsafe-root failure"
if LC_ALL=C grep -q $'\033' "$TEST_ROOT/manifest.log"; then
  fail "doctor emitted a raw terminal control character from state"
fi
mv "$TEST_ROOT/links.before" "$TEST_HOME/.zstack/links"
mv "$TEST_ROOT/root.before" "$TEST_HOME/.zstack/root"
pass "doctor audits state consistently without emitting unsafe values"

DOCTOR_STATE_SNAPSHOT_FIXTURE="$(copy_fixture doctor-state-snapshot)"
DOCTOR_STATE_SNAPSHOT_HOME="$TEST_ROOT/doctor-state-snapshot-home"
DOCTOR_STATE_SNAPSHOT_MANIFEST="$DOCTOR_STATE_SNAPSHOT_HOME/.zstack/links"
DOCTOR_STATE_SNAPSHOT_TMP="$TEST_ROOT/doctor-state-snapshot-tmp"
DOCTOR_STATE_SNAPSHOT_MARKER="$TEST_ROOT/doctor-state-snapshot-marker"
DOCTOR_STATE_REAL_SORT="$(command -v sort)"
HOME="$DOCTOR_STATE_SNAPSHOT_HOME" \
  "$DOCTOR_STATE_SNAPSHOT_FIXTURE/scripts/setup.sh" --hosts agents >/dev/null
mkdir -p "$DOCTOR_STATE_SNAPSHOT_TMP" "$TEST_ROOT/doctor-state-sort-bin"
chmod 700 "$DOCTOR_STATE_SNAPSHOT_TMP"
# These single-quoted lines are the source of the generated fault-injection shim.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'status=0' \
  '"$REAL_SORT_BIN" "$@" || status=$?' \
  'for argument in "$@"; do' \
  '  if [[ "$argument" == */zstack-doctor-links.* && ! -e "$SNAPSHOT_MARKER" ]]; then' \
  '    printf "%s\n" "# external manifest edit must survive" >> "$MANIFEST_PATH"' \
  '    : > "$SNAPSHOT_MARKER"' \
  '  fi' \
  'done' \
  'exit "$status"' > "$TEST_ROOT/doctor-state-sort-bin/sort"
chmod +x "$TEST_ROOT/doctor-state-sort-bin/sort"
if PATH="$TEST_ROOT/doctor-state-sort-bin:$PATH" \
  REAL_SORT_BIN="$DOCTOR_STATE_REAL_SORT" \
  MANIFEST_PATH="$DOCTOR_STATE_SNAPSHOT_MANIFEST" \
  SNAPSHOT_MARKER="$DOCTOR_STATE_SNAPSHOT_MARKER" \
  TMPDIR="$DOCTOR_STATE_SNAPSHOT_TMP" \
  HOME="$DOCTOR_STATE_SNAPSHOT_HOME" \
  "$DOCTOR_STATE_SNAPSHOT_FIXTURE/scripts/doctor.sh" \
  > "$TEST_ROOT/doctor-state-snapshot.log" 2>&1; then
  fail "doctor accepted an install manifest changed after snapshot validation"
fi
[[ -f "$DOCTOR_STATE_SNAPSHOT_MARKER" ]] ||
  fail "doctor state-snapshot fixture did not reach manifest parsing"
tail -n 1 "$DOCTOR_STATE_SNAPSHOT_MANIFEST" |
  grep -qx '# external manifest edit must survive' ||
  fail "doctor discarded an external post-snapshot manifest edit"
grep -q 'install manifest: .* tracked links for current root' \
  "$TEST_ROOT/doctor-state-snapshot.log" ||
  fail "doctor did not audit the captured install-manifest snapshot"
grep -q 'zstack install manifest changed during the installed-link audit; results use the captured snapshot' \
  "$TEST_ROOT/doctor-state-snapshot.log" ||
  fail "doctor reported the wrong post-snapshot manifest drift failure"
if grep -q 'install manifest line .* is malformed' \
  "$TEST_ROOT/doctor-state-snapshot.log"; then
  fail "doctor mixed the live post-snapshot manifest into its captured audit"
fi
[[ ! -e "$DOCTOR_STATE_SNAPSHOT_HOME/.zstack/operations.lock" ]] ||
  fail "doctor state-snapshot drift left the operation lock"
doctor_state_snapshot_temps="$(find "$DOCTOR_STATE_SNAPSHOT_TMP" \
  -mindepth 1 -maxdepth 1 -print | wc -l | tr -d ' ')"
[[ "$doctor_state_snapshot_temps" -eq 0 ]] ||
  fail "doctor state-snapshot drift left temporary files"
pass "doctor audits exact installed-state snapshots and reports live drift"

DOCTOR_HOST_SNAPSHOT_FIXTURE="$(copy_fixture doctor-host-snapshot)"
DOCTOR_HOST_SNAPSHOT_HOME="$TEST_ROOT/doctor-host-snapshot-home"
DOCTOR_HOST_SNAPSHOT_SOURCE="$DOCTOR_HOST_SNAPSHOT_FIXTURE/hosts/agents.yaml"
DOCTOR_HOST_SNAPSHOT_TMP="$TEST_ROOT/doctor-host-snapshot-tmp"
DOCTOR_HOST_SNAPSHOT_MARKER="$TEST_ROOT/doctor-host-snapshot-marker"
DOCTOR_HOST_REAL_AWK="$(command -v awk)"
HOME="$DOCTOR_HOST_SNAPSHOT_HOME" \
  "$DOCTOR_HOST_SNAPSHOT_FIXTURE/scripts/setup.sh" --hosts agents >/dev/null
mkdir -p "$DOCTOR_HOST_SNAPSHOT_TMP" "$TEST_ROOT/doctor-host-awk-bin"
chmod 700 "$DOCTOR_HOST_SNAPSHOT_TMP"
# These single-quoted lines are the source of the generated fault-injection shim.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'status=0' \
  '"$REAL_AWK_BIN" "$@" || status=$?' \
  'for argument in "$@"; do' \
  '  if [[ "$argument" == */zstack-doctor-host.* && ! -e "$SNAPSHOT_MARKER" ]]; then' \
  '    printf "%s\n" "# external host edit must survive" >> "$HOST_SOURCE_PATH"' \
  '    : > "$SNAPSHOT_MARKER"' \
  '  fi' \
  'done' \
  'exit "$status"' > "$TEST_ROOT/doctor-host-awk-bin/awk"
chmod +x "$TEST_ROOT/doctor-host-awk-bin/awk"
if PATH="$TEST_ROOT/doctor-host-awk-bin:$PATH" \
  REAL_AWK_BIN="$DOCTOR_HOST_REAL_AWK" \
  HOST_SOURCE_PATH="$DOCTOR_HOST_SNAPSHOT_SOURCE" \
  SNAPSHOT_MARKER="$DOCTOR_HOST_SNAPSHOT_MARKER" \
  TMPDIR="$DOCTOR_HOST_SNAPSHOT_TMP" \
  HOME="$DOCTOR_HOST_SNAPSHOT_HOME" \
  "$DOCTOR_HOST_SNAPSHOT_FIXTURE/scripts/doctor.sh" \
  > "$TEST_ROOT/doctor-host-snapshot.log" 2>&1; then
  fail "doctor accepted a host profile changed after snapshot parsing"
fi
[[ -f "$DOCTOR_HOST_SNAPSHOT_MARKER" ]] ||
  fail "doctor host-snapshot fixture did not reach profile parsing"
tail -n 1 "$DOCTOR_HOST_SNAPSHOT_SOURCE" |
  grep -qx '# external host edit must survive' ||
  fail "doctor discarded an external post-snapshot host edit"
grep -q 'agents: profile contract' "$TEST_ROOT/doctor-host-snapshot.log" ||
  fail "doctor did not validate the captured host profile"
grep -q 'host profile sources changed while doctor validated the captured profiles' \
  "$TEST_ROOT/doctor-host-snapshot.log" ||
  fail "doctor reported the wrong post-parse host drift failure"
if grep -q 'OK:   link agents:' "$TEST_ROOT/doctor-host-snapshot.log"; then
  fail "doctor ran host-link audit after host source drift"
fi
[[ ! -e "$DOCTOR_HOST_SNAPSHOT_HOME/.zstack/operations.lock" ]] ||
  fail "doctor host-snapshot drift left the operation lock"
doctor_host_snapshot_temps="$(find "$DOCTOR_HOST_SNAPSHOT_TMP" \
  -mindepth 1 -maxdepth 1 -print | wc -l | tr -d ' ')"
[[ "$doctor_host_snapshot_temps" -eq 0 ]] ||
  fail "doctor host-snapshot drift left temporary files"
pass "doctor reuses exact host snapshots and skips mixed link audits"

DOCTOR_CATALOG_SNAPSHOT_FIXTURE="$(copy_fixture doctor-catalog-snapshot)"
DOCTOR_CATALOG_SNAPSHOT_HOME="$TEST_ROOT/doctor-catalog-snapshot-home"
DOCTOR_CATALOG_SNAPSHOT_SOURCE="$DOCTOR_CATALOG_SNAPSHOT_FIXTURE/catalog.yaml"
DOCTOR_CATALOG_SNAPSHOT_TMP="$TEST_ROOT/doctor-catalog-snapshot-tmp"
DOCTOR_CATALOG_SNAPSHOT_MARKER="$TEST_ROOT/doctor-catalog-snapshot-marker"
DOCTOR_CATALOG_REAL_AWK="$(command -v awk)"
HOME="$DOCTOR_CATALOG_SNAPSHOT_HOME" \
  "$DOCTOR_CATALOG_SNAPSHOT_FIXTURE/scripts/setup.sh" --hosts agents >/dev/null
mkdir -p "$DOCTOR_CATALOG_SNAPSHOT_TMP" "$TEST_ROOT/doctor-catalog-awk-bin"
chmod 700 "$DOCTOR_CATALOG_SNAPSHOT_TMP"
# These single-quoted lines are the source of the generated fault-injection shim.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'status=0' \
  '"$REAL_AWK_BIN" "$@" || status=$?' \
  'for argument in "$@"; do' \
  '  if [[ "$argument" == */zstack-doctor-catalog-source.* && ! -e "$SNAPSHOT_MARKER" ]]; then' \
  '    printf "%s\n" "# external catalog edit must survive" >> "$CATALOG_SOURCE_PATH"' \
  '    : > "$SNAPSHOT_MARKER"' \
  '  fi' \
  'done' \
  'exit "$status"' > "$TEST_ROOT/doctor-catalog-awk-bin/awk"
chmod +x "$TEST_ROOT/doctor-catalog-awk-bin/awk"
if PATH="$TEST_ROOT/doctor-catalog-awk-bin:$PATH" \
  REAL_AWK_BIN="$DOCTOR_CATALOG_REAL_AWK" \
  CATALOG_SOURCE_PATH="$DOCTOR_CATALOG_SNAPSHOT_SOURCE" \
  SNAPSHOT_MARKER="$DOCTOR_CATALOG_SNAPSHOT_MARKER" \
  TMPDIR="$DOCTOR_CATALOG_SNAPSHOT_TMP" \
  HOME="$DOCTOR_CATALOG_SNAPSHOT_HOME" \
  "$DOCTOR_CATALOG_SNAPSHOT_FIXTURE/scripts/doctor.sh" \
  > "$TEST_ROOT/doctor-catalog-snapshot.log" 2>&1; then
  fail "doctor accepted a catalog changed after snapshot parsing"
fi
[[ -f "$DOCTOR_CATALOG_SNAPSHOT_MARKER" ]] ||
  fail "doctor catalog-snapshot fixture did not reach entry parsing"
tail -n 1 "$DOCTOR_CATALOG_SNAPSHOT_SOURCE" |
  grep -qx '# external catalog edit must survive' ||
  fail "doctor discarded an external post-snapshot catalog edit"
grep -q 'OK:   catalog version 1' "$TEST_ROOT/doctor-catalog-snapshot.log" ||
  fail "doctor did not validate the captured catalog version"
grep -q 'z-market-validate: registered in catalog' \
  "$TEST_ROOT/doctor-catalog-snapshot.log" ||
  fail "doctor did not reuse captured catalog entries for skill validation"
grep -q 'catalog.yaml changed while doctor validated the captured catalog' \
  "$TEST_ROOT/doctor-catalog-snapshot.log" ||
  fail "doctor reported the wrong post-parse catalog drift failure"
if grep -q 'OK:   link agents:' "$TEST_ROOT/doctor-catalog-snapshot.log"; then
  fail "doctor ran host-link audit after catalog source drift"
fi
[[ ! -e "$DOCTOR_CATALOG_SNAPSHOT_HOME/.zstack/operations.lock" ]] ||
  fail "doctor catalog-snapshot drift left the operation lock"
doctor_catalog_snapshot_temps="$(find "$DOCTOR_CATALOG_SNAPSHOT_TMP" \
  -mindepth 1 -maxdepth 1 -print | wc -l | tr -d ' ')"
[[ "$doctor_catalog_snapshot_temps" -eq 0 ]] ||
  fail "doctor catalog-snapshot drift left temporary files"
pass "doctor reuses one exact catalog snapshot across validation and link audit"

DOCTOR_EVAL_SNAPSHOT_FIXTURE="$(copy_fixture doctor-eval-snapshots)"
DOCTOR_EVAL_SNAPSHOT_CASES="$DOCTOR_EVAL_SNAPSHOT_FIXTURE/evals/cases.yaml"
DOCTOR_EVAL_SNAPSHOT_ROUTING="$DOCTOR_EVAL_SNAPSHOT_FIXTURE/evals/routing.yaml"
DOCTOR_EVAL_SNAPSHOT_TMP="$TEST_ROOT/doctor-eval-snapshot-tmp"
DOCTOR_EVAL_CASES_MARKER="$TEST_ROOT/doctor-eval-cases-marker"
DOCTOR_EVAL_ROUTING_MARKER="$TEST_ROOT/doctor-eval-routing-marker"
DOCTOR_EVAL_REAL_AWK="$(command -v awk)"
mkdir -p "$DOCTOR_EVAL_SNAPSHOT_TMP" "$TEST_ROOT/doctor-eval-awk-bin"
chmod 700 "$DOCTOR_EVAL_SNAPSHOT_TMP"
# These single-quoted lines are the source of the generated fault-injection shim.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'status=0' \
  '"$REAL_AWK_BIN" "$@" || status=$?' \
  'for argument in "$@"; do' \
  '  if [[ "$argument" == */zstack-doctor-evals-source.* && ! -e "$CASES_MARKER" ]]; then' \
  '    printf "%s\n" "# external behavioral edit must survive" >> "$CASES_SOURCE_PATH"' \
  '    : > "$CASES_MARKER"' \
  '  fi' \
  '  if [[ "$argument" == */zstack-doctor-routing-source.* && ! -e "$ROUTING_MARKER" ]]; then' \
  '    printf "%s\n" "# external routing edit must survive" >> "$ROUTING_SOURCE_PATH"' \
  '    : > "$ROUTING_MARKER"' \
  '  fi' \
  'done' \
  'exit "$status"' > "$TEST_ROOT/doctor-eval-awk-bin/awk"
chmod +x "$TEST_ROOT/doctor-eval-awk-bin/awk"
if PATH="$TEST_ROOT/doctor-eval-awk-bin:$PATH" \
  REAL_AWK_BIN="$DOCTOR_EVAL_REAL_AWK" \
  CASES_SOURCE_PATH="$DOCTOR_EVAL_SNAPSHOT_CASES" \
  ROUTING_SOURCE_PATH="$DOCTOR_EVAL_SNAPSHOT_ROUTING" \
  CASES_MARKER="$DOCTOR_EVAL_CASES_MARKER" \
  ROUTING_MARKER="$DOCTOR_EVAL_ROUTING_MARKER" \
  TMPDIR="$DOCTOR_EVAL_SNAPSHOT_TMP" \
  "$DOCTOR_EVAL_SNAPSHOT_FIXTURE/scripts/doctor.sh" --source-only \
  > "$TEST_ROOT/doctor-eval-snapshots.log" 2>&1; then
  fail "doctor accepted eval manifests changed after snapshot parsing"
fi
[[ -f "$DOCTOR_EVAL_CASES_MARKER" && -f "$DOCTOR_EVAL_ROUTING_MARKER" ]] ||
  fail "doctor eval-snapshot fixture did not reach both manifest parsers"
tail -n 1 "$DOCTOR_EVAL_SNAPSHOT_CASES" |
  grep -qx '# external behavioral edit must survive' ||
  fail "doctor discarded an external post-snapshot behavioral edit"
tail -n 1 "$DOCTOR_EVAL_SNAPSHOT_ROUTING" |
  grep -qx '# external routing edit must survive' ||
  fail "doctor discarded an external post-snapshot routing edit"
grep -q 'z-market-validate: 4 behavioral evals' \
  "$TEST_ROOT/doctor-eval-snapshots.log" ||
  fail "doctor did not compute behavioral coverage from the captured manifest"
grep -q 'z-market-validate: 5 routing evals' \
  "$TEST_ROOT/doctor-eval-snapshots.log" ||
  fail "doctor did not compute routing coverage from the captured manifest"
grep -q 'evals/cases.yaml changed while doctor validated the captured behavioral manifest' \
  "$TEST_ROOT/doctor-eval-snapshots.log" ||
  fail "doctor reported the wrong behavioral post-parser drift failure"
grep -q 'evals/routing.yaml changed while doctor validated the captured routing manifest' \
  "$TEST_ROOT/doctor-eval-snapshots.log" ||
  fail "doctor reported the wrong routing post-parser drift failure"
doctor_eval_snapshot_temps="$(find "$DOCTOR_EVAL_SNAPSHOT_TMP" \
  -mindepth 1 -maxdepth 1 -print | wc -l | tr -d ' ')"
[[ "$doctor_eval_snapshot_temps" -eq 0 ]] ||
  fail "doctor eval-snapshot drift left temporary files"
pass "doctor validates behavioral and routing manifests from exact raw snapshots"

DOCTOR_CAPTURED_YAML_FIXTURE="$(copy_fixture doctor-captured-yaml)"
DOCTOR_CAPTURED_YAML_SOURCE="$DOCTOR_CAPTURED_YAML_FIXTURE/catalog.yaml"
DOCTOR_CAPTURED_YAML_TMP="$TEST_ROOT/doctor-captured-yaml-tmp"
DOCTOR_CAPTURED_YAML_MARKER="$TEST_ROOT/doctor-captured-yaml-marker"
DOCTOR_CAPTURED_YAML_REAL_RUBY="$(command -v ruby)"
mkdir -p "$DOCTOR_CAPTURED_YAML_TMP" "$TEST_ROOT/doctor-captured-yaml-bin"
chmod 700 "$DOCTOR_CAPTURED_YAML_TMP"
# These single-quoted lines are the source of the generated fault-injection shim.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'status=0' \
  'is_validator=0' \
  'is_captured_validation=0' \
  'for argument in "$@"; do' \
  '  [[ "$argument" != "$VALIDATOR_PATH" ]] || is_validator=1' \
  '  [[ "$argument" != "--documents" ]] || is_captured_validation=1' \
  'done' \
  '"$REAL_RUBY_BIN" "$@" || status=$?' \
  'if [[ "$status" -eq 0 && "$is_validator" -eq 1 && "$is_captured_validation" -eq 0 && ! -e "$SNAPSHOT_MARKER" ]]; then' \
  '  printf "%s\n" "version: 1" >> "$CATALOG_SOURCE_PATH"' \
  '  : > "$SNAPSHOT_MARKER"' \
  'fi' \
  'exit "$status"' > "$TEST_ROOT/doctor-captured-yaml-bin/ruby"
chmod +x "$TEST_ROOT/doctor-captured-yaml-bin/ruby"
if PATH="$TEST_ROOT/doctor-captured-yaml-bin:$PATH" \
  REAL_RUBY_BIN="$DOCTOR_CAPTURED_YAML_REAL_RUBY" \
  VALIDATOR_PATH="$DOCTOR_CAPTURED_YAML_FIXTURE/scripts/validate-yaml.rb" \
  CATALOG_SOURCE_PATH="$DOCTOR_CAPTURED_YAML_SOURCE" \
  SNAPSHOT_MARKER="$DOCTOR_CAPTURED_YAML_MARKER" \
  TMPDIR="$DOCTOR_CAPTURED_YAML_TMP" \
  "$DOCTOR_CAPTURED_YAML_FIXTURE/scripts/doctor.sh" --source-only \
  > "$TEST_ROOT/doctor-captured-yaml.log" 2>&1; then
  fail "doctor accepted YAML syntax that changed between live and snapshot validation"
fi
[[ -f "$DOCTOR_CAPTURED_YAML_MARKER" ]] ||
  fail "doctor captured-YAML fixture did not mutate after initial strict validation"
tail -n 1 "$DOCTOR_CAPTURED_YAML_SOURCE" | grep -qx 'version: 1' ||
  fail "doctor discarded the YAML edit injected between validation phases"
grep -Eq 'OK:   strict YAML syntax \([0-9]+ files, [0-9]+ frontmatters\)' \
  "$TEST_ROOT/doctor-captured-yaml.log" ||
  fail "doctor captured-YAML fixture did not complete initial strict validation"
grep -Eq 'YAML ERROR: catalog.yaml:[0-9]+: duplicate key "version"' \
  "$TEST_ROOT/doctor-captured-yaml.log" ||
  fail "doctor did not strictly parse the captured catalog version"
grep -q 'captured source strict YAML validation failed' \
  "$TEST_ROOT/doctor-captured-yaml.log" ||
  fail "doctor reported the wrong captured-YAML validation failure"
doctor_captured_yaml_temps="$(find "$DOCTOR_CAPTURED_YAML_TMP" \
  -mindepth 1 -maxdepth 1 -print | wc -l | tr -d ' ')"
[[ "$doctor_captured_yaml_temps" -eq 0 ]] ||
  fail "doctor captured-YAML failure left temporary files"
pass "doctor strictly parses the exact YAML snapshots used by semantic validation"

DOCTOR_WORKFLOW_SNAPSHOT_FIXTURE="$(copy_fixture doctor-workflow-snapshot)"
DOCTOR_WORKFLOW_SNAPSHOT_SOURCE="$DOCTOR_WORKFLOW_SNAPSHOT_FIXTURE/.github/workflows/validate.yml"
DOCTOR_WORKFLOW_SNAPSHOT_TMP="$TEST_ROOT/doctor-workflow-snapshot-tmp"
DOCTOR_WORKFLOW_SNAPSHOT_MARKER="$TEST_ROOT/doctor-workflow-snapshot-marker"
DOCTOR_WORKFLOW_REAL_AWK="$(command -v awk)"
mkdir -p "$DOCTOR_WORKFLOW_SNAPSHOT_TMP" "$TEST_ROOT/doctor-workflow-awk-bin"
chmod 700 "$DOCTOR_WORKFLOW_SNAPSHOT_TMP"
# These single-quoted lines are the source of the generated fault-injection shim.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'status=0' \
  '"$REAL_AWK_BIN" "$@" || status=$?' \
  'for argument in "$@"; do' \
  '  if [[ "$argument" == */zstack-doctor-workflow.* && ! -e "$SNAPSHOT_MARKER" ]]; then' \
  '    printf "%s\n" "      - uses: actions/checkout@v7" >> "$WORKFLOW_SOURCE_PATH"' \
  '    : > "$SNAPSHOT_MARKER"' \
  '  fi' \
  'done' \
  'exit "$status"' > "$TEST_ROOT/doctor-workflow-awk-bin/awk"
chmod +x "$TEST_ROOT/doctor-workflow-awk-bin/awk"
if PATH="$TEST_ROOT/doctor-workflow-awk-bin:$PATH" \
  REAL_AWK_BIN="$DOCTOR_WORKFLOW_REAL_AWK" \
  WORKFLOW_SOURCE_PATH="$DOCTOR_WORKFLOW_SNAPSHOT_SOURCE" \
  SNAPSHOT_MARKER="$DOCTOR_WORKFLOW_SNAPSHOT_MARKER" \
  TMPDIR="$DOCTOR_WORKFLOW_SNAPSHOT_TMP" \
  "$DOCTOR_WORKFLOW_SNAPSHOT_FIXTURE/scripts/doctor.sh" --source-only \
  > "$TEST_ROOT/doctor-workflow-snapshot.log" 2>&1; then
  fail "doctor accepted a workflow changed after captured action inspection"
fi
[[ -f "$DOCTOR_WORKFLOW_SNAPSHOT_MARKER" ]] ||
  fail "doctor workflow-snapshot fixture did not reach captured action inspection"
tail -n 1 "$DOCTOR_WORKFLOW_SNAPSHOT_SOURCE" |
  grep -qx '      - uses: actions/checkout@v7' ||
  fail "doctor discarded an external post-snapshot workflow edit"
if grep -q 'workflow action must use a full immutable commit SHA' \
  "$TEST_ROOT/doctor-workflow-snapshot.log"; then
  fail "doctor inspected live workflow bytes instead of its captured snapshot"
fi
grep -q 'workflow sources changed while doctor validated captured workflows' \
  "$TEST_ROOT/doctor-workflow-snapshot.log" ||
  fail "doctor reported the wrong post-inspection workflow drift failure"
doctor_workflow_snapshot_temps="$(find "$DOCTOR_WORKFLOW_SNAPSHOT_TMP" \
  -mindepth 1 -maxdepth 1 -print | wc -l | tr -d ' ')"
[[ "$doctor_workflow_snapshot_temps" -eq 0 ]] ||
  fail "doctor workflow-snapshot drift left temporary files"
pass "doctor validates action pins from exact workflow snapshots and reports live drift"

DOCTOR_SKILL_TREE_FIXTURE="$(copy_fixture doctor-skill-tree-state)"
DOCTOR_SKILL_TREE_HOME="$TEST_ROOT/doctor-skill-tree-home"
DOCTOR_SKILL_TREE_SOURCE="$DOCTOR_SKILL_TREE_FIXTURE/skills/z-market-validate/references/quality-bar.md"
DOCTOR_SKILL_TREE_TMP="$TEST_ROOT/doctor-skill-tree-tmp"
DOCTOR_SKILL_TREE_MARKER="$TEST_ROOT/doctor-skill-tree-marker"
DOCTOR_SKILL_TREE_REAL_RUBY="$(command -v ruby)"
HOME="$DOCTOR_SKILL_TREE_HOME" \
  "$DOCTOR_SKILL_TREE_FIXTURE/scripts/setup.sh" --hosts agents >/dev/null
mkdir -p "$DOCTOR_SKILL_TREE_TMP" "$TEST_ROOT/doctor-skill-tree-ruby-bin"
chmod 700 "$DOCTOR_SKILL_TREE_TMP"
# These single-quoted lines are the source of the generated fault-injection shim.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'status=0' \
  'is_initial_validator=0' \
  'for argument in "$@"; do' \
  '  [[ "$argument" != "$VALIDATOR_PATH" ]] || is_initial_validator=1' \
  '  [[ "$argument" != "--documents" ]] || is_initial_validator=0' \
  'done' \
  '"$REAL_RUBY_BIN" "$@" || status=$?' \
  'if [[ "$status" -eq 0 && "$is_initial_validator" -eq 1 && ! -e "$STATE_MARKER" ]]; then' \
  '  printf "%s\n" "<!-- external skill edit must survive -->" >> "$SKILL_SOURCE_PATH"' \
  '  : > "$STATE_MARKER"' \
  'fi' \
  'exit "$status"' > "$TEST_ROOT/doctor-skill-tree-ruby-bin/ruby"
chmod +x "$TEST_ROOT/doctor-skill-tree-ruby-bin/ruby"
if PATH="$TEST_ROOT/doctor-skill-tree-ruby-bin:$PATH" \
  REAL_RUBY_BIN="$DOCTOR_SKILL_TREE_REAL_RUBY" \
  VALIDATOR_PATH="$DOCTOR_SKILL_TREE_FIXTURE/scripts/validate-yaml.rb" \
  SKILL_SOURCE_PATH="$DOCTOR_SKILL_TREE_SOURCE" \
  STATE_MARKER="$DOCTOR_SKILL_TREE_MARKER" \
  TMPDIR="$DOCTOR_SKILL_TREE_TMP" \
  HOME="$DOCTOR_SKILL_TREE_HOME" \
  "$DOCTOR_SKILL_TREE_FIXTURE/scripts/doctor.sh" \
  > "$TEST_ROOT/doctor-skill-tree.log" 2>&1; then
  fail "doctor accepted a skill tree changed between source-validation phases"
fi
[[ -f "$DOCTOR_SKILL_TREE_MARKER" ]] ||
  fail "doctor skill-tree fixture did not mutate after its baseline capture"
tail -n 1 "$DOCTOR_SKILL_TREE_SOURCE" |
  grep -qx '<!-- external skill edit must survive -->' ||
  fail "doctor discarded an external skill-tree edit"
grep -q 'skill tree changed before content validation; skill content checks were skipped' \
  "$TEST_ROOT/doctor-skill-tree.log" ||
  fail "doctor reported the wrong skill-tree drift failure"
if grep -q 'OK:   link agents:' "$TEST_ROOT/doctor-skill-tree.log"; then
  fail "doctor ran skill link checks after skill-tree drift"
fi
doctor_skill_tree_temps="$(find "$DOCTOR_SKILL_TREE_TMP" \
  -mindepth 1 -maxdepth 1 -print | wc -l | tr -d ' ')"
[[ "$doctor_skill_tree_temps" -eq 0 ]] ||
  fail "doctor skill-tree drift left temporary files"
pass "doctor rejects pre-content skill-tree drift and skips mixed skill link checks"

DOCTOR_SKILL_LINK_FIXTURE="$(copy_fixture doctor-skill-link-state)"
DOCTOR_SKILL_LINK_HOME="$TEST_ROOT/doctor-skill-link-home"
DOCTOR_SKILL_LINK_SOURCE="$DOCTOR_SKILL_LINK_FIXTURE/skills/z-market-validate/references/quality-bar.md"
DOCTOR_SKILL_LINK_PATH="$DOCTOR_SKILL_LINK_HOME/.agents/skills/z-market-validate"
DOCTOR_SKILL_LINK_TMP="$TEST_ROOT/doctor-skill-link-tmp"
DOCTOR_SKILL_LINK_MARKER="$TEST_ROOT/doctor-skill-link-marker"
DOCTOR_SKILL_LINK_REAL_BASENAME="$(command -v basename)"
HOME="$DOCTOR_SKILL_LINK_HOME" \
  "$DOCTOR_SKILL_LINK_FIXTURE/scripts/setup.sh" --hosts agents >/dev/null
mkdir -p "$DOCTOR_SKILL_LINK_TMP" "$TEST_ROOT/doctor-skill-link-bin"
chmod 700 "$DOCTOR_SKILL_LINK_TMP"
# These single-quoted lines are the source of the generated fault-injection shim.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'result=""' \
  'status=0' \
  'result="$("$REAL_BASENAME_BIN" "$@")" || status=$?' \
  '[[ "$status" -eq 0 ]] || exit "$status"' \
  'printf "%s\n" "$result"' \
  'for argument in "$@"; do' \
  '  if [[ "$argument" == "$INSTALLED_SKILL_PATH" && ! -e "$STATE_MARKER" ]]; then' \
  '    printf "%s\n" "<!-- link-audit skill edit must survive -->" >> "$SKILL_SOURCE_PATH"' \
  '    : > "$STATE_MARKER"' \
  '  fi' \
  'done' > "$TEST_ROOT/doctor-skill-link-bin/basename"
chmod +x "$TEST_ROOT/doctor-skill-link-bin/basename"
if PATH="$TEST_ROOT/doctor-skill-link-bin:$PATH" \
  REAL_BASENAME_BIN="$DOCTOR_SKILL_LINK_REAL_BASENAME" \
  INSTALLED_SKILL_PATH="$DOCTOR_SKILL_LINK_PATH" \
  SKILL_SOURCE_PATH="$DOCTOR_SKILL_LINK_SOURCE" \
  STATE_MARKER="$DOCTOR_SKILL_LINK_MARKER" \
  TMPDIR="$DOCTOR_SKILL_LINK_TMP" \
  HOME="$DOCTOR_SKILL_LINK_HOME" \
  "$DOCTOR_SKILL_LINK_FIXTURE/scripts/doctor.sh" \
  > "$TEST_ROOT/doctor-skill-link.log" 2>&1; then
  fail "doctor accepted skill-tree drift during the installed-link audit"
fi
[[ -f "$DOCTOR_SKILL_LINK_MARKER" ]] ||
  fail "doctor skill-link fixture did not mutate during link inspection"
tail -n 1 "$DOCTOR_SKILL_LINK_SOURCE" |
  grep -qx '<!-- link-audit skill edit must survive -->' ||
  fail "doctor discarded an external skill edit made during link inspection"
grep -q 'OK:   link agents:z-market-validate' "$TEST_ROOT/doctor-skill-link.log" ||
  fail "doctor skill-link fixture did not reach installed skill inspection"
grep -q 'skill tree changed during the installed-link audit; skill link results are invalid' \
  "$TEST_ROOT/doctor-skill-link.log" ||
  fail "doctor reported the wrong installed-link skill-tree drift failure"
[[ ! -e "$DOCTOR_SKILL_LINK_HOME/.zstack/operations.lock" ]] ||
  fail "doctor skill-link drift left the operation lock"
doctor_skill_link_temps="$(find "$DOCTOR_SKILL_LINK_TMP" \
  -mindepth 1 -maxdepth 1 -print | wc -l | tr -d ' ')"
[[ "$doctor_skill_link_temps" -eq 0 ]] ||
  fail "doctor skill-link drift left temporary files"
pass "doctor invalidates installed-link results when the skill tree drifts mid-audit"

CODEX_HOME_FIXTURE="$TEST_ROOT/codex-home"
mkdir -p "$CODEX_HOME_FIXTURE/.zstack"
printf '%s\n' "999999999" > "$CODEX_HOME_FIXTURE/.zstack/operations.lock"
chmod 600 "$CODEX_HOME_FIXTURE/.zstack/operations.lock"
HOME="$CODEX_HOME_FIXTURE" "$INSTALL_FIXTURE/scripts/setup.sh" --hosts codex > "$TEST_ROOT/stale-operation-lock.log" 2>&1
grep -q "Recovered stale zstack setup/unlink lock" "$TEST_ROOT/stale-operation-lock.log" || fail "setup did not recover a stale operation lock"
[[ ! -e "$CODEX_HOME_FIXTURE/.zstack/operations.lock" ]] || fail "setup left a recovered operation lock"
[[ -L "$CODEX_HOME_FIXTURE/.codex/skills/z-market-validate" ]] || fail "host filter did not install Codex skills"
[[ ! -e "$CODEX_HOME_FIXTURE/.codex/skills/z-write-prd" ]] || fail "setup ignored a skill's host allowlist"
[[ ! -e "$CODEX_HOME_FIXTURE/.agents/skills/z-market-validate" ]] || fail "host filter installed an unrequested host"
pass "setup respects host filters and per-skill hosts"

if (cd / && HOME="$TEST_ROOT/project-home" "$INSTALL_FIXTURE/scripts/setup.sh" --project --hosts agents > "$TEST_ROOT/project-root.log" 2>&1); then
  fail "setup accepted --project from filesystem root"
fi
grep -q "Refusing --project install from filesystem root" "$TEST_ROOT/project-root.log" || fail "setup reported the wrong project-root failure"
[[ ! -e "$TEST_ROOT/project-home/.agents" ]] || fail "setup wrote global links before rejecting the project root"
pass "setup rejects unsafe project roots before writing"

CONTROL_PROJECT="$TEST_ROOT/project-control"$'\t'"path"
CONTROL_PROJECT_HOME="$TEST_ROOT/project-control-home"
mkdir -p "$CONTROL_PROJECT" "$CONTROL_PROJECT_HOME"
if (cd "$CONTROL_PROJECT" && HOME="$CONTROL_PROJECT_HOME" "$INSTALL_FIXTURE/scripts/setup.sh" --project --hosts agents > "$TEST_ROOT/project-control.log" 2>&1); then
  fail "setup accepted a project path containing a control character"
fi
grep -q "Project path cannot contain '|' or control characters" "$TEST_ROOT/project-control.log" || fail "setup reported the wrong project control-character failure"
[[ ! -e "$CONTROL_PROJECT_HOME/.zstack" && ! -e "$CONTROL_PROJECT_HOME/.agents" ]] || fail "setup wrote global state before rejecting a project control character"
pass "setup rejects control characters in project manifest paths"

if HOME=/ "$INSTALL_FIXTURE/scripts/setup.sh" --hosts agents > "$TEST_ROOT/home.log" 2>&1; then
  fail "setup accepted an unsafe HOME"
fi
grep -q "Unsafe HOME value" "$TEST_ROOT/home.log" || fail "setup reported the wrong HOME failure"
pass "setup rejects unsafe HOME values"

if HOME=/tmp/.. "$INSTALL_FIXTURE/scripts/setup.sh" --hosts agents > "$TEST_ROOT/home-alias.log" 2>&1; then
  fail "setup accepted a HOME alias that resolves to filesystem root"
fi
grep -q "resolves to filesystem root" "$TEST_ROOT/home-alias.log" || fail "setup reported the wrong resolved HOME failure"
pass "setup rejects HOME aliases that resolve to filesystem root"

CONTROL_HOME="$TEST_ROOT/home-control"$'\r'"path"
mkdir -p "$CONTROL_HOME"
if HOME="$CONTROL_HOME" "$INSTALL_FIXTURE/scripts/setup.sh" --hosts agents > "$TEST_ROOT/home-control.log" 2>&1; then
  fail "setup accepted a HOME containing a control character"
fi
grep -q "HOME cannot contain '|' or control characters" "$TEST_ROOT/home-control.log" || fail "setup reported the wrong HOME control-character failure"
[[ ! -e "$CONTROL_HOME/.zstack" && ! -e "$CONTROL_HOME/.agents" ]] || fail "setup wrote state after rejecting a HOME control character"
pass "setup rejects control characters in HOME before writing"

STATE_LINK_HOME="$TEST_ROOT/state-link-home"
STATE_LINK_TARGET="$TEST_ROOT/state-link-target"
mkdir -p "$STATE_LINK_HOME" "$STATE_LINK_TARGET"
ln -s "$STATE_LINK_TARGET" "$STATE_LINK_HOME/.zstack"
if HOME="$STATE_LINK_HOME" "$INSTALL_FIXTURE/scripts/setup.sh" --hosts agents > "$TEST_ROOT/state-link-setup.log" 2>&1; then
  fail "setup accepted a symlinked zstack state directory"
fi
grep -q "zstack state directory must not be a symlink" "$TEST_ROOT/state-link-setup.log" || fail "setup reported the wrong state-directory failure"
[[ ! -e "$STATE_LINK_TARGET/operations.lock" && ! -e "$STATE_LINK_TARGET/links" ]] || fail "setup wrote through a symlinked state directory"
[[ ! -e "$STATE_LINK_HOME/.agents" ]] || fail "setup changed host roots after rejecting a symlinked state directory"
if HOME="$STATE_LINK_HOME" "$INSTALL_FIXTURE/scripts/unlink.sh" > "$TEST_ROOT/state-link-unlink.log" 2>&1; then
  fail "unlink accepted a symlinked zstack state directory"
fi
grep -q "zstack state directory must not be a symlink" "$TEST_ROOT/state-link-unlink.log" || fail "unlink reported the wrong state-directory failure"
pass "setup and unlink reject state-directory symlink escapes"

STATE_FILE_HOME="$TEST_ROOT/state-file-home"
STATE_FILE_TARGET="$TEST_ROOT/state-file-target"
mkdir -p "$STATE_FILE_HOME/.zstack"
printf '%s\n' "preserve manifest target" > "$STATE_FILE_TARGET"
ln -s "$STATE_FILE_TARGET" "$STATE_FILE_HOME/.zstack/links"
if HOME="$STATE_FILE_HOME" "$INSTALL_FIXTURE/scripts/setup.sh" --hosts agents > "$TEST_ROOT/state-file-setup.log" 2>&1; then
  fail "setup accepted a symlinked install manifest"
fi
grep -q "zstack install manifest must not be a symlink" "$TEST_ROOT/state-file-setup.log" || fail "setup reported the wrong manifest-file failure"
[[ ! -e "$STATE_FILE_HOME/.agents" ]] || fail "setup changed host roots after rejecting a symlinked manifest"
grep -qx "preserve manifest target" "$STATE_FILE_TARGET" || fail "setup changed the manifest symlink target"
if HOME="$STATE_FILE_HOME" "$INSTALL_FIXTURE/scripts/unlink.sh" > "$TEST_ROOT/state-file-unlink.log" 2>&1; then
  fail "unlink accepted a symlinked install manifest"
fi
grep -q "zstack install manifest must not be a symlink" "$TEST_ROOT/state-file-unlink.log" || fail "unlink reported the wrong manifest-file failure"
if HOME="$STATE_FILE_HOME" "$INSTALL_FIXTURE/scripts/doctor.sh" > "$TEST_ROOT/state-file-doctor.log" 2>&1; then
  fail "doctor accepted a symlinked install manifest"
fi
grep -q "zstack install manifest must not be a symlink" "$TEST_ROOT/state-file-doctor.log" || fail "doctor reported the wrong manifest-file failure"

unlink "$STATE_FILE_HOME/.zstack/links"
printf '%s\n' "preserve root target" > "$STATE_FILE_TARGET"
ln -s "$STATE_FILE_TARGET" "$STATE_FILE_HOME/.zstack/root"
if HOME="$STATE_FILE_HOME" "$INSTALL_FIXTURE/scripts/setup.sh" --hosts agents > "$TEST_ROOT/state-root-setup.log" 2>&1; then
  fail "setup accepted a symlinked root record"
fi
grep -q "zstack root record must not be a symlink" "$TEST_ROOT/state-root-setup.log" || fail "setup reported the wrong root-file failure"
if HOME="$STATE_FILE_HOME" "$INSTALL_FIXTURE/scripts/unlink.sh" > "$TEST_ROOT/state-root-unlink.log" 2>&1; then
  fail "unlink accepted a symlinked root record"
fi
grep -q "zstack root record must not be a symlink" "$TEST_ROOT/state-root-unlink.log" || fail "unlink reported the wrong root-file failure"
grep -qx "preserve root target" "$STATE_FILE_TARGET" || fail "setup or unlink changed the root symlink target"

unlink "$STATE_FILE_HOME/.zstack/root"
printf '%s\n' "$INSTALL_FIXTURE" > "$STATE_FILE_TARGET"
ln "$STATE_FILE_TARGET" "$STATE_FILE_HOME/.zstack/root"
if HOME="$STATE_FILE_HOME" "$INSTALL_FIXTURE/scripts/setup.sh" --hosts agents > "$TEST_ROOT/state-hardlink-setup.log" 2>&1; then
  fail "setup accepted a hardlinked root record"
fi
if HOME="$STATE_FILE_HOME" "$INSTALL_FIXTURE/scripts/unlink.sh" > "$TEST_ROOT/state-hardlink-unlink.log" 2>&1; then
  fail "unlink accepted a hardlinked root record"
fi
if HOME="$STATE_FILE_HOME" "$INSTALL_FIXTURE/scripts/doctor.sh" > "$TEST_ROOT/state-hardlink-doctor.log" 2>&1; then
  fail "doctor accepted a hardlinked root record"
fi
for state_hardlink_log in \
  "$TEST_ROOT/state-hardlink-setup.log" \
  "$TEST_ROOT/state-hardlink-unlink.log" \
  "$TEST_ROOT/state-hardlink-doctor.log"; do
  grep -q 'zstack root record must have exactly one hard link' "$state_hardlink_log" ||
    fail "state command reported the wrong hardlinked root-record failure"
done
grep -qx "$INSTALL_FIXTURE" "$STATE_FILE_TARGET" ||
  fail "state command changed a hardlinked root-record alias"
grep -qx "$INSTALL_FIXTURE" "$STATE_FILE_HOME/.zstack/root" ||
  fail "state command changed a hardlinked root record"
[[ ! -e "$STATE_FILE_HOME/.agents" ]] ||
  fail "setup changed host roots after rejecting a hardlinked root record"
pass "setup, unlink, and doctor reject unsafe or hardlinked state leaves before acting"

OVERSIZE_STATE_HOME="$TEST_ROOT/oversize-state-home"
mkdir -p "$OVERSIZE_STATE_HOME/.zstack"
dd if=/dev/zero of="$OVERSIZE_STATE_HOME/.zstack/links" bs=$((ZSTACK_LINK_MANIFEST_MAX_BYTES + 1)) count=1 2>/dev/null
if HOME="$OVERSIZE_STATE_HOME" "$INSTALL_FIXTURE/scripts/setup.sh" --hosts agents > "$TEST_ROOT/oversize-manifest-setup.log" 2>&1; then
  fail "setup accepted an oversized install manifest"
fi
grep -q "zstack install manifest exceeds the ${ZSTACK_LINK_MANIFEST_MAX_BYTES}-byte safety limit" "$TEST_ROOT/oversize-manifest-setup.log" || fail "setup reported the wrong oversized-manifest failure"
[[ ! -e "$OVERSIZE_STATE_HOME/.agents" ]] || fail "setup changed host roots before rejecting an oversized manifest"
if HOME="$OVERSIZE_STATE_HOME" "$INSTALL_FIXTURE/scripts/unlink.sh" > "$TEST_ROOT/oversize-manifest-unlink.log" 2>&1; then
  fail "unlink accepted an oversized install manifest"
fi
if HOME="$OVERSIZE_STATE_HOME" "$INSTALL_FIXTURE/scripts/doctor.sh" > "$TEST_ROOT/oversize-manifest-doctor.log" 2>&1; then
  fail "doctor accepted an oversized install manifest"
fi
grep -q "zstack install manifest exceeds the ${ZSTACK_LINK_MANIFEST_MAX_BYTES}-byte safety limit" "$TEST_ROOT/oversize-manifest-unlink.log" || fail "unlink reported the wrong oversized-manifest failure"
grep -q "zstack install manifest exceeds the ${ZSTACK_LINK_MANIFEST_MAX_BYTES}-byte safety limit" "$TEST_ROOT/oversize-manifest-doctor.log" || fail "doctor reported the wrong oversized-manifest failure"

: > "$OVERSIZE_STATE_HOME/.zstack/links"
dd if=/dev/zero of="$OVERSIZE_STATE_HOME/.zstack/root" bs=$((ZSTACK_ROOT_RECORD_MAX_BYTES + 1)) count=1 2>/dev/null
if HOME="$OVERSIZE_STATE_HOME" "$INSTALL_FIXTURE/scripts/setup.sh" --hosts agents > "$TEST_ROOT/oversize-root-setup.log" 2>&1; then
  fail "setup accepted an oversized root record"
fi
if HOME="$OVERSIZE_STATE_HOME" "$INSTALL_FIXTURE/scripts/unlink.sh" > "$TEST_ROOT/oversize-root-unlink.log" 2>&1; then
  fail "unlink accepted an oversized root record"
fi
if HOME="$OVERSIZE_STATE_HOME" "$INSTALL_FIXTURE/scripts/doctor.sh" > "$TEST_ROOT/oversize-root-doctor.log" 2>&1; then
  fail "doctor accepted an oversized root record"
fi
grep -q "zstack root record exceeds the ${ZSTACK_ROOT_RECORD_MAX_BYTES}-byte safety limit" "$TEST_ROOT/oversize-root-setup.log" || fail "setup reported the wrong oversized-root failure"
grep -q "zstack root record exceeds the ${ZSTACK_ROOT_RECORD_MAX_BYTES}-byte safety limit" "$TEST_ROOT/oversize-root-unlink.log" || fail "unlink reported the wrong oversized-root failure"
grep -q "zstack root record exceeds the ${ZSTACK_ROOT_RECORD_MAX_BYTES}-byte safety limit" "$TEST_ROOT/oversize-root-doctor.log" || fail "doctor reported the wrong oversized-root failure"
pass "setup, unlink, and doctor reject oversized state before acting"

NUL_STATE_HOME="$TEST_ROOT/nul-state-home"
NUL_STATE_LINK="$TEST_ROOT/nul-state-managed-link"
mkdir -p "$NUL_STATE_HOME/.zstack"
ln -s "$INSTALL_FIXTURE/skills/z-market-validate" "$NUL_STATE_LINK"
printf '%s|%s\0ignored-suffix\n' "$INSTALL_FIXTURE" "$NUL_STATE_LINK" > "$NUL_STATE_HOME/.zstack/links"
if HOME="$NUL_STATE_HOME" "$INSTALL_FIXTURE/scripts/setup.sh" --hosts agents > "$TEST_ROOT/nul-manifest-setup.log" 2>&1; then
  fail "setup accepted a NUL byte in the install manifest"
fi
if HOME="$NUL_STATE_HOME" "$INSTALL_FIXTURE/scripts/unlink.sh" > "$TEST_ROOT/nul-manifest-unlink.log" 2>&1; then
  fail "unlink accepted a NUL byte in the install manifest"
fi
if HOME="$NUL_STATE_HOME" "$INSTALL_FIXTURE/scripts/doctor.sh" > "$TEST_ROOT/nul-manifest-doctor.log" 2>&1; then
  fail "doctor accepted a NUL byte in the install manifest"
fi
grep -q "zstack install manifest contains a NUL byte" "$TEST_ROOT/nul-manifest-setup.log" || fail "setup reported the wrong NUL-manifest failure"
grep -q "zstack install manifest contains a NUL byte" "$TEST_ROOT/nul-manifest-unlink.log" || fail "unlink reported the wrong NUL-manifest failure"
grep -q "zstack install manifest contains a NUL byte" "$TEST_ROOT/nul-manifest-doctor.log" || fail "doctor reported the wrong NUL-manifest failure"
[[ -L "$NUL_STATE_LINK" ]] || fail "unlink acted on a path truncated at a manifest NUL byte"
[[ ! -e "$NUL_STATE_HOME/.agents" ]] || fail "setup changed host roots before rejecting a manifest NUL byte"

: > "$NUL_STATE_HOME/.zstack/links"
printf '%s\0ignored-suffix\n' "$INSTALL_FIXTURE" > "$NUL_STATE_HOME/.zstack/root"
if HOME="$NUL_STATE_HOME" "$INSTALL_FIXTURE/scripts/setup.sh" --hosts agents > "$TEST_ROOT/nul-root-setup.log" 2>&1; then
  fail "setup accepted a NUL byte in the root record"
fi
if HOME="$NUL_STATE_HOME" "$INSTALL_FIXTURE/scripts/unlink.sh" > "$TEST_ROOT/nul-root-unlink.log" 2>&1; then
  fail "unlink accepted a NUL byte in the root record"
fi
if HOME="$NUL_STATE_HOME" "$INSTALL_FIXTURE/scripts/doctor.sh" > "$TEST_ROOT/nul-root-doctor.log" 2>&1; then
  fail "doctor accepted a NUL byte in the root record"
fi
grep -q "zstack root record contains a NUL byte" "$TEST_ROOT/nul-root-setup.log" || fail "setup reported the wrong NUL-root failure"
grep -q "zstack root record contains a NUL byte" "$TEST_ROOT/nul-root-unlink.log" || fail "unlink reported the wrong NUL-root failure"
grep -q "zstack root record contains a NUL byte" "$TEST_ROOT/nul-root-doctor.log" || fail "doctor reported the wrong NUL-root failure"
pass "setup, unlink, and doctor reject NUL state without truncated-path actions"

ROOT_FORMAT_HOME="$TEST_ROOT/root-format-home"
mkdir -p "$ROOT_FORMAT_HOME/.zstack"
: > "$ROOT_FORMAT_HOME/.zstack/links"
printf '%s\n\n' "$INSTALL_FIXTURE" > "$ROOT_FORMAT_HOME/.zstack/root"
if HOME="$ROOT_FORMAT_HOME" "$INSTALL_FIXTURE/scripts/setup.sh" --hosts agents > "$TEST_ROOT/root-format-setup.log" 2>&1; then
  fail "setup accepted a multi-line root record"
fi
if HOME="$ROOT_FORMAT_HOME" "$INSTALL_FIXTURE/scripts/unlink.sh" > "$TEST_ROOT/root-format-unlink.log" 2>&1; then
  fail "unlink accepted a multi-line root record"
fi
if HOME="$ROOT_FORMAT_HOME" "$INSTALL_FIXTURE/scripts/doctor.sh" > "$TEST_ROOT/root-format-doctor.log" 2>&1; then
  fail "doctor accepted a multi-line root record"
fi
grep -q "zstack root record must contain exactly one safe absolute path" "$TEST_ROOT/root-format-setup.log" || fail "setup reported the wrong root-format failure"
grep -q "zstack root record must contain exactly one safe absolute path" "$TEST_ROOT/root-format-unlink.log" || fail "unlink reported the wrong root-format failure"
grep -q "zstack root record must contain exactly one safe absolute path" "$TEST_ROOT/root-format-doctor.log" || fail "doctor reported the wrong root-format failure"
[[ ! -e "$ROOT_FORMAT_HOME/.agents" ]] || fail "setup changed host roots before rejecting root-record drift"
pass "setup, unlink, and doctor reject non-canonical root records"

STATE_RACE_FIXTURE="$(copy_fixture state-race)"
STATE_RACE_HOME="$TEST_ROOT/state-race-home"
mkdir -p "$STATE_RACE_HOME/.zstack"
: > "$STATE_RACE_HOME/.zstack/links"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'printf "/tmp/repo|/tmp/link\0swapped-after-preflight\n" > "$HOME/.zstack/links"' \
  'exit 0' > "$STATE_RACE_FIXTURE/scripts/doctor.sh"
chmod +x "$STATE_RACE_FIXTURE/scripts/doctor.sh"
if HOME="$STATE_RACE_HOME" "$STATE_RACE_FIXTURE/scripts/setup.sh" --hosts agents > "$TEST_ROOT/state-race-setup.log" 2>&1; then
  fail "setup consumed state replaced after its preflight check"
fi
grep -q "zstack install manifest contains a NUL byte" "$TEST_ROOT/state-race-setup.log" || fail "setup did not revalidate replaced state under the mutation lock"
[[ ! -e "$STATE_RACE_HOME/.agents" ]] || fail "setup created host links before its locked state recheck"
[[ ! -e "$STATE_RACE_HOME/.zstack/operations.lock" ]] || fail "setup left its lock after rejecting replaced state"
pass "setup revalidates state under the mutation lock before linking"

CORRUPT_MANIFEST_FIXTURE="$(copy_fixture corrupt-manifest)"
CORRUPT_MANIFEST_HOME="$TEST_ROOT/corrupt-manifest-home"
CORRUPT_MANIFEST_LINK="$TEST_ROOT/corrupt-manifest"$'\033[31m'"link"
mkdir -p "$CORRUPT_MANIFEST_HOME/.zstack"
ln -s "$CORRUPT_MANIFEST_FIXTURE/skills/z-market-validate" "$CORRUPT_MANIFEST_LINK"
printf '%s|%s\n' "$CORRUPT_MANIFEST_FIXTURE" "$CORRUPT_MANIFEST_LINK" > "$CORRUPT_MANIFEST_HOME/.zstack/links"
HOME="$CORRUPT_MANIFEST_HOME" "$CORRUPT_MANIFEST_FIXTURE/scripts/setup.sh" --hosts agents > "$TEST_ROOT/corrupt-manifest-setup.log" 2>&1
grep -q "preserving unsafe install manifest line 1" "$TEST_ROOT/corrupt-manifest-setup.log" || fail "setup did not report a corrupt manifest record"
grep -Fqx "$CORRUPT_MANIFEST_FIXTURE|$CORRUPT_MANIFEST_LINK" "$CORRUPT_MANIFEST_HOME/.zstack/links" || fail "setup discarded a recoverable corrupt manifest record"
[[ -L "$CORRUPT_MANIFEST_LINK" ]] || fail "setup acted on a corrupt manifest record"
if LC_ALL=C grep -q $'\033' "$TEST_ROOT/corrupt-manifest-setup.log"; then
  fail "setup emitted a raw terminal control character from the manifest"
fi

HOME="$CORRUPT_MANIFEST_HOME" "$CORRUPT_MANIFEST_FIXTURE/scripts/unlink.sh" > "$TEST_ROOT/corrupt-manifest-unlink.log" 2>&1
grep -q "preserving unsafe install manifest line 1" "$TEST_ROOT/corrupt-manifest-unlink.log" || fail "unlink did not report a corrupt manifest record"
grep -Fqx "$CORRUPT_MANIFEST_FIXTURE|$CORRUPT_MANIFEST_LINK" "$CORRUPT_MANIFEST_HOME/.zstack/links" || fail "unlink discarded a recoverable corrupt manifest record"
[[ -L "$CORRUPT_MANIFEST_LINK" ]] || fail "unlink acted on a corrupt manifest record"
[[ ! -e "$CORRUPT_MANIFEST_HOME/.agents/skills/z-market-validate" ]] || fail "unlink stopped before removing valid managed links"
if LC_ALL=C grep -q $'\033' "$TEST_ROOT/corrupt-manifest-unlink.log"; then
  fail "unlink emitted a raw terminal control character from the manifest"
fi
unlink "$CORRUPT_MANIFEST_LINK"
pass "setup and unlink preserve corrupt manifest records without acting on or emitting them"

SETUP_SOURCE_FIXTURE="$(copy_fixture setup-source-drift)"
SETUP_SOURCE_HOME="$TEST_ROOT/setup-source-home"
SETUP_SOURCE_PATH="$SETUP_SOURCE_HOME/.zstack/links"
SETUP_SOURCE_MISSING_LINK="$SETUP_SOURCE_HOME/.agents/skills/z-market-validate"
HOME="$SETUP_SOURCE_HOME" \
  "$SETUP_SOURCE_FIXTURE/scripts/setup.sh" --hosts agents >/dev/null
rm -f "$SETUP_SOURCE_MISSING_LINK"
mkdir -p "$TEST_ROOT/setup-source-cp-bin"
# These single-quoted lines are the source of the generated fault-injection shim.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  '"$REAL_CP_BIN" "$@"' \
  'if [[ "${1:-}" == "$MANIFEST_PATH" ]]; then' \
  '  printf "%s\n" "external setup source edit must survive" >> "$MANIFEST_PATH"' \
  'fi' > "$TEST_ROOT/setup-source-cp-bin/cp"
chmod +x "$TEST_ROOT/setup-source-cp-bin/cp"
if PATH="$TEST_ROOT/setup-source-cp-bin:$PATH" \
  REAL_CP_BIN="$(command -v cp)" \
  MANIFEST_PATH="$SETUP_SOURCE_PATH" \
  HOME="$SETUP_SOURCE_HOME" \
  "$SETUP_SOURCE_FIXTURE/scripts/setup.sh" --hosts agents \
  > "$TEST_ROOT/setup-source-drift.log" 2>&1; then
  fail "setup accepted an install manifest changed while it was snapshotted"
fi
tail -n 1 "$SETUP_SOURCE_PATH" |
  grep -qx 'external setup source edit must survive' ||
  fail "setup cleanup discarded a source manifest edit"
[[ ! -e "$SETUP_SOURCE_MISSING_LINK" ]] ||
  fail "setup created a managed link before validating its manifest snapshot"
[[ -f "$SETUP_SOURCE_HOME/.zstack/root" ]] ||
  fail "setup removed the root record after source manifest drift"
[[ ! -e "$SETUP_SOURCE_HOME/.zstack/operations.lock" ]] ||
  fail "setup source manifest drift left the operation lock"
grep -q 'Install manifest changed while setup input was snapshotted' "$TEST_ROOT/setup-source-drift.log" ||
  fail "setup reported the wrong source manifest drift failure"
setup_source_temps="$(find "$SETUP_SOURCE_HOME/.zstack" -maxdepth 1 \( -name '*.pending.*' -o -name '*.source.*' -o -name '*.next.*' -o -name '*.merged.*' -o -name '*.expected.*' \) -print | wc -l | tr -d ' ')"
[[ "$setup_source_temps" -eq 0 ]] ||
  fail "setup source manifest drift left transaction files"
pass "setup validates an exact manifest snapshot before changing links"

SETUP_SOURCE_HARDLINK_FIXTURE="$(copy_fixture setup-source-hardlink)"
SETUP_SOURCE_HARDLINK_HOME="$TEST_ROOT/setup-source-hardlink-home"
SETUP_SOURCE_HARDLINK_ALIAS="$TEST_ROOT/setup-source-hardlink-alias"
HOME="$SETUP_SOURCE_HARDLINK_HOME" \
  "$SETUP_SOURCE_HARDLINK_FIXTURE/scripts/setup.sh" --hosts agents >/dev/null
cp "$SETUP_SOURCE_HARDLINK_HOME/.zstack/links" \
  "$TEST_ROOT/setup-source-hardlink-links.before"
mkdir -p "$TEST_ROOT/setup-source-hardlink-cp-bin"
# These single-quoted lines are the source of the generated fault-injection shim.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  '"$REAL_CP_BIN" "$@"' \
  'if [[ "${2:-}" == */links.source.* ]]; then' \
  '  ln "$2" "$SNAPSHOT_ALIAS"' \
  'fi' > "$TEST_ROOT/setup-source-hardlink-cp-bin/cp"
chmod +x "$TEST_ROOT/setup-source-hardlink-cp-bin/cp"
if PATH="$TEST_ROOT/setup-source-hardlink-cp-bin:$PATH" \
  REAL_CP_BIN="$(command -v cp)" \
  SNAPSHOT_ALIAS="$SETUP_SOURCE_HARDLINK_ALIAS" \
  HOME="$SETUP_SOURCE_HARDLINK_HOME" \
  "$SETUP_SOURCE_HARDLINK_FIXTURE/scripts/setup.sh" --hosts agents \
  > "$TEST_ROOT/setup-source-hardlink.log" 2>&1; then
  fail "setup accepted a hardlinked install-manifest source snapshot"
fi
cmp -s "$TEST_ROOT/setup-source-hardlink-links.before" \
  "$SETUP_SOURCE_HARDLINK_HOME/.zstack/links" ||
  fail "setup changed the manifest after rejecting a hardlinked source snapshot"
[[ -L "$SETUP_SOURCE_HARDLINK_HOME/.agents/skills/z-market-validate" ]] ||
  fail "setup changed managed links after rejecting a hardlinked source snapshot"
[[ -f "$SETUP_SOURCE_HARDLINK_HOME/.zstack/root" ]] ||
  fail "setup removed root state after rejecting a hardlinked source snapshot"
[[ ! -e "$SETUP_SOURCE_HARDLINK_HOME/.zstack/operations.lock" ]] ||
  fail "setup hardlinked source snapshot left the operation lock"
grep -q 'Install manifest changed while setup input was snapshotted' \
  "$TEST_ROOT/setup-source-hardlink.log" ||
  fail "setup reported the wrong hardlinked source-snapshot failure"
setup_source_hardlink_temp="$(find "$SETUP_SOURCE_HARDLINK_HOME/.zstack" \
  -maxdepth 1 -name 'links.source.*' -print -quit)"
[[ -n "$setup_source_hardlink_temp" ]] ||
  fail "setup removed a source snapshot whose inode gained an external hardlink"
[[ "$(zstack_file_link_count "$setup_source_hardlink_temp")" == "2" ]] ||
  fail "setup hardlink fixture did not preserve the raced snapshot inode"
unlink "$SETUP_SOURCE_HARDLINK_ALIAS"
unlink "$setup_source_hardlink_temp"
pass "setup rejects hardlinked manifest source snapshots before mutation"

STALE_LINK_RACE_FIXTURE="$(copy_fixture stale-link-race)"
STALE_LINK_RACE_HOME="$TEST_ROOT/stale-link-race-home"
STALE_LINK_RACE_PATH="$STALE_LINK_RACE_HOME/.agents/skills/z-raced-stale"
HOME="$STALE_LINK_RACE_HOME" \
  "$STALE_LINK_RACE_FIXTURE/scripts/setup.sh" --hosts agents >/dev/null
ln -s "$STALE_LINK_RACE_FIXTURE/skills/z-market-validate" "$STALE_LINK_RACE_PATH"
mkdir -p "$TEST_ROOT/stale-link-race-mv-bin"
# These single-quoted lines are the source of the generated fault-injection shim.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'if [[ "${1:-}" == "$RACED_LINK_PATH" ]]; then' \
  '  unlink "$RACED_LINK_PATH"' \
  '  printf "%s\n" "external stale-link replacement must survive" > "$RACED_LINK_PATH"' \
  'fi' \
  'exec "$REAL_MV_BIN" "$@"' > "$TEST_ROOT/stale-link-race-mv-bin/mv"
chmod +x "$TEST_ROOT/stale-link-race-mv-bin/mv"
if PATH="$TEST_ROOT/stale-link-race-mv-bin:$PATH" \
  REAL_MV_BIN="$(command -v mv)" \
  RACED_LINK_PATH="$STALE_LINK_RACE_PATH" \
  HOME="$STALE_LINK_RACE_HOME" \
  "$STALE_LINK_RACE_FIXTURE/scripts/setup.sh" --hosts agents \
  > "$TEST_ROOT/stale-link-race.log" 2>&1; then
  fail "setup accepted a stale link replaced during safe removal"
fi
grep -qx 'external stale-link replacement must survive' "$STALE_LINK_RACE_PATH" ||
  fail "setup removed or displaced a raced stale-link replacement"
stale_link_quarantines="$(find "$STALE_LINK_RACE_HOME/.agents/skills" -maxdepth 1 -name 'z-raced-stale.zstack-remove.*' -print | wc -l | tr -d ' ')"
[[ "$stale_link_quarantines" -eq 0 ]] ||
  fail "setup left a restored stale-link quarantine directory"
[[ ! -e "$STALE_LINK_RACE_HOME/.zstack/operations.lock" ]] ||
  fail "setup stale-link replacement race left the operation lock"
grep -q 'stale link changed before safe removal' "$TEST_ROOT/stale-link-race.log" ||
  fail "setup reported the wrong stale-link replacement failure"
stale_link_temps="$(find "$STALE_LINK_RACE_HOME/.zstack" -maxdepth 1 \( -name '*.pending.*' -o -name '*.source.*' -o -name '*.next.*' -o -name '*.merged.*' -o -name '*.expected.*' \) -print | wc -l | tr -d ' ')"
[[ "$stale_link_temps" -eq 0 ]] ||
  fail "setup stale-link replacement race left transaction files"
pass "setup preserves stale links replaced during identity-safe removal"

ROLLBACK_FIXTURE="$(copy_fixture link-rollback)"
ROLLBACK_HOME="$TEST_ROOT/rollback-home"
mkdir -p "$ROLLBACK_HOME/.agents/skills/z-market-validate" "$TEST_ROOT/fail-ln-bin"
printf '%s\n' "keep me" > "$ROLLBACK_HOME/.agents/skills/z-market-validate/owner.txt"
printf '%s\n' '#!/usr/bin/env bash' 'exit 1' > "$TEST_ROOT/fail-ln-bin/ln"
chmod +x "$TEST_ROOT/fail-ln-bin/ln"
if PATH="$TEST_ROOT/fail-ln-bin:$PATH" HOME="$ROLLBACK_HOME" "$ROLLBACK_FIXTURE/scripts/setup.sh" --hosts agents --force > "$TEST_ROOT/link-rollback.log" 2>&1; then
  fail "setup reported success after link creation failures"
fi
[[ -f "$ROLLBACK_HOME/.agents/skills/z-market-validate/owner.txt" ]] || fail "setup did not restore a conflict after link failure"
rollback_backups="$(find "$ROLLBACK_HOME/.agents/skills" -maxdepth 1 -name 'z-market-validate.zstack-backup-*' | wc -l | tr -d ' ')"
[[ "$rollback_backups" -eq 0 ]] || fail "setup left a backup after successful rollback"
[[ ! -e "$ROLLBACK_HOME/.zstack/root" ]] || fail "failed setup wrote a root record"
[[ ! -e "$ROLLBACK_HOME/.zstack/links" ]] || fail "failed setup wrote a link manifest"
pass "setup restores conflicts when symlink creation fails"

COMMIT_FIXTURE="$(copy_fixture manifest-commit)"
COMMIT_HOME="$TEST_ROOT/manifest-commit-home"
mkdir -p "$TEST_ROOT/fail-commit-bin"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'if [[ "${1:-}" == */links.merged.* && "${2:-}" == "$MANIFEST_PATH" ]]; then' \
  '  exit 1' \
  'fi' \
  'exec "$REAL_MV_BIN" "$@"' > "$TEST_ROOT/fail-commit-bin/mv"
chmod +x "$TEST_ROOT/fail-commit-bin/mv"
if PATH="$TEST_ROOT/fail-commit-bin:$PATH" \
  REAL_MV_BIN="$(command -v mv)" \
  MANIFEST_PATH="$COMMIT_HOME/.zstack/links" \
  HOME="$COMMIT_HOME" "$COMMIT_FIXTURE/scripts/setup.sh" --hosts agents \
  > "$TEST_ROOT/manifest-commit.log" 2>&1; then
  fail "setup reported success after manifest commit failure"
fi
[[ -L "$COMMIT_HOME/.agents/skills/z-market-validate" ]] || fail "manifest failure unexpectedly rolled back a valid link"
[[ ! -e "$COMMIT_HOME/.zstack/operations.lock" ]] || fail "manifest failure left the operation lock"
[[ ! -e "$COMMIT_HOME/.zstack/links" ]] || fail "manifest failure published a partial link manifest"
commit_temps="$(find "$COMMIT_HOME/.zstack" -maxdepth 1 \( -name '*.pending.*' -o -name '*.next.*' -o -name '*.merged.*' \) -print | wc -l | tr -d ' ')"
[[ "$commit_temps" -eq 0 ]] || fail "manifest failure left transaction files"

HOME="$COMMIT_HOME" "$COMMIT_FIXTURE/scripts/setup.sh" --hosts agents >/dev/null
commit_manifest_count="$(awk -F'|' -v root="$COMMIT_FIXTURE" '$1 == root {count++} END {print count + 0}' "$COMMIT_HOME/.zstack/links")"
[[ "$commit_manifest_count" -eq 5 ]] || fail "setup did not recover and register existing links after manifest failure"
HOME="$COMMIT_HOME" "$COMMIT_FIXTURE/scripts/unlink.sh" >/dev/null
pass "setup cleans failed manifest transactions and recovers on the next run"

MANIFEST_POSTPUBLISH_FIXTURE="$(copy_fixture manifest-postpublish-edit)"
MANIFEST_POSTPUBLISH_HOME="$TEST_ROOT/manifest-postpublish-home"
MANIFEST_POSTPUBLISH_PATH="$MANIFEST_POSTPUBLISH_HOME/.zstack/links"
mkdir -p "$TEST_ROOT/manifest-postpublish-mv-bin"
# These single-quoted lines are the source of the generated fault-injection shim.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  '"$REAL_MV_BIN" "$@"' \
  'if [[ "$2" == "$MANIFEST_PATH" ]]; then' \
  '  printf "%s\n" "external manifest edit must survive" >> "$MANIFEST_PATH"' \
  'fi' > "$TEST_ROOT/manifest-postpublish-mv-bin/mv"
chmod +x "$TEST_ROOT/manifest-postpublish-mv-bin/mv"
if PATH="$TEST_ROOT/manifest-postpublish-mv-bin:$PATH" \
  REAL_MV_BIN="$(command -v mv)" \
  MANIFEST_PATH="$MANIFEST_POSTPUBLISH_PATH" \
  HOME="$MANIFEST_POSTPUBLISH_HOME" \
  "$MANIFEST_POSTPUBLISH_FIXTURE/scripts/setup.sh" --hosts agents \
  > "$TEST_ROOT/manifest-postpublish-edit.log" 2>&1; then
  fail "setup accepted an install manifest edited during publication"
fi
tail -n 1 "$MANIFEST_POSTPUBLISH_PATH" |
  grep -qx 'external manifest edit must survive' ||
  fail "setup cleanup discarded a post-publish manifest edit"
[[ ! -e "$MANIFEST_POSTPUBLISH_HOME/.zstack/root" ]] ||
  fail "setup wrote a root record after manifest post-publish drift"
[[ ! -e "$MANIFEST_POSTPUBLISH_HOME/.zstack/operations.lock" ]] ||
  fail "setup manifest post-publish drift left the operation lock"
grep -q 'Install manifest changed during publication' "$TEST_ROOT/manifest-postpublish-edit.log" ||
  fail "setup reported the wrong manifest post-publish failure"
manifest_postpublish_temps="$(find "$MANIFEST_POSTPUBLISH_HOME/.zstack" -maxdepth 1 \( -name '*.pending.*' -o -name '*.next.*' -o -name '*.merged.*' -o -name '*.expected.*' \) -print | wc -l | tr -d ' ')"
[[ "$manifest_postpublish_temps" -eq 0 ]] ||
  fail "setup manifest post-publish drift left transaction files"
[[ -L "$MANIFEST_POSTPUBLISH_HOME/.agents/skills/z-market-validate" ]] ||
  fail "setup unexpectedly removed a valid link after manifest drift"
pass "setup verifies published install manifest bytes before writing root state"

MANIFEST_HARDLINK_FIXTURE="$(copy_fixture manifest-postpublish-hardlink)"
MANIFEST_HARDLINK_HOME="$TEST_ROOT/manifest-hardlink-home"
MANIFEST_HARDLINK_PATH="$MANIFEST_HARDLINK_HOME/.zstack/links"
MANIFEST_HARDLINK_ALIAS="$TEST_ROOT/manifest-hardlink-alias"
mkdir -p "$TEST_ROOT/manifest-hardlink-mv-bin"
# These single-quoted lines are the source of the generated fault-injection shim.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  '"$REAL_MV_BIN" "$@"' \
  'if [[ "${2:-}" == "$MANIFEST_PATH" ]]; then' \
  '  ln "$MANIFEST_PATH" "$MANIFEST_ALIAS"' \
  'fi' > "$TEST_ROOT/manifest-hardlink-mv-bin/mv"
chmod +x "$TEST_ROOT/manifest-hardlink-mv-bin/mv"
if PATH="$TEST_ROOT/manifest-hardlink-mv-bin:$PATH" \
  REAL_MV_BIN="$(command -v mv)" \
  MANIFEST_PATH="$MANIFEST_HARDLINK_PATH" \
  MANIFEST_ALIAS="$MANIFEST_HARDLINK_ALIAS" \
  HOME="$MANIFEST_HARDLINK_HOME" \
  "$MANIFEST_HARDLINK_FIXTURE/scripts/setup.sh" --hosts agents \
  > "$TEST_ROOT/manifest-postpublish-hardlink.log" 2>&1; then
  fail "setup accepted a manifest hardlinked during publication"
fi
[[ "$(zstack_file_link_count "$MANIFEST_HARDLINK_PATH")" == "2" ]] ||
  fail "setup hardlink fixture did not reach post-publication state"
cmp -s "$MANIFEST_HARDLINK_PATH" "$MANIFEST_HARDLINK_ALIAS" ||
  fail "setup changed a post-publish manifest hardlink alias"
[[ ! -e "$MANIFEST_HARDLINK_HOME/.zstack/root" ]] ||
  fail "setup wrote a root record after manifest hardlink drift"
[[ ! -e "$MANIFEST_HARDLINK_HOME/.zstack/operations.lock" ]] ||
  fail "setup manifest hardlink drift left the operation lock"
grep -q 'Install manifest changed during publication' "$TEST_ROOT/manifest-postpublish-hardlink.log" ||
  fail "setup reported the wrong manifest hardlink publication failure"
manifest_hardlink_temps="$(find "$MANIFEST_HARDLINK_HOME/.zstack" -maxdepth 1 \( -name '*.pending.*' -o -name '*.source.*' -o -name '*.next.*' -o -name '*.merged.*' -o -name '*.expected.*' \) -print | wc -l | tr -d ' ')"
[[ "$manifest_hardlink_temps" -eq 0 ]] ||
  fail "setup manifest hardlink drift left transaction files"
pass "setup rejects hardlinks added during manifest publication"

MANIFEST_EXPECTED_HARDLINK_FIXTURE="$(copy_fixture manifest-expected-hardlink)"
MANIFEST_EXPECTED_HARDLINK_HOME="$TEST_ROOT/manifest-expected-hardlink-home"
MANIFEST_EXPECTED_HARDLINK_PATH="$MANIFEST_EXPECTED_HARDLINK_HOME/.zstack/links"
MANIFEST_EXPECTED_HARDLINK_ALIAS="$TEST_ROOT/manifest-expected-hardlink-alias"
mkdir -p "$TEST_ROOT/manifest-expected-hardlink-mv-bin"
# These single-quoted lines are the source of the generated fault-injection shim.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  '"$REAL_MV_BIN" "$@"' \
  'if [[ "${2:-}" == "$MANIFEST_PATH" ]]; then' \
  '  for expected_path in "$STATE_PATH"/links.expected.*; do' \
  '    [[ -f "$expected_path" ]] || continue' \
  '    ln "$expected_path" "$EXPECTED_ALIAS"' \
  '    break' \
  '  done' \
  'fi' > "$TEST_ROOT/manifest-expected-hardlink-mv-bin/mv"
chmod +x "$TEST_ROOT/manifest-expected-hardlink-mv-bin/mv"
if PATH="$TEST_ROOT/manifest-expected-hardlink-mv-bin:$PATH" \
  REAL_MV_BIN="$(command -v mv)" \
  MANIFEST_PATH="$MANIFEST_EXPECTED_HARDLINK_PATH" \
  STATE_PATH="$MANIFEST_EXPECTED_HARDLINK_HOME/.zstack" \
  EXPECTED_ALIAS="$MANIFEST_EXPECTED_HARDLINK_ALIAS" \
  HOME="$MANIFEST_EXPECTED_HARDLINK_HOME" \
  "$MANIFEST_EXPECTED_HARDLINK_FIXTURE/scripts/setup.sh" --hosts agents \
  > "$TEST_ROOT/manifest-expected-hardlink.log" 2>&1; then
  fail "setup accepted an expected manifest snapshot hardlinked during publication"
fi
[[ -f "$MANIFEST_EXPECTED_HARDLINK_PATH" ]] ||
  fail "setup expected-hardlink fixture did not publish the manifest candidate"
[[ ! -e "$MANIFEST_EXPECTED_HARDLINK_HOME/.zstack/root" ]] ||
  fail "setup wrote root state after the expected manifest snapshot lost exclusivity"
[[ -L "$MANIFEST_EXPECTED_HARDLINK_HOME/.agents/skills/z-market-validate" ]] ||
  fail "setup removed valid links after expected manifest snapshot drift"
[[ ! -e "$MANIFEST_EXPECTED_HARDLINK_HOME/.zstack/operations.lock" ]] ||
  fail "setup expected manifest hardlink left the operation lock"
grep -q 'Install manifest changed during publication' \
  "$TEST_ROOT/manifest-expected-hardlink.log" ||
  fail "setup reported the wrong expected manifest hardlink failure"
manifest_expected_hardlink_temp="$(find "$MANIFEST_EXPECTED_HARDLINK_HOME/.zstack" \
  -maxdepth 1 -name 'links.expected.*' -print -quit)"
[[ -n "$manifest_expected_hardlink_temp" ]] ||
  fail "setup removed an expected manifest snapshot with an external hardlink"
[[ "$(zstack_file_link_count "$manifest_expected_hardlink_temp")" == "2" ]] ||
  fail "setup expected manifest hardlink fixture did not preserve the raced inode"
unlink "$MANIFEST_EXPECTED_HARDLINK_ALIAS"
unlink "$manifest_expected_hardlink_temp"
pass "setup binds post-publication proof to an exclusive manifest snapshot"

ROOT_POSTPUBLISH_FIXTURE="$(copy_fixture root-postpublish-edit)"
ROOT_POSTPUBLISH_HOME="$TEST_ROOT/root-postpublish-home"
ROOT_POSTPUBLISH_PATH="$ROOT_POSTPUBLISH_HOME/.zstack/root"
mkdir -p "$TEST_ROOT/root-postpublish-mv-bin"
# These single-quoted lines are the source of the generated fault-injection shim.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  '"$REAL_MV_BIN" "$@"' \
  'if [[ "$2" == "$ROOT_RECORD_PATH" ]]; then' \
  '  printf "%s\n" "external root edit must survive" >> "$ROOT_RECORD_PATH"' \
  'fi' > "$TEST_ROOT/root-postpublish-mv-bin/mv"
chmod +x "$TEST_ROOT/root-postpublish-mv-bin/mv"
if PATH="$TEST_ROOT/root-postpublish-mv-bin:$PATH" \
  REAL_MV_BIN="$(command -v mv)" \
  ROOT_RECORD_PATH="$ROOT_POSTPUBLISH_PATH" \
  HOME="$ROOT_POSTPUBLISH_HOME" \
  "$ROOT_POSTPUBLISH_FIXTURE/scripts/setup.sh" --hosts agents \
  > "$TEST_ROOT/root-postpublish-edit.log" 2>&1; then
  fail "setup accepted a root record edited during publication"
fi
tail -n 1 "$ROOT_POSTPUBLISH_PATH" |
  grep -qx 'external root edit must survive' ||
  fail "setup cleanup discarded a post-publish root record edit"
[[ -f "$ROOT_POSTPUBLISH_HOME/.zstack/links" ]] ||
  fail "setup removed the published manifest after root record drift"
[[ ! -e "$ROOT_POSTPUBLISH_HOME/.zstack/operations.lock" ]] ||
  fail "setup root post-publish drift left the operation lock"
grep -q 'Root record changed during publication' "$TEST_ROOT/root-postpublish-edit.log" ||
  fail "setup reported the wrong root post-publish failure"
root_postpublish_temps="$(find "$ROOT_POSTPUBLISH_HOME/.zstack" -maxdepth 1 \( -name '*.pending.*' -o -name '*.next.*' -o -name '*.merged.*' -o -name '*.expected.*' \) -print | wc -l | tr -d ' ')"
[[ "$root_postpublish_temps" -eq 0 ]] ||
  fail "setup root post-publish drift left transaction files"
[[ -L "$ROOT_POSTPUBLISH_HOME/.agents/skills/z-market-validate" ]] ||
  fail "setup unexpectedly removed a valid link after root record drift"
pass "setup verifies published root record bytes before reporting success"

ROOT_EXPECTED_HARDLINK_FIXTURE="$(copy_fixture root-expected-hardlink)"
ROOT_EXPECTED_HARDLINK_HOME="$TEST_ROOT/root-expected-hardlink-home"
ROOT_EXPECTED_HARDLINK_PATH="$ROOT_EXPECTED_HARDLINK_HOME/.zstack/root"
ROOT_EXPECTED_HARDLINK_ALIAS="$TEST_ROOT/root-expected-hardlink-alias"
mkdir -p "$TEST_ROOT/root-expected-hardlink-mv-bin"
# These single-quoted lines are the source of the generated fault-injection shim.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  '"$REAL_MV_BIN" "$@"' \
  'if [[ "${2:-}" == "$ROOT_RECORD_PATH" ]]; then' \
  '  for expected_path in "$STATE_PATH"/root.expected.*; do' \
  '    [[ -f "$expected_path" ]] || continue' \
  '    ln "$expected_path" "$EXPECTED_ALIAS"' \
  '    break' \
  '  done' \
  'fi' > "$TEST_ROOT/root-expected-hardlink-mv-bin/mv"
chmod +x "$TEST_ROOT/root-expected-hardlink-mv-bin/mv"
if PATH="$TEST_ROOT/root-expected-hardlink-mv-bin:$PATH" \
  REAL_MV_BIN="$(command -v mv)" \
  ROOT_RECORD_PATH="$ROOT_EXPECTED_HARDLINK_PATH" \
  STATE_PATH="$ROOT_EXPECTED_HARDLINK_HOME/.zstack" \
  EXPECTED_ALIAS="$ROOT_EXPECTED_HARDLINK_ALIAS" \
  HOME="$ROOT_EXPECTED_HARDLINK_HOME" \
  "$ROOT_EXPECTED_HARDLINK_FIXTURE/scripts/setup.sh" --hosts agents \
  > "$TEST_ROOT/root-expected-hardlink.log" 2>&1; then
  fail "setup accepted an expected root snapshot hardlinked during publication"
fi
[[ -f "$ROOT_EXPECTED_HARDLINK_HOME/.zstack/links" ]] ||
  fail "setup removed the published manifest after expected root snapshot drift"
[[ -f "$ROOT_EXPECTED_HARDLINK_PATH" ]] ||
  fail "setup expected-hardlink fixture did not publish the root candidate"
[[ -L "$ROOT_EXPECTED_HARDLINK_HOME/.agents/skills/z-market-validate" ]] ||
  fail "setup removed valid links after expected root snapshot drift"
[[ ! -e "$ROOT_EXPECTED_HARDLINK_HOME/.zstack/operations.lock" ]] ||
  fail "setup expected root hardlink left the operation lock"
grep -q 'Root record changed during publication' \
  "$TEST_ROOT/root-expected-hardlink.log" ||
  fail "setup reported the wrong expected root hardlink failure"
root_expected_hardlink_temp="$(find "$ROOT_EXPECTED_HARDLINK_HOME/.zstack" \
  -maxdepth 1 -name 'root.expected.*' -print -quit)"
[[ -n "$root_expected_hardlink_temp" ]] ||
  fail "setup removed an expected root snapshot with an external hardlink"
[[ "$(zstack_file_link_count "$root_expected_hardlink_temp")" == "2" ]] ||
  fail "setup expected root hardlink fixture did not preserve the raced inode"
unlink "$ROOT_EXPECTED_HARDLINK_ALIAS"
unlink "$root_expected_hardlink_temp"
pass "setup binds root publication proof to an exclusive expected snapshot"

CLONE_A_FIXTURE="$(copy_fixture clone-a)"
CLONE_B_FIXTURE="$(copy_fixture clone-b)"
CLONE_HOME="$TEST_ROOT/clone-home"
HOME="$CLONE_HOME" "$CLONE_A_FIXTURE/scripts/setup.sh" --hosts agents >/dev/null
cp "$CLONE_HOME/.zstack/links" "$TEST_ROOT/clone-links.before"
if HOME="$CLONE_HOME" "$CLONE_B_FIXTURE/scripts/setup.sh" --hosts agents > "$TEST_ROOT/clone-conflict.log" 2>&1; then
  fail "a second clone took over links without --force"
fi
cmp -s "$TEST_ROOT/clone-links.before" "$CLONE_HOME/.zstack/links" || fail "failed clone takeover changed manifest ownership"
clone_target="$(cd "$CLONE_HOME/.agents/skills/z-market-validate" && pwd -P)"
[[ "$clone_target" == "$CLONE_A_FIXTURE/skills/z-market-validate" ]] || fail "failed clone takeover changed the original link"

HOME="$CLONE_HOME" "$CLONE_B_FIXTURE/scripts/setup.sh" --hosts agents --force >/dev/null
clone_a_records="$(awk -F'|' -v root="$CLONE_A_FIXTURE" '$1 == root {count++} END {print count + 0}' "$CLONE_HOME/.zstack/links")"
clone_b_records="$(awk -F'|' -v root="$CLONE_B_FIXTURE" '$1 == root {count++} END {print count + 0}' "$CLONE_HOME/.zstack/links")"
[[ "$clone_a_records" -eq 0 && "$clone_b_records" -eq 5 ]] || fail "forced clone takeover did not transfer manifest ownership"
clone_backups="$(find "$CLONE_HOME/.agents/skills" -maxdepth 1 -name '*.zstack-backup-*' | wc -l | tr -d ' ')"
[[ "$clone_backups" -eq 5 ]] || fail "forced clone takeover did not preserve every original link"
clone_target="$(cd "$CLONE_HOME/.agents/skills/z-market-validate" && pwd -P)"
[[ "$clone_target" == "$CLONE_B_FIXTURE/skills/z-market-validate" ]] || fail "forced clone takeover did not install the new owner"

HOME="$CLONE_HOME" "$CLONE_A_FIXTURE/scripts/unlink.sh" >/dev/null
[[ -L "$CLONE_HOME/.agents/skills/z-market-validate" ]] || fail "old clone unlink removed the new clone's link"
HOME="$CLONE_HOME" "$CLONE_B_FIXTURE/scripts/unlink.sh" >/dev/null
[[ ! -e "$CLONE_HOME/.agents/skills/z-market-validate" ]] || fail "new clone unlink left its managed link"
clone_backups="$(find "$CLONE_HOME/.agents/skills" -maxdepth 1 -name '*.zstack-backup-*' | wc -l | tr -d ' ')"
[[ "$clone_backups" -eq 5 ]] || fail "clone unlink removed takeover backups"
pass "forced multi-clone takeover transfers ownership without unsafe unlink"

UNLINK_SOURCE_FIXTURE="$(copy_fixture unlink-source-drift)"
UNLINK_SOURCE_HOME="$TEST_ROOT/unlink-source-home"
UNLINK_SOURCE_PATH="$UNLINK_SOURCE_HOME/.zstack/links"
HOME="$UNLINK_SOURCE_HOME" \
  "$UNLINK_SOURCE_FIXTURE/scripts/setup.sh" --hosts agents >/dev/null
mkdir -p "$TEST_ROOT/unlink-source-cp-bin"
# These single-quoted lines are the source of the generated fault-injection shim.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  '"$REAL_CP_BIN" "$@"' \
  'if [[ "${1:-}" == "$MANIFEST_PATH" ]]; then' \
  '  printf "%s\n" "external source edit must survive" >> "$MANIFEST_PATH"' \
  'fi' > "$TEST_ROOT/unlink-source-cp-bin/cp"
chmod +x "$TEST_ROOT/unlink-source-cp-bin/cp"
if PATH="$TEST_ROOT/unlink-source-cp-bin:$PATH" \
  REAL_CP_BIN="$(command -v cp)" \
  MANIFEST_PATH="$UNLINK_SOURCE_PATH" \
  HOME="$UNLINK_SOURCE_HOME" \
  "$UNLINK_SOURCE_FIXTURE/scripts/unlink.sh" \
  > "$TEST_ROOT/unlink-source-drift.log" 2>&1; then
  fail "unlink accepted an install manifest changed while it was snapshotted"
fi
tail -n 1 "$UNLINK_SOURCE_PATH" |
  grep -qx 'external source edit must survive' ||
  fail "unlink cleanup discarded a source manifest edit"
[[ -L "$UNLINK_SOURCE_HOME/.agents/skills/z-market-validate" ]] ||
  fail "unlink removed a managed link before validating its manifest snapshot"
[[ -f "$UNLINK_SOURCE_HOME/.zstack/root" ]] ||
  fail "unlink removed the root record after source manifest drift"
[[ ! -e "$UNLINK_SOURCE_HOME/.zstack/operations.lock" ]] ||
  fail "unlink source manifest drift left the operation lock"
grep -q 'Install manifest changed while unlink input was snapshotted' "$TEST_ROOT/unlink-source-drift.log" ||
  fail "unlink reported the wrong source manifest drift failure"
unlink_source_temps="$(find "$UNLINK_SOURCE_HOME/.zstack" -maxdepth 1 \( -name '*.pending.*' -o -name '*.source.*' -o -name '*.next.*' -o -name '*.expected.*' \) -print | wc -l | tr -d ' ')"
[[ "$unlink_source_temps" -eq 0 ]] ||
  fail "unlink source manifest drift left transaction files"
pass "unlink validates an exact manifest snapshot before removing links"

UNLINK_SOURCE_HARDLINK_FIXTURE="$(copy_fixture unlink-source-hardlink)"
UNLINK_SOURCE_HARDLINK_HOME="$TEST_ROOT/unlink-source-hardlink-home"
UNLINK_SOURCE_HARDLINK_ALIAS="$TEST_ROOT/unlink-source-hardlink-alias"
HOME="$UNLINK_SOURCE_HARDLINK_HOME" \
  "$UNLINK_SOURCE_HARDLINK_FIXTURE/scripts/setup.sh" --hosts agents >/dev/null
cp "$UNLINK_SOURCE_HARDLINK_HOME/.zstack/links" \
  "$TEST_ROOT/unlink-source-hardlink-links.before"
mkdir -p "$TEST_ROOT/unlink-source-hardlink-cp-bin"
# These single-quoted lines are the source of the generated fault-injection shim.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  '"$REAL_CP_BIN" "$@"' \
  'if [[ "${2:-}" == */links.source.* ]]; then' \
  '  ln "$2" "$SNAPSHOT_ALIAS"' \
  'fi' > "$TEST_ROOT/unlink-source-hardlink-cp-bin/cp"
chmod +x "$TEST_ROOT/unlink-source-hardlink-cp-bin/cp"
if PATH="$TEST_ROOT/unlink-source-hardlink-cp-bin:$PATH" \
  REAL_CP_BIN="$(command -v cp)" \
  SNAPSHOT_ALIAS="$UNLINK_SOURCE_HARDLINK_ALIAS" \
  HOME="$UNLINK_SOURCE_HARDLINK_HOME" \
  "$UNLINK_SOURCE_HARDLINK_FIXTURE/scripts/unlink.sh" \
  > "$TEST_ROOT/unlink-source-hardlink.log" 2>&1; then
  fail "unlink accepted a hardlinked install-manifest source snapshot"
fi
cmp -s "$TEST_ROOT/unlink-source-hardlink-links.before" \
  "$UNLINK_SOURCE_HARDLINK_HOME/.zstack/links" ||
  fail "unlink changed the manifest after rejecting a hardlinked source snapshot"
[[ -L "$UNLINK_SOURCE_HARDLINK_HOME/.agents/skills/z-market-validate" ]] ||
  fail "unlink removed managed links after rejecting a hardlinked source snapshot"
[[ -f "$UNLINK_SOURCE_HARDLINK_HOME/.zstack/root" ]] ||
  fail "unlink removed root state after rejecting a hardlinked source snapshot"
[[ ! -e "$UNLINK_SOURCE_HARDLINK_HOME/.zstack/operations.lock" ]] ||
  fail "unlink hardlinked source snapshot left the operation lock"
grep -q 'Install manifest changed while unlink input was snapshotted' \
  "$TEST_ROOT/unlink-source-hardlink.log" ||
  fail "unlink reported the wrong hardlinked source-snapshot failure"
unlink_source_hardlink_temp="$(find "$UNLINK_SOURCE_HARDLINK_HOME/.zstack" \
  -maxdepth 1 -name 'links.source.*' -print -quit)"
[[ -n "$unlink_source_hardlink_temp" ]] ||
  fail "unlink removed a source snapshot whose inode gained an external hardlink"
[[ "$(zstack_file_link_count "$unlink_source_hardlink_temp")" == "2" ]] ||
  fail "unlink hardlink fixture did not preserve the raced snapshot inode"
unlink "$UNLINK_SOURCE_HARDLINK_ALIAS"
unlink "$unlink_source_hardlink_temp"
pass "unlink rejects hardlinked manifest source snapshots before mutation"

UNLINK_POSTPUBLISH_FIXTURE="$(copy_fixture unlink-postpublish-edit)"
UNLINK_POSTPUBLISH_HOME="$TEST_ROOT/unlink-postpublish-home"
UNLINK_POSTPUBLISH_PATH="$UNLINK_POSTPUBLISH_HOME/.zstack/links"
HOME="$UNLINK_POSTPUBLISH_HOME" \
  "$UNLINK_POSTPUBLISH_FIXTURE/scripts/setup.sh" --hosts agents >/dev/null
printf '%s|%s\n' \
  "$TEST_ROOT/unlink-other-owner" \
  "$TEST_ROOT/unlink-other-link" >> "$UNLINK_POSTPUBLISH_PATH"
mkdir -p "$TEST_ROOT/unlink-postpublish-mv-bin"
# These single-quoted lines are the source of the generated fault-injection shim.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  '"$REAL_MV_BIN" "$@"' \
  'if [[ "${2:-}" == "$MANIFEST_PATH" ]]; then' \
  '  printf "%s\n" "external unlink manifest edit must survive" >> "$MANIFEST_PATH"' \
  'fi' > "$TEST_ROOT/unlink-postpublish-mv-bin/mv"
chmod +x "$TEST_ROOT/unlink-postpublish-mv-bin/mv"
if PATH="$TEST_ROOT/unlink-postpublish-mv-bin:$PATH" \
  REAL_MV_BIN="$(command -v mv)" \
  MANIFEST_PATH="$UNLINK_POSTPUBLISH_PATH" \
  HOME="$UNLINK_POSTPUBLISH_HOME" \
  "$UNLINK_POSTPUBLISH_FIXTURE/scripts/unlink.sh" \
  > "$TEST_ROOT/unlink-postpublish-edit.log" 2>&1; then
  fail "unlink accepted an install manifest edited during publication"
fi
tail -n 1 "$UNLINK_POSTPUBLISH_PATH" |
  grep -qx 'external unlink manifest edit must survive' ||
  fail "unlink cleanup discarded a post-publish manifest edit"
[[ -f "$UNLINK_POSTPUBLISH_HOME/.zstack/root" ]] ||
  fail "unlink removed the root record after manifest publication drift"
[[ ! -e "$UNLINK_POSTPUBLISH_HOME/.zstack/operations.lock" ]] ||
  fail "unlink manifest post-publish drift left the operation lock"
grep -q 'Install manifest changed during unlink publication' "$TEST_ROOT/unlink-postpublish-edit.log" ||
  fail "unlink reported the wrong manifest post-publish failure"
unlink_postpublish_temps="$(find "$UNLINK_POSTPUBLISH_HOME/.zstack" -maxdepth 1 \( -name '*.pending.*' -o -name '*.next.*' -o -name '*.expected.*' \) -print | wc -l | tr -d ' ')"
[[ "$unlink_postpublish_temps" -eq 0 ]] ||
  fail "unlink manifest post-publish drift left transaction files"
pass "unlink verifies published install manifest bytes before reporting success"

UNLINK_EXPECTED_HARDLINK_FIXTURE="$(copy_fixture unlink-expected-hardlink)"
UNLINK_EXPECTED_HARDLINK_HOME="$TEST_ROOT/unlink-expected-hardlink-home"
UNLINK_EXPECTED_HARDLINK_PATH="$UNLINK_EXPECTED_HARDLINK_HOME/.zstack/links"
UNLINK_EXPECTED_HARDLINK_ALIAS="$TEST_ROOT/unlink-expected-hardlink-alias"
HOME="$UNLINK_EXPECTED_HARDLINK_HOME" \
  "$UNLINK_EXPECTED_HARDLINK_FIXTURE/scripts/setup.sh" --hosts agents >/dev/null
printf '%s|%s\n' \
  "$TEST_ROOT/unlink-expected-other-owner" \
  "$TEST_ROOT/unlink-expected-other-link" >> "$UNLINK_EXPECTED_HARDLINK_PATH"
printf '%s|%s\n' \
  "$TEST_ROOT/unlink-expected-other-owner" \
  "$TEST_ROOT/unlink-expected-other-link" \
  > "$TEST_ROOT/unlink-expected-hardlink-published"
mkdir -p "$TEST_ROOT/unlink-expected-hardlink-mv-bin"
# These single-quoted lines are the source of the generated fault-injection shim.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  '"$REAL_MV_BIN" "$@"' \
  'if [[ "${2:-}" == "$MANIFEST_PATH" ]]; then' \
  '  for expected_path in "$STATE_PATH"/links.expected.*; do' \
  '    [[ -f "$expected_path" ]] || continue' \
  '    ln "$expected_path" "$EXPECTED_ALIAS"' \
  '    break' \
  '  done' \
  'fi' > "$TEST_ROOT/unlink-expected-hardlink-mv-bin/mv"
chmod +x "$TEST_ROOT/unlink-expected-hardlink-mv-bin/mv"
if PATH="$TEST_ROOT/unlink-expected-hardlink-mv-bin:$PATH" \
  REAL_MV_BIN="$(command -v mv)" \
  MANIFEST_PATH="$UNLINK_EXPECTED_HARDLINK_PATH" \
  STATE_PATH="$UNLINK_EXPECTED_HARDLINK_HOME/.zstack" \
  EXPECTED_ALIAS="$UNLINK_EXPECTED_HARDLINK_ALIAS" \
  HOME="$UNLINK_EXPECTED_HARDLINK_HOME" \
  "$UNLINK_EXPECTED_HARDLINK_FIXTURE/scripts/unlink.sh" \
  > "$TEST_ROOT/unlink-expected-hardlink.log" 2>&1; then
  fail "unlink accepted an expected manifest snapshot hardlinked during publication"
fi
cmp -s "$TEST_ROOT/unlink-expected-hardlink-published" \
  "$UNLINK_EXPECTED_HARDLINK_PATH" ||
  fail "unlink expected-hardlink fixture did not reach post-publication proof"
[[ -f "$UNLINK_EXPECTED_HARDLINK_HOME/.zstack/root" ]] ||
  fail "unlink removed root state after expected manifest snapshot drift"
[[ ! -e "$UNLINK_EXPECTED_HARDLINK_HOME/.zstack/operations.lock" ]] ||
  fail "unlink expected manifest hardlink left the operation lock"
grep -q 'Install manifest changed during unlink publication' \
  "$TEST_ROOT/unlink-expected-hardlink.log" ||
  fail "unlink reported the wrong expected manifest hardlink failure"
unlink_expected_hardlink_temp="$(find "$UNLINK_EXPECTED_HARDLINK_HOME/.zstack" \
  -maxdepth 1 -name 'links.expected.*' -print -quit)"
[[ -n "$unlink_expected_hardlink_temp" ]] ||
  fail "unlink removed an expected manifest snapshot with an external hardlink"
[[ "$(zstack_file_link_count "$unlink_expected_hardlink_temp")" == "2" ]] ||
  fail "unlink expected manifest hardlink fixture did not preserve the raced inode"
unlink "$UNLINK_EXPECTED_HARDLINK_ALIAS"
unlink "$unlink_expected_hardlink_temp"
pass "unlink binds post-publication proof to an exclusive manifest snapshot"

EMPTY_MANIFEST_RACE_FIXTURE="$(copy_fixture empty-manifest-race)"
EMPTY_MANIFEST_RACE_HOME="$TEST_ROOT/empty-manifest-race-home"
EMPTY_MANIFEST_RACE_PATH="$EMPTY_MANIFEST_RACE_HOME/.zstack/links"
HOME="$EMPTY_MANIFEST_RACE_HOME" \
  "$EMPTY_MANIFEST_RACE_FIXTURE/scripts/setup.sh" --hosts agents >/dev/null
mkdir -p "$TEST_ROOT/empty-manifest-race-mv-bin"
# These single-quoted lines are the source of the generated fault-injection shim.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'if [[ "${1:-}" == "$MANIFEST_PATH" ]]; then' \
  '  unlink "$MANIFEST_PATH"' \
  '  printf "%s\n" "external empty-manifest replacement must survive" > "$MANIFEST_PATH"' \
  'fi' \
  'exec "$REAL_MV_BIN" "$@"' > "$TEST_ROOT/empty-manifest-race-mv-bin/mv"
chmod +x "$TEST_ROOT/empty-manifest-race-mv-bin/mv"
if PATH="$TEST_ROOT/empty-manifest-race-mv-bin:$PATH" \
  REAL_MV_BIN="$(command -v mv)" \
  MANIFEST_PATH="$EMPTY_MANIFEST_RACE_PATH" \
  HOME="$EMPTY_MANIFEST_RACE_HOME" \
  "$EMPTY_MANIFEST_RACE_FIXTURE/scripts/unlink.sh" \
  > "$TEST_ROOT/empty-manifest-race.log" 2>&1; then
  fail "unlink accepted a manifest replaced during empty-state removal"
fi
grep -qx 'external empty-manifest replacement must survive' "$EMPTY_MANIFEST_RACE_PATH" ||
  fail "unlink removed or displaced a raced empty-manifest replacement"
empty_manifest_quarantines="$(find "$EMPTY_MANIFEST_RACE_HOME/.zstack" -maxdepth 1 -name 'links.zstack-remove.*' -print | wc -l | tr -d ' ')"
[[ "$empty_manifest_quarantines" -eq 0 ]] ||
  fail "unlink left a restored manifest quarantine directory"
[[ -f "$EMPTY_MANIFEST_RACE_HOME/.zstack/root" ]] ||
  fail "unlink removed the root record after manifest removal drift"
[[ ! -e "$EMPTY_MANIFEST_RACE_HOME/.zstack/operations.lock" ]] ||
  fail "unlink empty-manifest replacement race left the operation lock"
grep -q 'Install manifest changed before safe empty unlink publication' "$TEST_ROOT/empty-manifest-race.log" ||
  fail "unlink reported the wrong empty-manifest replacement failure"
empty_manifest_temps="$(find "$EMPTY_MANIFEST_RACE_HOME/.zstack" -maxdepth 1 \( -name '*.pending.*' -o -name '*.source.*' -o -name '*.next.*' -o -name '*.expected.*' \) -print | wc -l | tr -d ' ')"
[[ "$empty_manifest_temps" -eq 0 ]] ||
  fail "unlink empty-manifest replacement race left transaction files"
pass "unlink preserves manifests replaced during empty-state publication"

ROOT_REMOVE_RACE_FIXTURE="$(copy_fixture root-remove-race)"
ROOT_REMOVE_RACE_HOME="$TEST_ROOT/root-remove-race-home"
ROOT_REMOVE_RACE_PATH="$ROOT_REMOVE_RACE_HOME/.zstack/root"
HOME="$ROOT_REMOVE_RACE_HOME" \
  "$ROOT_REMOVE_RACE_FIXTURE/scripts/setup.sh" --hosts agents >/dev/null
mkdir -p "$TEST_ROOT/root-remove-race-mv-bin"
# These single-quoted lines are the source of the generated fault-injection shim.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'if [[ "${1:-}" == "$ROOT_RECORD_PATH" ]]; then' \
  '  unlink "$ROOT_RECORD_PATH"' \
  '  printf "%s\n" "external root replacement must survive" > "$ROOT_RECORD_PATH"' \
  'fi' \
  'exec "$REAL_MV_BIN" "$@"' > "$TEST_ROOT/root-remove-race-mv-bin/mv"
chmod +x "$TEST_ROOT/root-remove-race-mv-bin/mv"
if PATH="$TEST_ROOT/root-remove-race-mv-bin:$PATH" \
  REAL_MV_BIN="$(command -v mv)" \
  ROOT_RECORD_PATH="$ROOT_REMOVE_RACE_PATH" \
  HOME="$ROOT_REMOVE_RACE_HOME" \
  "$ROOT_REMOVE_RACE_FIXTURE/scripts/unlink.sh" \
  > "$TEST_ROOT/root-remove-race.log" 2>&1; then
  fail "unlink accepted a root record replaced during safe removal"
fi
grep -qx 'external root replacement must survive' "$ROOT_REMOVE_RACE_PATH" ||
  fail "unlink removed or displaced a raced root record replacement"
root_remove_quarantines="$(find "$ROOT_REMOVE_RACE_HOME/.zstack" -maxdepth 1 -name 'root.zstack-remove.*' -print | wc -l | tr -d ' ')"
[[ "$root_remove_quarantines" -eq 0 ]] ||
  fail "unlink left a restored root-record quarantine directory"
[[ ! -e "$ROOT_REMOVE_RACE_HOME/.zstack/operations.lock" ]] ||
  fail "unlink root-record replacement race left the operation lock"
grep -q 'Root record changed before safe unlink cleanup' "$TEST_ROOT/root-remove-race.log" ||
  fail "unlink reported the wrong root-record replacement failure"
root_remove_temps="$(find "$ROOT_REMOVE_RACE_HOME/.zstack" -maxdepth 1 \( -name '*.pending.*' -o -name '*.source.*' -o -name '*.next.*' -o -name '*.expected.*' \) -print | wc -l | tr -d ' ')"
[[ "$root_remove_temps" -eq 0 ]] ||
  fail "unlink root-record replacement race left transaction files"
pass "unlink preserves root records replaced during identity-safe removal"

RECONCILE_FIXTURE="$(copy_fixture reconcile)"
RECONCILE_HOME="$TEST_ROOT/reconcile-home"
HOME="$RECONCILE_HOME" "$RECONCILE_FIXTURE/scripts/setup.sh" --hosts agents,codex >/dev/null
ln -s "$RECONCILE_FIXTURE/skills/z-seo-plan" "$RECONCILE_HOME/.agents/skills/z-seo-plan.zstack-backup-manual"
awk '
  /^  - id:/ { in_write_prd = ($0 == "  - id: z-write-prd") }
  in_write_prd && /^      - agents$/ { next }
  /^  - id: z-seo-plan$/ { in_seo = 1 }
  in_seo && /^    status: active$/ { $0 = "    status: draft"; in_seo = 0 }
  { print }
' "$RECONCILE_FIXTURE/catalog.yaml" > "$RECONCILE_FIXTURE/catalog.yaml.next"
mv "$RECONCILE_FIXTURE/catalog.yaml.next" "$RECONCILE_FIXTURE/catalog.yaml"
route_fixture_skill_to_none "$RECONCILE_FIXTURE" z-seo-plan

HOME="$RECONCILE_HOME" "$RECONCILE_FIXTURE/scripts/setup.sh" --hosts agents >/dev/null
[[ ! -e "$RECONCILE_HOME/.agents/skills/z-seo-plan" ]] || fail "setup left a draft skill in the selected host"
[[ ! -e "$RECONCILE_HOME/.agents/skills/z-write-prd" ]] || fail "setup ignored a removed host allowlist entry"
[[ -L "$RECONCILE_HOME/.agents/skills/z-seo-plan.zstack-backup-manual" ]] || fail "setup removed a conflict backup during reconciliation"
[[ -L "$RECONCILE_HOME/.codex/skills/z-seo-plan" ]] || fail "setup changed an unselected host"

HOME="$RECONCILE_HOME" "$RECONCILE_FIXTURE/scripts/setup.sh" --hosts codex >/dev/null
[[ ! -e "$RECONCILE_HOME/.codex/skills/z-seo-plan" ]] || fail "setup did not reconcile a draft skill when its host was selected"
[[ -L "$RECONCILE_HOME/.codex/skills/z-write-prd" ]] || fail "setup removed a still-allowed skill"
if grep -qF "$RECONCILE_HOME/.agents/skills/z-seo-plan" "$RECONCILE_HOME/.zstack/links" ||
   grep -qF "$RECONCILE_HOME/.agents/skills/z-write-prd" "$RECONCILE_HOME/.zstack/links" ||
   grep -qF "$RECONCILE_HOME/.codex/skills/z-seo-plan" "$RECONCILE_HOME/.zstack/links"; then
  fail "setup retained stale manifest entries after reconciliation"
fi
pass "setup reconciles catalog status and host allowlists within selected hosts"

PROJECT_FIXTURE="$TEST_ROOT/project-install"
mkdir -p "$PROJECT_FIXTURE"
(cd "$PROJECT_FIXTURE" && HOME="$TEST_HOME" "$INSTALL_FIXTURE/scripts/setup.sh" --project --hosts agents >/dev/null)
[[ -L "$PROJECT_FIXTURE/.agents/skills/z-market-validate" ]] || fail "project install did not create an Agent Skill link"

printf '%s\n' "$$" > "$TEST_HOME/.zstack/operations.lock"
if HOME="$TEST_HOME" "$INSTALL_FIXTURE/scripts/unlink.sh" > "$TEST_ROOT/unlink-lock.log" 2>&1; then
  fail "unlink ignored an active shared operation lock"
fi
[[ -L "$TEST_HOME/.agents/skills/z-market-validate" ]] || fail "locked unlink removed a managed link"
rm -f "$TEST_HOME/.zstack/operations.lock"

HOME="$TEST_HOME" "$INSTALL_FIXTURE/scripts/unlink.sh" >/dev/null
[[ ! -e "$TEST_HOME/.agents/skills/z-market-validate" ]] || fail "unlink left a zstack-managed link"
[[ ! -e "$PROJECT_FIXTURE/.agents/skills/z-market-validate" ]] || fail "unlink left a manifest-tracked project link"
backup_count="$(find "$TEST_HOME/.agents/skills" -maxdepth 1 -name 'z-market-validate.zstack-backup-*' | wc -l | tr -d ' ')"
[[ "$backup_count" -eq 1 ]] || fail "unlink removed a conflict backup"
[[ ! -e "$TEST_HOME/.zstack/root" ]] || fail "unlink left this repo's root record"
[[ ! -e "$TEST_HOME/.zstack/links" ]] || fail "unlink left this repo's manifest entries"
pass "unlink shares the mutation lock and removes only managed global/project links"

VALIDATION_FIXTURE="$(copy_fixture validation)"
awk '
  /^description:/ && !inserted { print "license: MIT"; inserted = 1 }
  { print }
' "$VALIDATION_FIXTURE/skills/z-write-prd/SKILL.md" > "$VALIDATION_FIXTURE/skills/z-write-prd/SKILL.md.next"
mv "$VALIDATION_FIXTURE/skills/z-write-prd/SKILL.md.next" "$VALIDATION_FIXTURE/skills/z-write-prd/SKILL.md"
awk '
  /^    category: product$/ { $0 = "    category: Product Strategy" }
  { print }
' "$VALIDATION_FIXTURE/catalog.yaml" > "$VALIDATION_FIXTURE/catalog.yaml.next"
mv "$VALIDATION_FIXTURE/catalog.yaml.next" "$VALIDATION_FIXTURE/catalog.yaml"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only > "$TEST_ROOT/doctor-aggregate.log" 2>&1; then
  fail "doctor accepted unsupported frontmatter"
fi
grep -q "category must be non-empty kebab-case" "$TEST_ROOT/doctor-aggregate.log" || fail "doctor default mode omitted a catalog failure"
grep -q "unsupported frontmatter key 'license'" "$TEST_ROOT/doctor-aggregate.log" || fail "doctor default mode stopped before a later skill failure"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/doctor-fail-fast.log" 2>&1; then
  fail "doctor fail-fast mode accepted invalid catalog metadata"
fi
grep -q "category must be non-empty kebab-case" "$TEST_ROOT/doctor-fail-fast.log" || fail "doctor fail-fast mode reported the wrong first failure"
if grep -q "unsupported frontmatter key 'license'" "$TEST_ROOT/doctor-fail-fast.log"; then
  fail "doctor fail-fast mode continued after its first validation error"
fi
cp "$ROOT/catalog.yaml" "$VALIDATION_FIXTURE/catalog.yaml"
pass "doctor aggregates errors by default and fail-fast stops after the first error"

cp "$ROOT/skills/z-write-prd/SKILL.md" "$VALIDATION_FIXTURE/skills/z-write-prd/SKILL.md"
awk '
  /^description:/ { print "description: Short."; replacing = 1; next }
  replacing && /^---$/ { replacing = 0; print; next }
  replacing { next }
  { print }
' "$VALIDATION_FIXTURE/skills/z-write-prd/SKILL.md" > "$VALIDATION_FIXTURE/skills/z-write-prd/SKILL.md.next"
mv "$VALIDATION_FIXTURE/skills/z-write-prd/SKILL.md.next" "$VALIDATION_FIXTURE/skills/z-write-prd/SKILL.md"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/short-description.log" 2>&1; then
  fail "doctor accepted a description without enough what-and-when guidance"
fi
grep -q "description must explain what the skill does and when to use it" "$TEST_ROOT/short-description.log" || fail "doctor reported the wrong short-description failure"
pass "doctor requires useful what-and-when descriptions"

cp "$ROOT/skills/z-write-prd/SKILL.md" "$VALIDATION_FIXTURE/skills/z-write-prd/SKILL.md"
awk '
  /^---$/ {
    separator_count++
    if (separator_count == 2) print "  Explicitly invoke /z-write-prd."
  }
  { print }
' "$VALIDATION_FIXTURE/skills/z-write-prd/SKILL.md" > "$VALIDATION_FIXTURE/skills/z-write-prd/SKILL.md.next"
mv "$VALIDATION_FIXTURE/skills/z-write-prd/SKILL.md.next" "$VALIDATION_FIXTURE/skills/z-write-prd/SKILL.md"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/invocation-prefix.log" 2>&1; then
  fail "doctor accepted host-specific invocation syntax in a description"
fi
grep -qF "description must not include host-specific /z-* or \$z-* invocation syntax" "$TEST_ROOT/invocation-prefix.log" || fail "doctor reported the wrong invocation-prefix failure"
pass "doctor keeps invocation prefixes out of portable descriptions"

cp "$ROOT/skills/z-write-prd/SKILL.md" "$VALIDATION_FIXTURE/skills/z-write-prd/SKILL.md"
printf '\n## When to use\n\n- When a user asks for a PRD.\n' >> "$VALIDATION_FIXTURE/skills/z-write-prd/SKILL.md"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/body-trigger.log" 2>&1; then
  fail "doctor accepted trigger guidance duplicated in the skill body"
fi
grep -q "put trigger guidance in frontmatter description" "$TEST_ROOT/body-trigger.log" || fail "doctor reported the wrong body-trigger failure"
pass "doctor keeps trigger guidance in frontmatter"

cp "$ROOT/skills/z-write-prd/SKILL.md" "$VALIDATION_FIXTURE/skills/z-write-prd/SKILL.md"
printf '%s\n' "# Unlinked reference" > "$VALIDATION_FIXTURE/skills/z-write-prd/references/orphan.md"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/reference.log" 2>&1; then
  fail "doctor accepted an undiscoverable reference"
fi
grep -q "reference is not discoverable" "$TEST_ROOT/reference.log" || fail "doctor reported the wrong reference failure"
pass "doctor rejects undiscoverable references"

cp "$ROOT/skills/z-write-prd/SKILL.md" "$VALIDATION_FIXTURE/skills/z-write-prd/SKILL.md"
rm -f "$VALIDATION_FIXTURE/skills/z-write-prd/references/orphan.md"
long_reference="$VALIDATION_FIXTURE/skills/z-write-prd/references/long-reference.md"
printf '%s\n\n' '# Long reference without navigation' > "$long_reference"
line_number=1
while [[ "$line_number" -le 101 ]]; do
  printf 'Detail line %s\n' "$line_number" >> "$long_reference"
  line_number=$((line_number + 1))
done
printf '\nRead references/long-reference.md when testing long references.\n' >> "$VALIDATION_FIXTURE/skills/z-write-prd/SKILL.md"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/reference-contents.log" 2>&1; then
  fail "doctor accepted a long reference without contents navigation"
fi
grep -q "long reference needs a Contents section" "$TEST_ROOT/reference-contents.log" || fail "doctor reported the wrong long-reference failure"
pass "doctor requires navigation in long references"

cp "$ROOT/skills/z-write-prd/SKILL.md" "$VALIDATION_FIXTURE/skills/z-write-prd/SKILL.md"
rm -f "$long_reference"

SKILL_LIMIT_ROOT="$VALIDATION_FIXTURE/skills/z-write-prd"
ln -s "$ROOT/README.md" "$SKILL_LIMIT_ROOT/references/local-link.md"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/skill-symlink.log" 2>&1; then
  fail "doctor accepted a symbolic link inside a skill package"
fi
grep -q "skill tree contains a symbolic link" "$TEST_ROOT/skill-symlink.log" ||
  fail "doctor reported the wrong skill symlink failure"
rm -f "$SKILL_LIMIT_ROOT/references/local-link.md"

dd if=/dev/zero of="$SKILL_LIMIT_ROOT/oversized.bin" bs=$((2 * 1024 * 1024 + 1)) count=1 2>/dev/null
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/skill-file-limit.log" 2>&1; then
  fail "doctor accepted an oversized skill file"
fi
grep -q "skill tree file exceeds 2097152 bytes" "$TEST_ROOT/skill-file-limit.log" ||
  fail "doctor reported the wrong skill file-size failure"
rm -f "$SKILL_LIMIT_ROOT/oversized.bin"

SKILL_COUNT_OVERFLOW="$SKILL_LIMIT_ROOT/generated-count"
mkdir -p "$SKILL_COUNT_OVERFLOW"
for ((skill_index = 1; skill_index <= 101; skill_index++)); do
  : > "$SKILL_COUNT_OVERFLOW/file-$skill_index.txt"
done
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/skill-count-limit.log" 2>&1; then
  fail "doctor accepted too many files inside a skill package"
fi
grep -Eq "skill package has [0-9]+ files; maximum is 100" "$TEST_ROOT/skill-count-limit.log" ||
  fail "doctor reported the wrong skill file-count failure"
rm -rf "$SKILL_COUNT_OVERFLOW"

SKILL_TOTAL_OVERFLOW="$SKILL_LIMIT_ROOT/generated-total"
mkdir -p "$SKILL_TOTAL_OVERFLOW"
for skill_index in 1 2 3; do
  dd if=/dev/zero \
    of="$SKILL_TOTAL_OVERFLOW/file-$skill_index.bin" \
    bs=$((2 * 1024 * 1024)) count=1 2>/dev/null
done
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/skill-total-limit.log" 2>&1; then
  fail "doctor accepted an oversized skill package"
fi
grep -Eq "skill package is [0-9]+ bytes; maximum is 5242880" "$TEST_ROOT/skill-total-limit.log" ||
  fail "doctor reported the wrong skill total-size failure"
rm -rf "$SKILL_TOTAL_OVERFLOW"
pass "doctor rejects non-reproducible or oversized skill packages"

rm -f "$VALIDATION_FIXTURE/skills/z-write-prd/references/quality-bar.md"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/quality-bar.log" 2>&1; then
  fail "doctor accepted an active skill without a quality bar"
fi
grep -q "active skill requires references/quality-bar.md" "$TEST_ROOT/quality-bar.log" || fail "doctor reported the wrong quality-bar failure"
cp "$ROOT/skills/z-write-prd/references/quality-bar.md" "$VALIDATION_FIXTURE/skills/z-write-prd/references/quality-bar.md"
pass "doctor requires a linked quality bar for every active skill"

sed 's/^## 11\. Evidence handoff$/## 11. Downstream notes/' \
  "$ROOT/skills/z-write-prd/references/prd-template.md" > "$VALIDATION_FIXTURE/skills/z-write-prd/references/prd-template.md"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/evidence-handoff.log" 2>&1; then
  fail "doctor accepted an active skill without an evidence handoff output"
fi
grep -q "primary output template must include an Evidence handoff section" "$TEST_ROOT/evidence-handoff.log" || fail "doctor reported the wrong evidence-handoff failure"
cp "$ROOT/skills/z-write-prd/references/prd-template.md" "$VALIDATION_FIXTURE/skills/z-write-prd/references/prd-template.md"
pass "doctor requires evidence handoff output for every active skill"

sed 's/| Next validation |/| Follow-up |/' \
  "$ROOT/skills/z-write-prd/references/prd-template.md" > "$VALIDATION_FIXTURE/skills/z-write-prd/references/prd-template.md"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/evidence-handoff-fields.log" 2>&1; then
  fail "doctor accepted an evidence handoff with a missing required field"
fi
grep -q "Evidence handoff is missing required fields: Next validation" "$TEST_ROOT/evidence-handoff-fields.log" || fail "doctor reported the wrong missing evidence-handoff field"
cp "$ROOT/skills/z-write-prd/references/prd-template.md" "$VALIDATION_FIXTURE/skills/z-write-prd/references/prd-template.md"
pass "doctor requires all seven evidence handoff fields"

sed -e 's/| Field | Value |/| Field | Value | Detail |/g' \
  -e 's/|-------|-------|/|-------|-------|--------|/g' \
  "$ROOT/skills/z-write-prd/references/prd-template.md" > "$VALIDATION_FIXTURE/skills/z-write-prd/references/prd-template.md"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/evidence-handoff-shape.log" 2>&1; then
  fail "doctor accepted a three-column Evidence handoff template"
fi
grep -q "Evidence handoff template must contain exactly one valid two-column Field | Value table" "$TEST_ROOT/evidence-handoff-shape.log" || fail "doctor reported the wrong Evidence handoff shape failure"
cp "$ROOT/skills/z-write-prd/references/prd-template.md" "$VALIDATION_FIXTURE/skills/z-write-prd/references/prd-template.md"
pass "doctor validates the Evidence handoff table shape"

sed 's/search signal/interest score/' \
  "$ROOT/skills/z-write-prd/references/prd-template.md" > "$VALIDATION_FIXTURE/skills/z-write-prd/references/prd-template.md"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/evidence-handoff-classes.log" 2>&1; then
  fail "doctor accepted an evidence handoff with a non-contract evidence class"
fi
grep -q "Evidence handoff is missing evidence classes: search signal" "$TEST_ROOT/evidence-handoff-classes.log" || fail "doctor reported the wrong missing evidence class"
cp "$ROOT/skills/z-write-prd/references/prd-template.md" "$VALIDATION_FIXTURE/skills/z-write-prd/references/prd-template.md"
pass "doctor requires the five evidence classes"

sed 's/Evidence does not upgrade on handoff/Evidence is summarized on handoff/' \
  "$ROOT/skills/z-write-prd/SKILL.md" > "$VALIDATION_FIXTURE/skills/z-write-prd/SKILL.md"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/evidence-class.log" 2>&1; then
  fail "doctor accepted a skill that could upgrade evidence across handoffs"
fi
grep -q "SKILL.md must preserve evidence class across handoffs" "$TEST_ROOT/evidence-class.log" || fail "doctor reported the wrong evidence-class failure"
cp "$ROOT/skills/z-write-prd/SKILL.md" "$VALIDATION_FIXTURE/skills/z-write-prd/SKILL.md"
pass "doctor requires evidence-class preservation in active skills"

sed 's/The handoff is a fixed interface\./The handoff may be rewritten./' \
  "$ROOT/skills/z-write-prd/SKILL.md" > "$VALIDATION_FIXTURE/skills/z-write-prd/SKILL.md"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/evidence-interface.log" 2>&1; then
  fail "doctor accepted a skill without a fixed evidence-handoff interface"
fi
grep -q "SKILL.md must define Evidence handoff as a fixed interface" "$TEST_ROOT/evidence-interface.log" || fail "doctor reported the wrong fixed evidence-handoff failure"
cp "$ROOT/skills/z-write-prd/SKILL.md" "$VALIDATION_FIXTURE/skills/z-write-prd/SKILL.md"
pass "doctor requires a fixed evidence-handoff interface in active skills"

sed 's/two-column/multi-column/' \
  "$ROOT/skills/z-write-prd/SKILL.md" > "$VALIDATION_FIXTURE/skills/z-write-prd/SKILL.md"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/evidence-columns.log" 2>&1; then
  fail "doctor accepted a skill without the two-column Evidence handoff contract"
fi
grep -q "SKILL.md must require one two-column Field | Value Evidence handoff" "$TEST_ROOT/evidence-columns.log" || fail "doctor reported the wrong Evidence handoff column failure"
cp "$ROOT/skills/z-write-prd/SKILL.md" "$VALIDATION_FIXTURE/skills/z-write-prd/SKILL.md"
pass "doctor requires the two-column Evidence handoff contract in active skills"

sed 's/Never leave the class cell empty\./The class cell may be empty./' \
  "$ROOT/skills/z-write-prd/SKILL.md" > "$VALIDATION_FIXTURE/skills/z-write-prd/SKILL.md"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/evidence-classes-empty.log" 2>&1; then
  fail "doctor accepted a skill that permits an empty Evidence classes cell"
fi
grep -q "SKILL.md must require a non-empty Evidence classes cell" "$TEST_ROOT/evidence-classes-empty.log" || fail "doctor reported the wrong empty Evidence classes failure"
cp "$ROOT/skills/z-write-prd/SKILL.md" "$VALIDATION_FIXTURE/skills/z-write-prd/SKILL.md"
pass "doctor requires a non-empty Evidence classes cell in active skills"

# Backticks are literal Markdown delimiters in the generated fault fixture.
# shellcheck disable=SC2016
sed 's/`Next validation`/`Next experiment`/' \
  "$ROOT/skills/z-write-prd/SKILL.md" > "$VALIDATION_FIXTURE/skills/z-write-prd/SKILL.md"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/evidence-runtime-fields.log" 2>&1; then
  fail "doctor accepted a fixed interface with a missing runtime field label"
fi
grep -q "SKILL.md fixed interface is missing runtime field labels: Next validation" "$TEST_ROOT/evidence-runtime-fields.log" || fail "doctor reported the wrong missing runtime field label"
cp "$ROOT/skills/z-write-prd/SKILL.md" "$VALIDATION_FIXTURE/skills/z-write-prd/SKILL.md"
pass "doctor requires all seven runtime field labels in active skills"

awk '
  /^    category: product$/ { $0 = "    category: Product Strategy" }
  { print }
' "$VALIDATION_FIXTURE/catalog.yaml" > "$VALIDATION_FIXTURE/catalog.yaml.next"
mv "$VALIDATION_FIXTURE/catalog.yaml.next" "$VALIDATION_FIXTURE/catalog.yaml"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/catalog.log" 2>&1; then
  fail "doctor accepted invalid catalog metadata"
fi
grep -q "category must be non-empty kebab-case" "$TEST_ROOT/catalog.log" || fail "doctor reported the wrong catalog failure"
pass "doctor rejects invalid catalog metadata"

cp "$ROOT/catalog.yaml" "$VALIDATION_FIXTURE/catalog.yaml"
awk '
  /^  - id: z-write-prd$/ { target = 1 }
  target && /^    status: active$/ { print; print; target = 0; next }
  { print }
' "$VALIDATION_FIXTURE/catalog.yaml" > "$VALIDATION_FIXTURE/catalog.yaml.next"
mv "$VALIDATION_FIXTURE/catalog.yaml.next" "$VALIDATION_FIXTURE/catalog.yaml"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/duplicate-yaml.log" 2>&1; then
  fail "doctor accepted a duplicate YAML key"
fi
grep -q 'duplicate key "status"' "$TEST_ROOT/duplicate-yaml.log" || fail "doctor reported the wrong duplicate YAML failure"
pass "doctor rejects duplicate YAML keys"

cp "$ROOT/catalog.yaml" "$VALIDATION_FIXTURE/catalog.yaml"
sed 's/^link_mode: symlink$/link_mode: copy/' "$ROOT/hosts/codex.yaml" > "$VALIDATION_FIXTURE/hosts/codex.yaml"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/host.log" 2>&1; then
  fail "doctor accepted an unsupported host profile"
fi
grep -q "unsupported link_mode 'copy'" "$TEST_ROOT/host.log" || fail "doctor reported the wrong host failure"
pass "doctor rejects unsupported host profiles"

cp "$ROOT/.github/workflows/validate.yml" "$VALIDATION_FIXTURE/.github/workflows/validate.yml"
sed 's#uses: actions/checkout@[0-9a-f]\{40\}#uses: actions/checkout@v7#' \
  "$VALIDATION_FIXTURE/.github/workflows/validate.yml" > "$VALIDATION_FIXTURE/.github/workflows/validate.next.yml"
mv "$VALIDATION_FIXTURE/.github/workflows/validate.next.yml" "$VALIDATION_FIXTURE/.github/workflows/validate.yml"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/action-pin.log" 2>&1; then
  fail "doctor accepted a floating GitHub Action reference"
fi
grep -q "workflow action must use a full immutable commit SHA" "$TEST_ROOT/action-pin.log" || fail "doctor reported the wrong action-pin failure"
pass "doctor requires immutable GitHub Action references"
cp "$ROOT/.github/workflows/validate.yml" "$VALIDATION_FIXTURE/.github/workflows/validate.yml"

if (
  ZSTACK_REAL_AWK="$(command -v awk)"
  export ZSTACK_REAL_AWK
  # Invoked indirectly by the child Bash after export.
  # shellcheck disable=SC2329
  awk() {
    local argument
    for argument in "$@"; do
      case "$argument" in
        */zstack-doctor-workflow.*|*/z-market-validate/SKILL.md) return 74 ;;
      esac
    done
    "$ZSTACK_REAL_AWK" "$@"
  }
  export -f awk
  "$ROOT/scripts/doctor.sh" --source-only > "$TEST_ROOT/doctor-parser-failure.log" 2>&1
); then
  fail "doctor accepted failed workflow and SKILL.md parsers"
fi
grep -q "workflow inspection failed for .github/workflows/validate.yml" "$TEST_ROOT/doctor-parser-failure.log" ||
  fail "doctor did not propagate the workflow parser failure"
grep -q "z-market-validate: SKILL.md inspection failed" "$TEST_ROOT/doctor-parser-failure.log" ||
  fail "doctor did not propagate the SKILL.md parser failure"
pass "doctor fails closed when workflow or skill inspection fails"

cp "$ROOT/catalog.yaml" "$VALIDATION_FIXTURE/catalog.yaml"
cp "$ROOT/evals/cases.yaml" "$VALIDATION_FIXTURE/evals/cases.yaml"
cp "$ROOT/evals/routing.yaml" "$VALIDATION_FIXTURE/evals/routing.yaml"
for duplicate_manifest in catalog.yaml evals/cases.yaml evals/routing.yaml; do
  awk '
    /^  - id:/ {
      count++
      if (count == 1) first_id = $0
      if (count == 2) $0 = first_id
    }
    { print }
  ' "$VALIDATION_FIXTURE/$duplicate_manifest" > "$VALIDATION_FIXTURE/$duplicate_manifest.next"
  mv "$VALIDATION_FIXTURE/$duplicate_manifest.next" "$VALIDATION_FIXTURE/$duplicate_manifest"
done
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only > "$TEST_ROOT/duplicate-identifiers.log" 2>&1; then
  fail "doctor accepted duplicate catalog, behavioral, and routing identifiers"
fi
grep -q "catalog has duplicate id: z-market-validate" "$TEST_ROOT/duplicate-identifiers.log" ||
  fail "doctor did not report the duplicate catalog identifier"
grep -q "eval manifest has duplicate id: market-tools-blocked" "$TEST_ROOT/duplicate-identifiers.log" ||
  fail "doctor did not report the duplicate behavioral identifier"
grep -q "routing manifest has duplicate id: market-vague" "$TEST_ROOT/duplicate-identifiers.log" ||
  fail "doctor did not report the duplicate routing identifier"
cp "$ROOT/catalog.yaml" "$VALIDATION_FIXTURE/catalog.yaml"
cp "$ROOT/evals/cases.yaml" "$VALIDATION_FIXTURE/evals/cases.yaml"
cp "$ROOT/evals/routing.yaml" "$VALIDATION_FIXTURE/evals/routing.yaml"
pass "doctor detects duplicate identifiers without subprocess sorting"

if (
  ZSTACK_REAL_FIND="$(command -v find)"
  ZSTACK_REAL_RUBY="$(command -v ruby)"
  export ZSTACK_REAL_FIND ZSTACK_REAL_RUBY
  # Invoked indirectly by the child Bash after export.
  # shellcheck disable=SC2329
  find() {
    local argument
    for argument in "$@"; do
      [[ "$argument" == */z-write-prd ]] && return 74
    done
    "$ZSTACK_REAL_FIND" "$@"
  }
  # Invoked indirectly by the child Bash after export.
  # shellcheck disable=SC2329
  ruby() {
    local argument
    for argument in "$@"; do
      [[ "$argument" == *'entry.fetch("expected_skill")'* ]] && return 74
    done
    "$ZSTACK_REAL_RUBY" "$@"
  }
  export -f find ruby
  "$ROOT/scripts/doctor.sh" --source-only > "$TEST_ROOT/doctor-preparation-failure.log" 2>&1
); then
  fail "doctor accepted failed handoff enumeration and Chinese routing preparation"
fi
grep -q "z-write-prd: Evidence handoff file enumeration failed" "$TEST_ROOT/doctor-preparation-failure.log" ||
  fail "doctor did not propagate the Evidence handoff enumeration failure"
grep -q "Chinese routing checks could not be prepared" "$TEST_ROOT/doctor-preparation-failure.log" ||
  fail "doctor did not propagate the Chinese routing preparation failure"
pass "doctor fails closed when handoff enumeration or Chinese routing preparation fails"

cp "$ROOT/hosts/codex.yaml" "$VALIDATION_FIXTURE/hosts/codex.yaml"
sed 's#^skills_root: ~/.codex/skills$#skills_root: /#' "$ROOT/hosts/codex.yaml" > "$VALIDATION_FIXTURE/hosts/codex.yaml"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/root.log" 2>&1; then
  fail "doctor accepted an unsafe host root"
fi
grep -q "skills_root must stay inside HOME" "$TEST_ROOT/root.log" || fail "doctor reported the wrong root failure"
pass "doctor rejects unsafe host roots"

sed 's#^skills_root: ~/.codex/skills$#skills_root: ~/../outside#' "$ROOT/hosts/codex.yaml" > "$VALIDATION_FIXTURE/hosts/codex.yaml"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/traversal-root.log" 2>&1; then
  fail "doctor accepted a host root outside HOME"
fi
grep -q "skills_root must stay inside HOME" "$TEST_ROOT/traversal-root.log" || fail "doctor reported the wrong traversal root failure"
pass "doctor rejects host roots that traverse outside HOME"

sed 's/^  description_max_chars: 1024$/  description_max_chars: 0/' "$ROOT/hosts/codex.yaml" > "$VALIDATION_FIXTURE/hosts/codex.yaml"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/description-limit.log" 2>&1; then
  fail "doctor accepted an invalid description limit"
fi
grep -q "description_max_chars must be a positive integer" "$TEST_ROOT/description-limit.log" || fail "doctor reported the wrong description limit failure"
pass "doctor validates host description limits"

cp "$ROOT/hosts/codex.yaml" "$VALIDATION_FIXTURE/hosts/codex.yaml"
rm -f "$VALIDATION_FIXTURE/evals/cases.yaml"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/evals.log" 2>&1; then
  fail "doctor accepted a missing eval manifest"
fi
grep -q "missing evals/cases.yaml" "$TEST_ROOT/evals.log" || fail "doctor reported the wrong eval failure"
pass "doctor requires the behavioral eval manifest"

cp "$ROOT/evals/cases.yaml" "$VALIDATION_FIXTURE/evals/cases.yaml"
sed '/Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence\./d' \
  "$ROOT/evals/cases.yaml" > "$VALIDATION_FIXTURE/evals/cases.yaml"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/eval-evidence-applicability.log" 2>&1; then
  fail "doctor accepted behavioral cases without the shared Evidence class applicability criterion"
fi
grep -q "evals/cases.yaml must test Evidence class applicability for every case" "$TEST_ROOT/eval-evidence-applicability.log" || fail "doctor reported the wrong Evidence class applicability failure"
pass "doctor requires Evidence class applicability review for every case"

cp "$ROOT/evals/cases.yaml" "$VALIDATION_FIXTURE/evals/cases.yaml"
awk '
  /^  - id: market-tools-blocked$/ { target = 1 }
  target && /^    must_not:$/ { empty_list = 1; print; next }
  empty_list && /^      - / { empty_list = 0; target = 0; next }
  { print }
' "$VALIDATION_FIXTURE/evals/cases.yaml" > "$VALIDATION_FIXTURE/evals/cases.yaml.next"
mv "$VALIDATION_FIXTURE/evals/cases.yaml.next" "$VALIDATION_FIXTURE/evals/cases.yaml"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/empty-eval.log" 2>&1; then
  fail "doctor accepted an empty eval criterion list"
fi
grep -q "eval needs at least one non-empty must_not criterion" "$TEST_ROOT/empty-eval.log" || fail "doctor reported the wrong empty eval failure"
pass "doctor rejects empty behavioral eval criteria"

cp "$ROOT/evals/cases.yaml" "$VALIDATION_FIXTURE/evals/cases.yaml"
awk '
  !changed && /^    kind:/ { $0 = "    kind: unknown"; changed = 1 }
  { print }
' "$VALIDATION_FIXTURE/evals/cases.yaml" > "$VALIDATION_FIXTURE/evals/cases.yaml.next"
mv "$VALIDATION_FIXTURE/evals/cases.yaml.next" "$VALIDATION_FIXTURE/evals/cases.yaml"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/eval-kind.log" 2>&1; then
  fail "doctor accepted an unknown behavioral eval kind"
fi
grep -q "eval kind must be happy-path, edge, or adversarial" "$TEST_ROOT/eval-kind.log" || fail "doctor reported the wrong eval-kind failure"
pass "doctor rejects unknown behavioral eval kinds"

cp "$ROOT/evals/cases.yaml" "$VALIDATION_FIXTURE/evals/cases.yaml"
awk '
  !changed && /^    execution: artifact$/ { $0 = "    execution: unknown"; changed = 1 }
  { print }
' "$VALIDATION_FIXTURE/evals/cases.yaml" > "$VALIDATION_FIXTURE/evals/cases.yaml.next"
mv "$VALIDATION_FIXTURE/evals/cases.yaml.next" "$VALIDATION_FIXTURE/evals/cases.yaml"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/eval-execution.log" 2>&1; then
  fail "doctor accepted an unknown behavioral eval execution mode"
fi
grep -q "eval execution must be response or artifact" "$TEST_ROOT/eval-execution.log" || fail "doctor reported the wrong eval-execution failure"
pass "doctor validates behavioral eval execution modes"

cp "$ROOT/evals/cases.yaml" "$VALIDATION_FIXTURE/evals/cases.yaml"
awk '
  /^  - id:/ { target = ($0 == "  - id: market-evidence-packet") }
  target && /^    kind: happy-path$/ { $0 = "    kind: edge"; target = 0 }
  { print }
' "$VALIDATION_FIXTURE/evals/cases.yaml" > "$VALIDATION_FIXTURE/evals/cases.yaml.next"
mv "$VALIDATION_FIXTURE/evals/cases.yaml.next" "$VALIDATION_FIXTURE/evals/cases.yaml"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/eval-happy-path.log" 2>&1; then
  fail "doctor accepted a skill without a happy-path behavioral eval"
fi
grep -q "z-market-validate: active skill needs at least 1 happy-path eval (found 0)" "$TEST_ROOT/eval-happy-path.log" || fail "doctor reported the wrong happy-path coverage failure"
pass "doctor requires a happy-path eval for every active skill"

cp "$ROOT/evals/cases.yaml" "$VALIDATION_FIXTURE/evals/cases.yaml"
awk '
  /^    skill:/ { target = ($0 == "    skill: z-market-validate") }
  target && /^    kind:/ { $0 = "    kind: happy-path"; target = 0 }
  { print }
' "$VALIDATION_FIXTURE/evals/cases.yaml" > "$VALIDATION_FIXTURE/evals/cases.yaml.next"
mv "$VALIDATION_FIXTURE/evals/cases.yaml.next" "$VALIDATION_FIXTURE/evals/cases.yaml"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/eval-resilience.log" 2>&1; then
  fail "doctor accepted a skill without an edge or adversarial behavioral eval"
fi
grep -q "z-market-validate: active skill needs at least 1 edge or adversarial eval (found 0)" "$TEST_ROOT/eval-resilience.log" || fail "doctor reported the wrong resilience coverage failure"
pass "doctor requires resilience coverage for every active skill"

cp "$ROOT/evals/cases.yaml" "$VALIDATION_FIXTURE/evals/cases.yaml"
awk '
  /^  - id:/ {
    target = ($0 == "  - id: market-tools-blocked" ||
              $0 == "  - id: market-competition-composite")
  }
  target && /^    skill: z-market-validate$/ { $0 = "    skill: z-write-prd"; target = 0 }
  { print }
' "$VALIDATION_FIXTURE/evals/cases.yaml" > "$VALIDATION_FIXTURE/evals/cases.yaml.next"
mv "$VALIDATION_FIXTURE/evals/cases.yaml.next" "$VALIDATION_FIXTURE/evals/cases.yaml"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/eval-count.log" 2>&1; then
  fail "doctor accepted insufficient behavioral eval coverage"
fi
grep -q "z-market-validate: active skill needs at least 3 behavioral evals (found 2)" "$TEST_ROOT/eval-count.log" || fail "doctor reported the wrong behavioral coverage failure"
pass "doctor requires three behavioral evals for every active skill"

cp "$ROOT/evals/cases.yaml" "$VALIDATION_FIXTURE/evals/cases.yaml"
rm -f "$VALIDATION_FIXTURE/evals/routing.yaml"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/routing-missing.log" 2>&1; then
  fail "doctor accepted a missing routing eval manifest"
fi
grep -q "missing evals/routing.yaml" "$TEST_ROOT/routing-missing.log" || fail "doctor reported the wrong missing-routing failure"
pass "doctor requires the routing eval manifest"

cp "$ROOT/evals/routing.yaml" "$VALIDATION_FIXTURE/evals/routing.yaml"
awk '
  !changed && /^    expected_skill: z-market-validate$/ {
    $0 = "    expected_skill: z-missing-skill"
    changed = 1
  }
  { print }
' "$VALIDATION_FIXTURE/evals/routing.yaml" > "$VALIDATION_FIXTURE/evals/routing.yaml.next"
mv "$VALIDATION_FIXTURE/evals/routing.yaml.next" "$VALIDATION_FIXTURE/evals/routing.yaml"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/routing-skill.log" 2>&1; then
  fail "doctor accepted an unknown routing target"
fi
grep -q "routing eval references unknown or inactive skill 'z-missing-skill'" "$TEST_ROOT/routing-skill.log" || fail "doctor reported the wrong routing-target failure"
pass "doctor rejects unknown routing targets"

cp "$ROOT/evals/routing.yaml" "$VALIDATION_FIXTURE/evals/routing.yaml"
awk '
  /^  - id: market-vague$/ { target = 1 }
  target && /^    expected_skill:/ {
    print "      Run /z-market-validate explicitly."
    target = 0
  }
  { print }
' "$VALIDATION_FIXTURE/evals/routing.yaml" > "$VALIDATION_FIXTURE/evals/routing.yaml.next"
mv "$VALIDATION_FIXTURE/evals/routing.yaml.next" "$VALIDATION_FIXTURE/evals/routing.yaml"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/routing-leak.log" 2>&1; then
  fail "doctor accepted a routing prompt that names its skill"
fi
grep -q "routing prompt must not name a z-\* skill or use a host-specific invocation" "$TEST_ROOT/routing-leak.log" || fail "doctor reported the wrong routing-leak failure"
pass "doctor keeps routing prompts free of expected-skill leakage"

cp "$ROOT/evals/routing.yaml" "$VALIDATION_FIXTURE/evals/routing.yaml"
awk '
  /^    expected_skill: z-write-prd$/ {
    if (kept_one) {
      $0 = "    expected_skill: none"
    } else {
      kept_one = 1
    }
  }
  { print }
' "$VALIDATION_FIXTURE/evals/routing.yaml" > "$VALIDATION_FIXTURE/evals/routing.yaml.next"
mv "$VALIDATION_FIXTURE/evals/routing.yaml.next" "$VALIDATION_FIXTURE/evals/routing.yaml"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/routing-coverage.log" 2>&1; then
  fail "doctor accepted insufficient routing coverage"
fi
grep -q "z-write-prd: active skill needs at least 2 routing evals (found 1)" "$TEST_ROOT/routing-coverage.log" || fail "doctor reported the wrong routing-coverage failure"
pass "doctor requires routing coverage for every active skill"

cp "$ROOT/evals/routing.yaml" "$VALIDATION_FIXTURE/evals/routing.yaml"
awk '
  /^    expected_skill: none$/ {
    if (kept_one) {
      $0 = "    expected_skill: z-market-validate"
    } else {
      kept_one = 1
    }
  }
  { print }
' "$VALIDATION_FIXTURE/evals/routing.yaml" > "$VALIDATION_FIXTURE/evals/routing.yaml.next"
mv "$VALIDATION_FIXTURE/evals/routing.yaml.next" "$VALIDATION_FIXTURE/evals/routing.yaml"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/routing-no-match.log" 2>&1; then
  fail "doctor accepted insufficient no-match routing coverage"
fi
grep -q "routing manifest needs at least 2 no-match cases (found 1)" "$TEST_ROOT/routing-no-match.log" || fail "doctor reported the wrong no-match coverage failure"
pass "doctor requires unrelated no-match routing coverage"

cp "$ROOT/evals/routing.yaml" "$VALIDATION_FIXTURE/evals/routing.yaml"
awk '
  /^  - id:/ { target = ($0 == "  - id: zh-prd-notes") }
  target && /^    expected_skill: z-write-prd$/ {
    $0 = "    expected_skill: z-market-validate"
    target = 0
  }
  { print }
' "$VALIDATION_FIXTURE/evals/routing.yaml" > "$VALIDATION_FIXTURE/evals/routing.yaml.next"
mv "$VALIDATION_FIXTURE/evals/routing.yaml.next" "$VALIDATION_FIXTURE/evals/routing.yaml"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/routing-chinese-positive.log" 2>&1; then
  fail "doctor accepted a Chinese-trigger description without a Chinese routing eval"
fi
grep -q "z-write-prd: description advertises Chinese triggers but has no Chinese routing eval" "$TEST_ROOT/routing-chinese-positive.log" || fail "doctor reported the wrong Chinese routing-coverage failure"
pass "doctor requires Chinese routing coverage for advertised triggers"

cp "$ROOT/evals/routing.yaml" "$VALIDATION_FIXTURE/evals/routing.yaml"
awk '
  /^  - id:/ { chinese_case = ($0 ~ /^  - id: zh-/) }
  chinese_case && /^    expected_skill: none$/ {
    $0 = "    expected_skill: z-market-validate"
    chinese_case = 0
  }
  { print }
' "$VALIDATION_FIXTURE/evals/routing.yaml" > "$VALIDATION_FIXTURE/evals/routing.yaml.next"
mv "$VALIDATION_FIXTURE/evals/routing.yaml.next" "$VALIDATION_FIXTURE/evals/routing.yaml"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/routing-chinese-no-match.log" 2>&1; then
  fail "doctor accepted a routing suite without a Chinese no-match case"
fi
grep -q "routing manifest needs at least 1 Chinese no-match case (found 0)" "$TEST_ROOT/routing-chinese-no-match.log" || fail "doctor reported the wrong Chinese no-match coverage failure"
pass "doctor requires Chinese no-match routing coverage"

cp "$ROOT/evals/routing.yaml" "$VALIDATION_FIXTURE/evals/routing.yaml"
cp "$ROOT/catalog.yaml" "$VALIDATION_FIXTURE/catalog.yaml"
awk '
  /^  - id: z-write-prd$/ { target = 1 }
  target && /^    tags:$/ { empty_list = 1; print; next }
  empty_list && /^      - / { next }
  empty_list { empty_list = 0; target = 0 }
  { print }
' "$VALIDATION_FIXTURE/catalog.yaml" > "$VALIDATION_FIXTURE/catalog.yaml.next"
mv "$VALIDATION_FIXTURE/catalog.yaml.next" "$VALIDATION_FIXTURE/catalog.yaml"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/empty-tags.log" 2>&1; then
  fail "doctor accepted an empty catalog tag list"
fi
grep -q "catalog entry needs at least one non-empty tag" "$TEST_ROOT/empty-tags.log" || fail "doctor reported the wrong empty tag failure"
pass "doctor rejects empty catalog tags"

cp "$ROOT/catalog.yaml" "$VALIDATION_FIXTURE/catalog.yaml"
awk '
  /^  - id:/ { target = ($0 == "  - id: z-write-prd") }
  target && /^      - product$/ { $0 = "      - Product Strategy" }
  { print }
' "$VALIDATION_FIXTURE/catalog.yaml" > "$VALIDATION_FIXTURE/catalog.yaml.next"
mv "$VALIDATION_FIXTURE/catalog.yaml.next" "$VALIDATION_FIXTURE/catalog.yaml"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/invalid-tag.log" 2>&1; then
  fail "doctor accepted an invalid catalog tag"
fi
grep -q "catalog tag 'Product Strategy' must be kebab-case" "$TEST_ROOT/invalid-tag.log" || fail "doctor reported the wrong invalid tag failure"
pass "doctor rejects non-portable catalog tags"

cp "$ROOT/catalog.yaml" "$VALIDATION_FIXTURE/catalog.yaml"
awk '
  /^  - id: z-write-prd$/ { target = 1 }
  target && /^      - indie$/ { print; print; target = 0; next }
  { print }
' "$VALIDATION_FIXTURE/catalog.yaml" > "$VALIDATION_FIXTURE/catalog.yaml.next"
mv "$VALIDATION_FIXTURE/catalog.yaml.next" "$VALIDATION_FIXTURE/catalog.yaml"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/duplicate-tag.log" 2>&1; then
  fail "doctor accepted a duplicate catalog tag"
fi
grep -q "duplicate catalog tag 'indie'" "$TEST_ROOT/duplicate-tag.log" || fail "doctor reported the wrong duplicate tag failure"
pass "doctor rejects duplicate catalog tags"

cp "$ROOT/catalog.yaml" "$VALIDATION_FIXTURE/catalog.yaml"
awk '
  /^  - id:/ { target = ($0 == "  - id: z-write-prd") }
  target && /^      - indie$/ { next }
  { print }
' "$VALIDATION_FIXTURE/catalog.yaml" > "$VALIDATION_FIXTURE/catalog.yaml.next"
mv "$VALIDATION_FIXTURE/catalog.yaml.next" "$VALIDATION_FIXTURE/catalog.yaml"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/missing-indie-tag.log" 2>&1; then
  fail "doctor accepted catalog tags without the indie baseline"
fi
grep -q "catalog tags must include 'indie'" "$TEST_ROOT/missing-indie-tag.log" || fail "doctor reported the wrong indie tag failure"
pass "doctor requires the indie audience tag"

cp "$ROOT/catalog.yaml" "$VALIDATION_FIXTURE/catalog.yaml"
awk '
  /^  - id: z-write-prd$/ { target = 1 }
  target && /^    summary: >-$/ { empty_summary = 1; print; next }
  empty_summary && /^      / { next }
  empty_summary { empty_summary = 0; target = 0 }
  { print }
' "$VALIDATION_FIXTURE/catalog.yaml" > "$VALIDATION_FIXTURE/catalog.yaml.next"
mv "$VALIDATION_FIXTURE/catalog.yaml.next" "$VALIDATION_FIXTURE/catalog.yaml"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/empty-summary.log" 2>&1; then
  fail "doctor accepted an empty catalog summary"
fi
grep -q "catalog summary must contain at least 20 characters" "$TEST_ROOT/empty-summary.log" || fail "doctor reported the wrong empty summary failure"
pass "doctor rejects empty catalog summaries"

cp "$ROOT/catalog.yaml" "$VALIDATION_FIXTURE/catalog.yaml"
cp "$ROOT/evals/cases.yaml" "$VALIDATION_FIXTURE/evals/cases.yaml"
git -C "$VALIDATION_FIXTURE" init -q
git -C "$VALIDATION_FIXTURE" add -f --all
printf 'ghp_%020d\n' 0 > "$VALIDATION_FIXTURE/evals/leak.txt"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/secret.log" 2>&1; then
  fail "doctor accepted a secret outside skills and catalog"
fi
grep -q "possible secret detected in tracked or unignored repository content" "$TEST_ROOT/secret.log" || fail "doctor reported the wrong repository secret failure"
grep -q '^  evals/leak.txt$' "$TEST_ROOT/secret.log" ||
  fail "doctor did not identify the repository candidate containing a secret"
secret_fixture_value="$(printf 'ghp_%020d' 0)"
if grep -Fq "$secret_fixture_value" "$TEST_ROOT/secret.log"; then
  fail "doctor leaked a detected secret value while reporting its path"
fi
rm -f "$VALIDATION_FIXTURE/evals/leak.txt"

secret_symlink_target="$(printf 'ghp_%020d' 1)"
ln -s "$secret_symlink_target" "$VALIDATION_FIXTURE/evals/secret-link"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast \
  > "$TEST_ROOT/secret-symlink.log" 2>&1; then
  fail "doctor accepted a secret in a repository candidate symlink target"
fi
grep -q '^  evals/secret-link$' "$TEST_ROOT/secret-symlink.log" ||
  fail "doctor did not identify the symlink candidate containing a secret"
if grep -Fq "$secret_symlink_target" "$TEST_ROOT/secret-symlink.log"; then
  fail "doctor leaked a secret symlink target while reporting its path"
fi
unlink "$VALIDATION_FIXTURE/evals/secret-link"
pass "doctor reports secret-bearing candidate paths without exposing values"

for secret_cap_index in 10 11 12 13 14 15; do
  secret_cap_value="$(printf 'ghp_%020d' "$secret_cap_index")"
  printf '%s\n' "$secret_cap_value" > \
    "$VALIDATION_FIXTURE/evals/secret-cap-$secret_cap_index.txt"
done
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only \
  > "$TEST_ROOT/secret-cap.log" 2>&1; then
  fail "doctor accepted six secret-bearing repository candidates"
fi
[[ "$(grep -c '^  evals/secret-cap-[0-9][0-9]\.txt$' "$TEST_ROOT/secret-cap.log")" -eq 5 ]] ||
  fail "doctor did not cap secret-bearing candidate paths at five"
[[ "$(grep -c '^  \.\.\.$' "$TEST_ROOT/secret-cap.log")" -eq 1 ]] ||
  fail "doctor did not mark one truncated secret-path list"
grep -q '^errors=1 warnings=0$' "$TEST_ROOT/secret-cap.log" ||
  fail "doctor did not finish its aggregate summary after reporting secret paths"
for secret_cap_index in 10 11 12 13 14 15; do
  secret_cap_value="$(printf 'ghp_%020d' "$secret_cap_index")"
  if grep -Fq "$secret_cap_value" "$TEST_ROOT/secret-cap.log"; then
    fail "doctor leaked a secret value from its truncated path report"
  fi
  rm -f "$VALIDATION_FIXTURE/evals/secret-cap-$secret_cap_index.txt"
done
pass "doctor caps aggregate secret-path diagnostics without exposing values"

printf '%s\n' '[broken](missing-file.md)' > "$VALIDATION_FIXTURE/evals/broken-link.md"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/markdown-link.log" 2>&1; then
  fail "doctor accepted a broken link in unignored Markdown"
fi
grep -q "broken local Markdown link in evals/broken-link.md" "$TEST_ROOT/markdown-link.log" || fail "doctor reported the wrong Markdown-link failure"
rm -f "$VALIDATION_FIXTURE/evals/broken-link.md"
pass "doctor checks Markdown links in commit candidates"

DOCTOR_DELETED_CANDIDATE_FIXTURE="$(copy_fixture doctor-deleted-candidate)"
git -C "$DOCTOR_DELETED_CANDIDATE_FIXTURE" init -q
git -C "$DOCTOR_DELETED_CANDIDATE_FIXTURE" add -f --all
printf '%s\n' 'tracked content scheduled for deletion' > \
  "$DOCTOR_DELETED_CANDIDATE_FIXTURE/evals/deleted-candidate.md"
git -C "$DOCTOR_DELETED_CANDIDATE_FIXTURE" add evals/deleted-candidate.md
rm -f "$DOCTOR_DELETED_CANDIDATE_FIXTURE/evals/deleted-candidate.md"
"$DOCTOR_DELETED_CANDIDATE_FIXTURE/scripts/doctor.sh" --source-only \
  > "$TEST_ROOT/doctor-deleted-candidate.log" 2>&1 ||
  fail "doctor treated a tracked worktree deletion as a live commit candidate"
grep -q 'repository candidates remained stable across portability validation' \
  "$TEST_ROOT/doctor-deleted-candidate.log" ||
  fail "doctor did not validate the remaining live candidates after a tracked deletion"
pass "doctor excludes tracked worktree deletions from live candidate scans"

printf 'ghp_%020d\n' 0 > "$VALIDATION_FIXTURE/.env"
printf 'ghp_%020d\n' 0 > "$VALIDATION_FIXTURE/.dev.vars"
mkdir -p "$VALIDATION_FIXTURE/.gstack"
mkdir -p "$VALIDATION_FIXTURE/.wrangler/state"
printf '%s\n' '[ignored broken link](missing-file.md)' > "$VALIDATION_FIXTURE/.gstack/ignored.md"
printf '%s\n' '[ignored Wrangler link](missing-file.md)' > \
  "$VALIDATION_FIXTURE/.wrangler/state/ignored.md"
"$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only >/dev/null || fail "doctor scanned Git-ignored local content"
pass "doctor skips ignored local secrets and Markdown"

printf 'ghp_%020d\n' 0 > "$VALIDATION_FIXTURE/.env.example"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast \
  > "$TEST_ROOT/doctor-git-public-env.log" 2>&1; then
  fail "Git-backed doctor ignored the public .env.example candidate"
fi
grep -q 'possible secret detected in tracked or unignored repository content' \
  "$TEST_ROOT/doctor-git-public-env.log" ||
  fail "Git-backed doctor reported the wrong public .env.example failure"
rm -f "$VALIDATION_FIXTURE/.env.example"
printf 'ghp_%020d\n' 0 > "$VALIDATION_FIXTURE/.dev.vars.example"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast \
  > "$TEST_ROOT/doctor-git-public-dev-vars.log" 2>&1; then
  fail "Git-backed doctor ignored the public .dev.vars.example candidate"
fi
grep -q 'possible secret detected in tracked or unignored repository content' \
  "$TEST_ROOT/doctor-git-public-dev-vars.log" ||
  fail "Git-backed doctor reported the wrong public .dev.vars.example failure"
rm -f "$VALIDATION_FIXTURE/.dev.vars.example"
pass "Git candidate discovery scans public env examples"

NO_GIT_PRIVACY_FIXTURE="$(copy_fixture doctor-no-git-privacy)"
mkdir -p "$NO_GIT_PRIVACY_FIXTURE/logs" \
  "$NO_GIT_PRIVACY_FIXTURE/.gstack" \
  "$NO_GIT_PRIVACY_FIXTURE/.zstack-new-skill.fixture" \
  "$NO_GIT_PRIVACY_FIXTURE/.wrangler/state" \
  "$NO_GIT_PRIVACY_FIXTURE/node_modules/private-package"
printf 'ghp_%020d\n' 0 > "$NO_GIT_PRIVACY_FIXTURE/.env"
printf 'ghp_%020d\n' 0 > "$NO_GIT_PRIVACY_FIXTURE/.env.local"
printf 'ghp_%020d\n' 0 > "$NO_GIT_PRIVACY_FIXTURE/.dev.vars"
printf 'ghp_%020d\n' 0 > "$NO_GIT_PRIVACY_FIXTURE/.dev.vars.local"
printf 'ghp_%020d\n' 0 > "$NO_GIT_PRIVACY_FIXTURE/.DS_Store"
printf 'ghp_%020d\n' 0 > "$NO_GIT_PRIVACY_FIXTURE/local.log"
printf 'ghp_%020d\n' 0 > "$NO_GIT_PRIVACY_FIXTURE/local.pid"
printf 'ghp_%020d\n' 0 > "$NO_GIT_PRIVACY_FIXTURE/local.pid.lock"
printf '%s\n' '[ignored broken link](missing-file.md)' > \
  "$NO_GIT_PRIVACY_FIXTURE/logs/ignored.md"
printf '%s\n' '[ignored gstack link](missing-file.md)' > \
  "$NO_GIT_PRIVACY_FIXTURE/.gstack/ignored.md"
printf 'ghp_%020d\n' 0 > \
  "$NO_GIT_PRIVACY_FIXTURE/.zstack-new-skill.fixture/token.txt"
printf 'ghp_%020d\n' 0 > \
  "$NO_GIT_PRIVACY_FIXTURE/node_modules/private-package/token.txt"
printf 'ghp_%020d\n' 0 > "$NO_GIT_PRIVACY_FIXTURE/.wrangler/state/token.txt"
"$NO_GIT_PRIVACY_FIXTURE/scripts/doctor.sh" --source-only \
  > "$TEST_ROOT/doctor-no-git-privacy.log" 2>&1 ||
  fail "no-Git doctor scanned conservative local-state exclusions"
printf 'ghp_%020d\n' 0 > "$NO_GIT_PRIVACY_FIXTURE/.env.example"
if "$NO_GIT_PRIVACY_FIXTURE/scripts/doctor.sh" --source-only --fail-fast \
  > "$TEST_ROOT/doctor-no-git-public-env.log" 2>&1; then
  fail "no-Git doctor ignored the public .env.example candidate"
fi
grep -q 'possible secret detected in tracked or unignored repository content' \
  "$TEST_ROOT/doctor-no-git-public-env.log" ||
  fail "no-Git doctor reported the wrong public .env.example failure"
rm -f "$NO_GIT_PRIVACY_FIXTURE/.env.example"
printf 'ghp_%020d\n' 0 > "$NO_GIT_PRIVACY_FIXTURE/.dev.vars.example"
if "$NO_GIT_PRIVACY_FIXTURE/scripts/doctor.sh" --source-only --fail-fast \
  > "$TEST_ROOT/doctor-no-git-public-dev-vars.log" 2>&1; then
  fail "no-Git doctor ignored the public .dev.vars.example candidate"
fi
grep -q 'possible secret detected in tracked or unignored repository content' \
  "$TEST_ROOT/doctor-no-git-public-dev-vars.log" ||
  fail "no-Git doctor reported the wrong public .dev.vars.example failure"
pass "no-Git candidate discovery excludes private local state but scans public env examples"

if (
  ZSTACK_REAL_GIT="$(command -v git)"
  export ZSTACK_REAL_GIT
  # Invoked indirectly by the child Bash after export.
  # shellcheck disable=SC2329
  git() {
    local argument
    for argument in "$@"; do
      [[ "$argument" == "ls-files" ]] && return 74
    done
    "$ZSTACK_REAL_GIT" "$@"
  }
  export -f git
  "$ROOT/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/candidate-inventory-failure.log" 2>&1
); then
  fail "doctor accepted a failed repository candidate inventory"
fi
grep -q "repository candidate inventory failed" "$TEST_ROOT/candidate-inventory-failure.log" ||
  fail "doctor reported the wrong repository inventory failure"

if (
  ZSTACK_REAL_GIT="$(command -v git)"
  export ZSTACK_REAL_GIT
  # Invoked indirectly by the child Bash after export.
  # shellcheck disable=SC2329
  git() {
    local argument
    for argument in "$@"; do
      if [[ "$argument" == "ls-files" ]]; then
        printf '../outside-repository\0'
        return 0
      fi
    done
    "$ZSTACK_REAL_GIT" "$@"
  }
  export -f git
  "$ROOT/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/unsafe-candidate-inventory.log" 2>&1
); then
  fail "doctor accepted an unsafe repository candidate path"
fi
grep -q "repository candidate path is not canonical portable UTF-8" \
  "$TEST_ROOT/unsafe-candidate-inventory.log" ||
  fail "doctor did not reject an unsafe path while binding the candidate inventory"

unsafe_no_ruby_candidates=(
  './UNSAFE_CANDIDATE_MARKER'
  'double//UNSAFE_CANDIDATE_MARKER'
  ' UNSAFE_CANDIDATE_MARKER'
  'UNSAFE_CANDIDATE_MARKER '
  $'control\033UNSAFE_CANDIDATE_MARKER'
  $'line\nUNSAFE_CANDIDATE_MARKER'
)
unsafe_no_ruby_index=0
for unsafe_no_ruby_candidate in "${unsafe_no_ruby_candidates[@]}"; do
  unsafe_no_ruby_index=$((unsafe_no_ruby_index + 1))
  unsafe_no_ruby_log="$TEST_ROOT/unsafe-no-ruby-candidate-$unsafe_no_ruby_index.log"
  if (
    ZSTACK_REAL_GIT="$(command -v git)"
    UNSAFE_NO_RUBY_CANDIDATE="$unsafe_no_ruby_candidate"
    export ZSTACK_REAL_GIT UNSAFE_NO_RUBY_CANDIDATE
    # Invoked indirectly by the child Bash after export.
    # shellcheck disable=SC2329
    git() {
      local argument
      for argument in "$@"; do
        if [[ "$argument" == "ls-files" ]]; then
          printf '%s\0' "$UNSAFE_NO_RUBY_CANDIDATE"
          return 0
        fi
      done
      "$ZSTACK_REAL_GIT" "$@"
    }
    export -f git
    PATH="$NO_RUBY_BIN" \
      "$ROOT/scripts/doctor.sh" --source-only --fail-fast > "$unsafe_no_ruby_log" 2>&1
  ); then
    fail "no-Ruby doctor accepted unsafe repository candidate case $unsafe_no_ruby_index"
  fi
  grep -q 'repository candidate preflight could not be validated' "$unsafe_no_ruby_log" ||
    fail "no-Ruby doctor reported the wrong unsafe-candidate failure"
  if grep -Fq 'UNSAFE_CANDIDATE_MARKER' "$unsafe_no_ruby_log"; then
    fail "no-Ruby doctor echoed an unsafe repository candidate"
  fi
done
pass "no-Ruby candidate preflight rejects noncanonical and control-character paths safely"

if (
  ZSTACK_REAL_GREP="$(command -v grep)"
  export ZSTACK_REAL_GREP
  # Invoked indirectly by the child Bash after export.
  # shellcheck disable=SC2329
  grep() {
    local argument
    for argument in "$@"; do
      [[ "$argument" == *"mcp__"* ]] && return 74
    done
    "$ZSTACK_REAL_GREP" "$@"
  }
  export -f grep
  "$ROOT/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/portability-scan-failure.log" 2>&1
); then
  fail "doctor accepted a failed skill portability scan"
fi
grep -q "skill portability scan failed" "$TEST_ROOT/portability-scan-failure.log" ||
  fail "doctor reported the wrong skill portability-scan failure"

printf '%s\n' 'ordinary untracked scan candidate' > "$VALIDATION_FIXTURE/evals/scan-candidate.txt"
if (
  ZSTACK_REAL_XARGS="$(command -v xargs)"
  export ZSTACK_REAL_XARGS
  # Invoked indirectly by the child Bash after export.
  # shellcheck disable=SC2329
  xargs() {
    local argument
    for argument in "$@"; do
      [[ "$argument" == *"AKIA[A-Z0-9]{16}"* ]] && return 74
    done
    "$ZSTACK_REAL_XARGS" "$@"
  }
  export -f xargs
  "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/secret-scan-failure.log" 2>&1
); then
  fail "doctor accepted a failed repository secret scan"
fi
grep -q "repository secret scan failed" "$TEST_ROOT/secret-scan-failure.log" ||
  fail "doctor reported the wrong repository secret-scan failure"
rm -f "$VALIDATION_FIXTURE/evals/scan-candidate.txt"
pass "doctor fails closed when repository inventory, Markdown, portability, or secret scanning fails"

DOCTOR_CANDIDATE_STATE_FIXTURE="$(copy_fixture doctor-candidate-state)"
DOCTOR_CANDIDATE_STATE_NEW_PATH="$DOCTOR_CANDIDATE_STATE_FIXTURE/evals/concurrent-candidate.md"
DOCTOR_CANDIDATE_STATE_TMP="$TEST_ROOT/doctor-candidate-state-tmp"
DOCTOR_CANDIDATE_STATE_MARKER="$TEST_ROOT/doctor-candidate-state-marker"
DOCTOR_CANDIDATE_STATE_REAL_GREP="$(command -v grep)"
mkdir -p "$DOCTOR_CANDIDATE_STATE_TMP" "$TEST_ROOT/doctor-candidate-state-bin"
chmod 700 "$DOCTOR_CANDIDATE_STATE_TMP"
# These single-quoted lines are the source of the generated fault-injection shim.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'status=0' \
  'is_markdown_scan=0' \
  'for argument in "$@"; do' \
  '  [[ "$argument" != *"\]\("* ]] || is_markdown_scan=1' \
  'done' \
  '"$REAL_GREP_BIN" "$@" || status=$?' \
  'if [[ "$is_markdown_scan" -eq 1 && ! -e "$STATE_MARKER" ]]; then' \
  '  printf "%s\n" "new candidate must survive" > "$NEW_CANDIDATE_PATH"' \
  '  : > "$STATE_MARKER"' \
  'fi' \
  'exit "$status"' > "$TEST_ROOT/doctor-candidate-state-bin/grep"
chmod +x "$TEST_ROOT/doctor-candidate-state-bin/grep"
if PATH="$TEST_ROOT/doctor-candidate-state-bin:$PATH" \
  REAL_GREP_BIN="$DOCTOR_CANDIDATE_STATE_REAL_GREP" \
  NEW_CANDIDATE_PATH="$DOCTOR_CANDIDATE_STATE_NEW_PATH" \
  STATE_MARKER="$DOCTOR_CANDIDATE_STATE_MARKER" \
  TMPDIR="$DOCTOR_CANDIDATE_STATE_TMP" \
  "$DOCTOR_CANDIDATE_STATE_FIXTURE/scripts/doctor.sh" --source-only \
  > "$TEST_ROOT/doctor-candidate-state.log" 2>&1; then
  fail "doctor accepted repository candidate drift during portability validation"
fi
[[ -f "$DOCTOR_CANDIDATE_STATE_MARKER" ]] ||
  fail "doctor candidate-state fixture did not mutate during Markdown scanning"
grep -qx 'new candidate must survive' "$DOCTOR_CANDIDATE_STATE_NEW_PATH" ||
  fail "doctor discarded a repository candidate added during validation"
grep -q 'repository candidates changed during portability validation' \
  "$TEST_ROOT/doctor-candidate-state.log" ||
  fail "doctor reported the wrong repository candidate drift failure"
if grep -q 'broken local Markdown link' "$TEST_ROOT/doctor-candidate-state.log"; then
  fail "doctor candidate-state fixture introduced an unrelated Markdown failure"
fi
doctor_candidate_state_temps="$(find "$DOCTOR_CANDIDATE_STATE_TMP" \
  -mindepth 1 -maxdepth 1 -print | wc -l | tr -d ' ')"
[[ "$doctor_candidate_state_temps" -eq 0 ]] ||
  fail "doctor repository candidate drift left temporary files"
pass "doctor re-enumerates and invalidates results when commit-candidate membership drifts"

EVIDENCE_FIXTURE="$TEST_ROOT/evidence-validation"
mkdir -p "$EVIDENCE_FIXTURE/scripts/lib" "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/raw"
cp "$ROOT/scripts/validate-evidence.rb" "$EVIDENCE_FIXTURE/scripts/validate-evidence.rb"
cp "$ROOT/scripts/generate-evidence-manifests.rb" "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb"
cp "$ROOT/scripts/lib/eval_archive_lock.rb" "$EVIDENCE_FIXTURE/scripts/lib/eval_archive_lock.rb"
cp "$ROOT/scripts/lib/eval_archive_name.rb" "$EVIDENCE_FIXTURE/scripts/lib/eval_archive_name.rb"
cp "$ROOT/scripts/lib/eval_input_file.rb" "$EVIDENCE_FIXTURE/scripts/lib/eval_input_file.rb"
cp "$ROOT/scripts/lib/eval_limits.rb" "$EVIDENCE_FIXTURE/scripts/lib/eval_limits.rb"
cp "$ROOT/scripts/lib/eval_output_file.rb" "$EVIDENCE_FIXTURE/scripts/lib/eval_output_file.rb"
cp "$ROOT/scripts/lib/eval_public_text.rb" "$EVIDENCE_FIXTURE/scripts/lib/eval_public_text.rb"
cp "$ROOT/scripts/lib/eval_strict_json.rb" "$EVIDENCE_FIXTURE/scripts/lib/eval_strict_json.rb"
cp "$ROOT/scripts/lib/eval_strict_yaml.rb" "$EVIDENCE_FIXTURE/scripts/lib/eval_strict_yaml.rb"
printf '%s\n' 'version: 1' 'cases:' '  - id: example-case' > "$EVIDENCE_FIXTURE/evals/cases.yaml"
printf '%s\n' 'version: 1' 'cases:' '  - id: example-route' > "$EVIDENCE_FIXTURE/evals/routing.yaml"
printf '%s\n' '# Prompt' > "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/prompts.md"
printf '%s\n' '# Summary' > "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/summary.md"
printf '%s\n' '{"schemaVersion":2,"archiveDate":"2026-01-01","suite":"behavioral","host":{"name":"Example","version":"1.0"},"provenance":{"status":"complete","gaps":[]},"runs":[{"id":"baseline","case":"example-case","phase":"baseline","model":"example-model","workspace":"temporary directory","permissions":"writes limited to temporary directory","webSearch":false,"subagents":false,"maxTurns":1,"stopStatus":"stop","grade":"pass","exitStatus":0,"elapsedSeconds":1.25,"totalCostUsd":0.01,"tokenUsage":{"total_tokens":10},"artifacts":["response.md"]}],"runnerIncidents":[]}' > "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/run.json"
cp "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/run.json" "$EVIDENCE_FIXTURE/run.valid.json"
printf '%s' 'artifact' > "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/raw/response.md"
artifact_digest="$(ruby -rdigest -e 'print Digest::SHA256.file(ARGV.fetch(0)).hexdigest' \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/raw/response.md")"
printf '%s\n' \
  'sha256                                                            bytes  path' \
  "$artifact_digest  8  response.md" > "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/raw/artifact-manifest.txt"
ruby "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb" \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example" >/dev/null || fail "archive-manifest generator rejected a valid archive"
ruby "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb" --check \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example" >/dev/null || fail "archive-manifest check rejected fresh output"
ruby "$EVIDENCE_FIXTURE/scripts/validate-evidence.rb" >/dev/null || fail "evidence validator rejected a valid archive"

MANIFEST_LOCK_READY="$TEST_ROOT/manifest-lock-ready"
MANIFEST_LOCK_RELEASE="$TEST_ROOT/manifest-lock-release"
ruby -I "$EVIDENCE_FIXTURE/scripts/lib" -r eval_archive_lock -e '
  lock = Zstack::EvalArchiveLock.acquire(ARGV.fetch(0))
  File.write(ARGV.fetch(1), "ready\n")
  1_000.times do
    break if File.exist?(ARGV.fetch(2))
    sleep 0.01
  end
  lock.close
' "$EVIDENCE_FIXTURE/evals/runs" "$MANIFEST_LOCK_READY" "$MANIFEST_LOCK_RELEASE" &
MANIFEST_LOCK_PID=$!
for _manifest_lock_wait in {1..200}; do
  [[ -f "$MANIFEST_LOCK_READY" ]] && break
  sleep 0.01
done
[[ -f "$MANIFEST_LOCK_READY" ]] || fail "manifest lock holder did not start"
if ruby "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb" --check \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example" > "$TEST_ROOT/archive-generator-lock.log" 2>&1; then
  fail "archive-manifest generator ignored the shared publication lock"
fi
grep -q "another evaluation archive publication is in progress" "$TEST_ROOT/archive-generator-lock.log" ||
  fail "archive-manifest generator reported the wrong lock contention"
: > "$MANIFEST_LOCK_RELEASE"
wait "$MANIFEST_LOCK_PID"
pass "archive-manifest generation shares the archive publication lock"

if ruby "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb" \
  --publication-lock-held --check \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example" > "$TEST_ROOT/archive-generator-forged-parent-lock.log" 2>&1; then
  fail "archive-manifest generator accepted a forged parent-lock declaration"
fi
grep -q "caller did not prove that its parent holds the publication lock" \
  "$TEST_ROOT/archive-generator-forged-parent-lock.log" ||
  fail "archive-manifest generator reported the wrong forged parent-lock failure"
pass "archive-manifest generation verifies inherited publication-lock ownership"

MANIFEST_REPLACED_PARENT_LOCK_LOG="$TEST_ROOT/archive-generator-replaced-parent-lock.log"
ruby -I "$EVIDENCE_FIXTURE/scripts/lib" -r eval_archive_lock -rdigest -rtmpdir -rrbconfig -e '
  root = File.realpath(ARGV.fetch(0))
  generator = ARGV.fetch(1)
  archive = ARGV.fetch(2)
  log = ARGV.fetch(3)
  key = Digest::SHA256.hexdigest(root)[0, 32]
  lock_path = File.join(Dir.tmpdir, "zstack-eval-archive-#{key}.lock")
  displaced_path = "#{lock_path}.parent-#{Process.pid}"
  File.unlink(displaced_path) if File.exist?(displaced_path) || File.symlink?(displaced_path)

  lock = Zstack::EvalArchiveLock.acquire(root)
  begin
    File.rename(lock_path, displaced_path)
    File.open(lock_path, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
      file.write("#{Process.pid}\n")
    end
    accepted = system(
      RbConfig.ruby, generator, "--publication-lock-held", "--check", archive,
      out: log, err: [:child, :out]
    )
    abort "archive-manifest generator accepted a replacement parent lock" if accepted
    output = File.read(log)
    unless output.include?("caller did not prove that its parent holds the publication lock")
      abort "archive-manifest generator reported the wrong replaced-parent failure"
    end
    unless File.binread(lock_path) == "#{Process.pid}\n"
      abort "archive-manifest generator changed the replacement parent lock"
    end
  ensure
    lock.close
    File.unlink(lock_path) if File.exist?(lock_path) || File.symlink?(lock_path)
    File.unlink(displaced_path) if File.exist?(displaced_path) || File.symlink?(displaced_path)
  end
' "$EVIDENCE_FIXTURE/evals/runs" \
  "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb" \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example" \
  "$MANIFEST_REPLACED_PARENT_LOCK_LOG"
pass "archive-manifest generation binds inherited authority to the exact parent lock inode"

printf '\377' > "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/raw/response.md"
binary_artifact_digest="$(ruby -rdigest -e 'puts Digest::SHA256.file(ARGV.fetch(0)).hexdigest' \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/raw/response.md")"
printf '%s\n' \
  'sha256                                                            bytes  path' \
  "$binary_artifact_digest  1  response.md" \
  > "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/raw/artifact-manifest.txt"
ruby "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb" \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example" >/dev/null
ruby "$EVIDENCE_FIXTURE/scripts/validate-evidence.rb" >/dev/null ||
  fail "evidence validator treated a binary artifact as a UTF-8 control file"
printf '%s' 'artifact' > "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/raw/response.md"
printf '%s\n' \
  'sha256                                                            bytes  path' \
  "$artifact_digest  8  response.md" \
  > "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/raw/artifact-manifest.txt"
ruby "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb" \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example" >/dev/null
pass "evidence validation preserves arbitrary binary artifact bytes"

cp "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/archive-manifest.txt" "$EVIDENCE_FIXTURE/archive-manifest.before"
printf '%s\n' 'changed before a later target failure' >> "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/summary.md"
mkdir -p "$EVIDENCE_FIXTURE/evals/runs/2026-01-02-invalid/raw"
mkfifo "$EVIDENCE_FIXTURE/evals/runs/2026-01-02-invalid/raw/special.fifo"
if ruby "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb" \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example" \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-02-invalid" > "$TEST_ROOT/archive-multi-target.log" 2>&1; then
  fail "archive-manifest generator accepted a later invalid target"
fi
cmp -s \
  "$EVIDENCE_FIXTURE/archive-manifest.before" \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/archive-manifest.txt" ||
  fail "archive-manifest generator partially updated an earlier target"
printf '%s\n' '# Summary' > "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/summary.md"
rm -f "$EVIDENCE_FIXTURE/evals/runs/2026-01-02-invalid/raw/special.fifo"
rmdir "$EVIDENCE_FIXTURE/evals/runs/2026-01-02-invalid/raw" "$EVIDENCE_FIXTURE/evals/runs/2026-01-02-invalid"
pass "archive-manifest generation preflights every target before writing"

MANIFEST_CONCURRENT_ARCHIVE="$EVIDENCE_FIXTURE/evals/runs/2026-01-02-concurrent"
cp -R "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example" "$MANIFEST_CONCURRENT_ARCHIVE"
cp "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/archive-manifest.txt" \
  "$EVIDENCE_FIXTURE/archive-manifest.concurrent.before"
cp "$MANIFEST_CONCURRENT_ARCHIVE/archive-manifest.txt" \
  "$EVIDENCE_FIXTURE/archive-manifest.concurrent-second.before"
MANIFEST_PREFLIGHT_INJECTION="$TEST_ROOT/manifest-preflight-injection.rb"
printf '%s\n' \
  'target = ENV.fetch("ZSTACK_MANIFEST_MUTATION_TARGET")' \
  'returns = 0' \
  'trace = TracePoint.new(:return) do |event|' \
  '  next unless event.method_id == :manifest_content' \
  '  returns += 1' \
  '  next unless returns == 1' \
  '  File.open(target, "ab") { |file| file.write("changed after first preflight\n") }' \
  'end' \
  'trace.enable' \
  'Object.const_set(:ZSTACK_MANIFEST_PREFLIGHT_TRACE, trace)' \
  > "$MANIFEST_PREFLIGHT_INJECTION"
if RUBYOPT="-r$MANIFEST_PREFLIGHT_INJECTION" \
  ZSTACK_MANIFEST_MUTATION_TARGET="$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/summary.md" \
  ruby "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb" \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example" \
  "$MANIFEST_CONCURRENT_ARCHIVE" > "$TEST_ROOT/archive-manifest-concurrent-source.log" 2>&1; then
  fail "archive-manifest generator accepted content changed after its first preflight"
fi
grep -q "archive contents or manifest target changed after preflight" \
  "$TEST_ROOT/archive-manifest-concurrent-source.log" ||
  fail "archive-manifest generator reported the wrong concurrent-source failure"
cmp -s \
  "$EVIDENCE_FIXTURE/archive-manifest.concurrent.before" \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/archive-manifest.txt" ||
  fail "archive-manifest generator wrote a stale manifest after concurrent source change"
cmp -s \
  "$EVIDENCE_FIXTURE/archive-manifest.concurrent-second.before" \
  "$MANIFEST_CONCURRENT_ARCHIVE/archive-manifest.txt" ||
  fail "archive-manifest generator partially updated a later target after concurrent source change"
printf '%s\n' '# Summary' > "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/summary.md"
rm -rf "$MANIFEST_CONCURRENT_ARCHIVE"
pass "archive-manifest generation rechecks every source before publishing"

MANIFEST_ROLLBACK_FIRST="$EVIDENCE_FIXTURE/evals/runs/2026-01-03-rollback-first"
MANIFEST_ROLLBACK_SECOND="$EVIDENCE_FIXTURE/evals/runs/2026-01-04-rollback-second"
cp -R "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example" "$MANIFEST_ROLLBACK_FIRST"
cp -R "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example" "$MANIFEST_ROLLBACK_SECOND"
printf '%s\n' 'first target needs a new manifest' >> "$MANIFEST_ROLLBACK_FIRST/summary.md"
printf '%s\n' 'second target needs a new manifest' >> "$MANIFEST_ROLLBACK_SECOND/summary.md"
cp "$MANIFEST_ROLLBACK_FIRST/archive-manifest.txt" "$EVIDENCE_FIXTURE/archive-manifest.rollback-first.before"
MANIFEST_ROLLBACK_INJECTION="$TEST_ROOT/manifest-rollback-injection.rb"
printf '%s\n' \
  'target = ENV.fetch("ZSTACK_MANIFEST_REPLACEMENT_TARGET")' \
  'returns = 0' \
  'trace = TracePoint.new(:return) do |event|' \
  '  next unless event.method_id == :write_atomically' \
  '  returns += 1' \
  '  next unless returns == 1' \
  '  File.rename(target, "#{target}.original")' \
  '  File.write(target, "replacement must survive\n")' \
  'end' \
  'trace.enable' \
  'Object.const_set(:ZSTACK_MANIFEST_ROLLBACK_TRACE, trace)' \
  > "$MANIFEST_ROLLBACK_INJECTION"
if RUBYOPT="-r$MANIFEST_ROLLBACK_INJECTION" \
  ZSTACK_MANIFEST_REPLACEMENT_TARGET="$MANIFEST_ROLLBACK_SECOND/archive-manifest.txt" \
  ruby "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb" \
  "$MANIFEST_ROLLBACK_FIRST" "$MANIFEST_ROLLBACK_SECOND" \
  > "$TEST_ROOT/archive-manifest-late-failure.log" 2>&1; then
  fail "archive-manifest generator accepted a target replaced during multi-target publication"
fi
grep -q "manifest target changed after preflight" "$TEST_ROOT/archive-manifest-late-failure.log" ||
  fail "archive-manifest generator reported the wrong late-target failure"
cmp -s "$EVIDENCE_FIXTURE/archive-manifest.rollback-first.before" \
  "$MANIFEST_ROLLBACK_FIRST/archive-manifest.txt" ||
  fail "archive-manifest generator did not roll back an earlier published target"
grep -qx "replacement must survive" "$MANIFEST_ROLLBACK_SECOND/archive-manifest.txt" ||
  fail "archive-manifest generator changed a concurrently replaced later target"
rm -rf "$MANIFEST_ROLLBACK_FIRST" "$MANIFEST_ROLLBACK_SECOND"
pass "archive-manifest generation rolls back earlier targets after a late publish failure"

MANIFEST_POSTCHECK_FIRST="$EVIDENCE_FIXTURE/evals/runs/2026-01-05-postcheck-first"
MANIFEST_POSTCHECK_SECOND="$EVIDENCE_FIXTURE/evals/runs/2026-01-06-postcheck-second"
cp -R "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example" "$MANIFEST_POSTCHECK_FIRST"
cp -R "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example" "$MANIFEST_POSTCHECK_SECOND"
printf '%s\n' 'first target needs post-publish verification' >> "$MANIFEST_POSTCHECK_FIRST/summary.md"
printf '%s\n' 'second target needs post-publish verification' >> "$MANIFEST_POSTCHECK_SECOND/summary.md"
cp "$MANIFEST_POSTCHECK_SECOND/archive-manifest.txt" "$EVIDENCE_FIXTURE/archive-manifest.postcheck-second.before"
MANIFEST_POSTCHECK_INJECTION="$TEST_ROOT/manifest-postcheck-injection.rb"
printf '%s\n' \
  'target = ENV.fetch("ZSTACK_MANIFEST_POSTCHECK_TARGET")' \
  'returns = 0' \
  'trace = TracePoint.new(:return) do |event|' \
  '  next unless event.method_id == :write_atomically' \
  '  returns += 1' \
  '  next unless returns == 2' \
  '  File.rename(target, "#{target}.published")' \
  '  File.write(target, "post-publish replacement must survive\n")' \
  'end' \
  'trace.enable' \
  'Object.const_set(:ZSTACK_MANIFEST_POSTCHECK_TRACE, trace)' \
  > "$MANIFEST_POSTCHECK_INJECTION"
if RUBYOPT="-r$MANIFEST_POSTCHECK_INJECTION" \
  ZSTACK_MANIFEST_POSTCHECK_TARGET="$MANIFEST_POSTCHECK_FIRST/archive-manifest.txt" \
  ruby "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb" \
  "$MANIFEST_POSTCHECK_FIRST" "$MANIFEST_POSTCHECK_SECOND" \
  > "$TEST_ROOT/archive-manifest-postcheck.log" 2>&1; then
  fail "archive-manifest generator missed an early target replaced after the final write"
fi
grep -q "manifest publication could not be verified" "$TEST_ROOT/archive-manifest-postcheck.log" ||
  fail "archive-manifest generator reported the wrong post-publish verification failure"
grep -qx "post-publish replacement must survive" "$MANIFEST_POSTCHECK_FIRST/archive-manifest.txt" ||
  fail "archive-manifest generator removed a post-publish replacement"
cmp -s "$EVIDENCE_FIXTURE/archive-manifest.postcheck-second.before" \
  "$MANIFEST_POSTCHECK_SECOND/archive-manifest.txt" ||
  fail "archive-manifest generator did not roll back an unchanged later publication"
rm -rf "$MANIFEST_POSTCHECK_FIRST" "$MANIFEST_POSTCHECK_SECOND"
pass "archive-manifest generation verifies every published target before success"

mv \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/archive-manifest.txt" \
  "$EVIDENCE_FIXTURE/archive-manifest.saved"
mkfifo "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/archive-manifest.txt"
if ruby "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb" \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example" > "$TEST_ROOT/archive-manifest-target.log" 2>&1; then
  fail "archive-manifest generator replaced a non-regular manifest target"
fi
[[ -p "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/archive-manifest.txt" ]] ||
  fail "archive-manifest generator changed a non-regular manifest target"
rm -f "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/archive-manifest.txt"
mv \
  "$EVIDENCE_FIXTURE/archive-manifest.saved" \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/archive-manifest.txt"
pass "archive-manifest generation preserves non-regular manifest targets"

mv "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/summary.md" \
  "$EVIDENCE_FIXTURE/summary-hardlink-source.md"
ln "$EVIDENCE_FIXTURE/summary-hardlink-source.md" \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/summary.md"
if ruby "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb" \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example" > "$TEST_ROOT/evidence-generator-hardlink.log" 2>&1; then
  fail "archive-manifest generator accepted a multiply linked archive file"
fi
grep -q "one hard link" "$TEST_ROOT/evidence-generator-hardlink.log" ||
  fail "archive-manifest generator reported the wrong hardlink failure"
if ruby "$EVIDENCE_FIXTURE/scripts/validate-evidence.rb" > "$TEST_ROOT/evidence-validator-hardlink.log" 2>&1; then
  fail "evidence validator accepted a multiply linked archive file"
fi
grep -q "one hard link" "$TEST_ROOT/evidence-validator-hardlink.log" ||
  fail "evidence validator reported the wrong hardlink failure"
rm -f "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/summary.md"
mv "$EVIDENCE_FIXTURE/summary-hardlink-source.md" \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/summary.md"
ruby "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb" \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example" >/dev/null
pass "evidence publication rejects multiply linked archive files"

printf '%s\n' 'must not be ignored' > "$EVIDENCE_FIXTURE/evals/runs/.unvalidated-evidence"
if ruby "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb" --check > "$TEST_ROOT/evidence-generator-top-level-file.log" 2>&1; then
  fail "archive-manifest check ignored a hidden top-level entry"
fi
grep -q "top-level entry must be a real archive directory" "$TEST_ROOT/evidence-generator-top-level-file.log" ||
  fail "archive-manifest check reported the wrong hidden-entry failure"
if ruby "$EVIDENCE_FIXTURE/scripts/validate-evidence.rb" > "$TEST_ROOT/evidence-top-level-file.log" 2>&1; then
  fail "evidence validator ignored a top-level non-directory entry"
fi
grep -q "top-level entry must be a real archive directory" "$TEST_ROOT/evidence-top-level-file.log" ||
  fail "evidence validator reported the wrong top-level file failure"
rm -f "$EVIDENCE_FIXTURE/evals/runs/.unvalidated-evidence"

mkdir "$EVIDENCE_FIXTURE/evals/runs/.partial-archive"
if ruby "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb" --check > "$TEST_ROOT/evidence-generator-hidden-directory.log" 2>&1; then
  fail "archive-manifest check accepted a non-canonical hidden archive directory"
fi
grep -q "archive directory name must use a valid ISO calendar date" "$TEST_ROOT/evidence-generator-hidden-directory.log" ||
  fail "archive-manifest check reported the wrong hidden-directory failure"
if ruby "$EVIDENCE_FIXTURE/scripts/validate-evidence.rb" > "$TEST_ROOT/evidence-hidden-directory.log" 2>&1; then
  fail "evidence validator accepted a non-canonical hidden archive directory"
fi
grep -q "archive directory name must use a valid ISO calendar date" "$TEST_ROOT/evidence-hidden-directory.log" ||
  fail "evidence validator reported the wrong hidden-directory failure"
rmdir "$EVIDENCE_FIXTURE/evals/runs/.partial-archive"

mkdir "$EVIDENCE_FIXTURE/evals/runs/2026-99-99-invalid"
if ruby "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb" --check > "$TEST_ROOT/evidence-generator-invalid-date.log" 2>&1; then
  fail "archive-manifest check accepted an impossible archive date"
fi
grep -q "valid ISO calendar date" "$TEST_ROOT/evidence-generator-invalid-date.log" ||
  fail "archive-manifest check reported the wrong invalid-date failure"
if ruby "$EVIDENCE_FIXTURE/scripts/validate-evidence.rb" > "$TEST_ROOT/evidence-invalid-directory-date.log" 2>&1; then
  fail "evidence validator accepted an impossible archive directory date"
fi
grep -q "valid ISO calendar date" "$TEST_ROOT/evidence-invalid-directory-date.log" ||
  fail "evidence validator reported the wrong invalid directory-date failure"
if ruby "$EVIDENCE_FIXTURE/scripts/validate-evidence.rb" \
  --candidate "$EVIDENCE_FIXTURE/evals/runs/2026-99-99-invalid" \
  --candidate-name 2026-99-99-invalid > "$TEST_ROOT/evidence-invalid-candidate-date.log" 2>&1; then
  fail "evidence validator accepted an impossible candidate date"
fi
grep -q "valid ISO calendar date" "$TEST_ROOT/evidence-invalid-candidate-date.log" ||
  fail "evidence validator reported the wrong invalid candidate-date failure"
rmdir "$EVIDENCE_FIXTURE/evals/runs/2026-99-99-invalid"

sed 's/"archiveDate":"2026-01-01"/"archiveDate":"2026-02-30"/' \
  "$EVIDENCE_FIXTURE/run.valid.json" > "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/run.json"
ruby "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb" \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example" >/dev/null
if ruby "$EVIDENCE_FIXTURE/scripts/validate-evidence.rb" > "$TEST_ROOT/evidence-invalid-metadata-date.log" 2>&1; then
  fail "evidence validator accepted an impossible archiveDate"
fi
grep -q "archiveDate must be a valid ISO calendar date" "$TEST_ROOT/evidence-invalid-metadata-date.log" ||
  fail "evidence validator reported the wrong invalid archiveDate failure"
cp "$EVIDENCE_FIXTURE/run.valid.json" "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/run.json"
ruby "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb" \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example" >/dev/null
pass "evidence archive dates require real ISO calendar dates"

EVIDENCE_OUTSIDE_ARCHIVE="$EVIDENCE_FIXTURE/outside-archive"
mkdir -p "$EVIDENCE_OUTSIDE_ARCHIVE"
mkfifo "$EVIDENCE_OUTSIDE_ARCHIVE/special.fifo"
ln -s "$EVIDENCE_OUTSIDE_ARCHIVE" "$EVIDENCE_FIXTURE/evals/runs/2026-01-02-linked"
if ruby "$EVIDENCE_FIXTURE/scripts/validate-evidence.rb" > "$TEST_ROOT/evidence-top-level-link.log" 2>&1; then
  fail "evidence validator accepted a linked top-level archive"
fi
if ruby "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb" --check > "$TEST_ROOT/evidence-generator-top-level-link.log" 2>&1; then
  fail "archive-manifest check accepted a linked top-level archive"
fi
grep -q "top-level entry must be a real archive directory" "$TEST_ROOT/evidence-generator-top-level-link.log" ||
  fail "archive-manifest check reported the wrong top-level link failure"
grep -q "top-level entry must be a real archive directory" "$TEST_ROOT/evidence-top-level-link.log" ||
  fail "evidence validator reported the wrong top-level link failure"
if grep -q "special.fifo" "$TEST_ROOT/evidence-top-level-link.log"; then
  fail "evidence validator traversed a rejected top-level link"
fi
rm -f "$EVIDENCE_FIXTURE/evals/runs/2026-01-02-linked" "$EVIDENCE_OUTSIDE_ARCHIVE/special.fifo"
rmdir "$EVIDENCE_OUTSIDE_ARCHIVE"
pass "evidence validation rejects and does not traverse non-archive top-level entries"

ruby -rjson -e '
  path = ARGV.fetch(0)
  data = JSON.parse(File.read(path))
  run = data.fetch("runs").fetch(0)
  run["exitStatus"] = -1
  run["elapsedSeconds"] = "ELAPSED_INFINITY"
  run["totalCostUsd"] = "COST_INFINITY"
  run["tokenUsage"] = { "inputTokens" => "TOKEN_INFINITY" }
  content = JSON.generate(data)
    .sub(%q{"ELAPSED_INFINITY"}, "1e309")
    .sub(%q{"COST_INFINITY"}, "1e309")
    .sub(%q{"TOKEN_INFINITY"}, "1e309")
  File.write(path, content + "\n")
' "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/run.json"
if ruby "$EVIDENCE_FIXTURE/scripts/validate-evidence.rb" > "$TEST_ROOT/evidence-run-field-types.log" 2>&1; then
  fail "evidence validator accepted invalid optional run metadata"
fi
grep -q "exitStatus must be a non-negative integer or null" "$TEST_ROOT/evidence-run-field-types.log" ||
  fail "evidence validator omitted the invalid exit-status failure"
grep -q "elapsedSeconds must be a finite non-negative number or null" "$TEST_ROOT/evidence-run-field-types.log" ||
  fail "evidence validator omitted the invalid elapsed-time failure"
grep -q "totalCostUsd must be a finite non-negative number or null" "$TEST_ROOT/evidence-run-field-types.log" ||
  fail "evidence validator omitted the invalid cost failure"
grep -q "tokenUsage must be an object with finite non-negative numbers or null" "$TEST_ROOT/evidence-run-field-types.log" ||
  fail "evidence validator omitted the invalid token-usage failure"
cp "$EVIDENCE_FIXTURE/run.valid.json" "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/run.json"
pass "evidence metadata validates optional execution field types"

ruby -e '
  path = ARGV.fetch(0)
  content = File.read(path)
  replacement = content.sub(%q{"schemaVersion":2}, %q{"schemaVersion":1,"schemaVersion":2})
  abort "duplicate metadata fixture did not change" if replacement == content
  File.write(path, replacement)
' "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/run.json"
ruby "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb" \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example" >/dev/null
if ruby "$EVIDENCE_FIXTURE/scripts/validate-evidence.rb" > "$TEST_ROOT/evidence-duplicate-metadata.log" 2>&1; then
  fail "evidence validator accepted ambiguous duplicate metadata"
fi
grep -q "duplicate JSON object key" "$TEST_ROOT/evidence-duplicate-metadata.log" ||
  fail "evidence validator reported the wrong duplicate-key failure"
cp "$EVIDENCE_FIXTURE/run.valid.json" "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/run.json"
ruby "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb" \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example" >/dev/null
pass "strict JSON inputs reject duplicate object keys at every evidence boundary"

printf '%s\n' \
  'sha256                                                            bytes  path' \
  'Unarchived entries are inventory-only: omitted.md' \
  "$artifact_digest  8  response.md" \
  "$artifact_digest  8  omitted.md" \
  "$artifact_digest  8  omitted.md" > "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/raw/artifact-manifest.txt"
if ruby "$EVIDENCE_FIXTURE/scripts/validate-evidence.rb" > "$TEST_ROOT/evidence-inventory-duplicate.log" 2>&1; then
  fail "evidence validator accepted a duplicate inventory-only artifact"
fi
grep -q "duplicate artifact path: omitted.md" "$TEST_ROOT/evidence-inventory-duplicate.log" ||
  fail "evidence validator reported the wrong duplicate inventory-only failure"
printf '%s\n' \
  'sha256                                                            bytes  path' \
  'Unarchived entries are inventory-only: omitted.md, omitted.md' \
  "$artifact_digest  8  response.md" \
  "$artifact_digest  8  omitted.md" > "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/raw/artifact-manifest.txt"
if ruby "$EVIDENCE_FIXTURE/scripts/validate-evidence.rb" > "$TEST_ROOT/evidence-inventory-declaration-duplicate.log" 2>&1; then
  fail "evidence validator accepted a duplicate inventory-only declaration"
fi
grep -q "inventory-only declaration contains duplicate paths" "$TEST_ROOT/evidence-inventory-declaration-duplicate.log" ||
  fail "evidence validator reported the wrong duplicate inventory declaration failure"
printf '%s\n' \
  'sha256                                                            bytes  path' \
  'Unarchived entries are inventory-only: omitted.md' \
  'Unarchived entries are inventory-only: second-omitted.md' \
  "$artifact_digest  8  response.md" \
  "$artifact_digest  8  omitted.md" \
  "$artifact_digest  8  second-omitted.md" > "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/raw/artifact-manifest.txt"
if ruby "$EVIDENCE_FIXTURE/scripts/validate-evidence.rb" > "$TEST_ROOT/evidence-inventory-declaration-lines.log" 2>&1; then
  fail "evidence validator accepted multiple inventory-only declaration lines"
fi
grep -q "inventory-only entries must use at most one declaration line" "$TEST_ROOT/evidence-inventory-declaration-lines.log" ||
  fail "evidence validator reported the wrong inventory declaration-line failure"
printf '%s\n' \
  'sha256                                                            bytes  path' \
  "$artifact_digest  8  response.md" > "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/raw/artifact-manifest.txt"
ruby "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb" \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example" >/dev/null
pass "evidence manifests reject duplicate retained and inventory-only paths or declarations"

dd if=/dev/zero \
  of="$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/oversized.bin" \
  bs=$((2 * 1024 * 1024 + 1)) count=1 2>/dev/null
if ruby "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb" \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example" > "$TEST_ROOT/archive-generator-file-limit.log" 2>&1; then
  fail "archive-manifest generator accepted an oversized archive file"
fi
grep -q "archive file is 2097153 bytes; maximum is 2097152" "$TEST_ROOT/archive-generator-file-limit.log" ||
  fail "archive-manifest generator reported the wrong per-file limit failure"
if ruby "$EVIDENCE_FIXTURE/scripts/validate-evidence.rb" > "$TEST_ROOT/archive-file-limit.log" 2>&1; then
  fail "evidence validator accepted an oversized archive file"
fi
grep -q "archive file is 2097153 bytes; maximum is 2097152" "$TEST_ROOT/archive-file-limit.log" ||
  fail "evidence validator reported the wrong per-file limit failure"
rm -f "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/oversized.bin"
ruby "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb" \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example" >/dev/null
pass "evidence archives reject files above the publication limit"

ARCHIVE_COUNT_OVERFLOW="$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/count-overflow"
mkdir -p "$ARCHIVE_COUNT_OVERFLOW"
for ((archive_index = 1; archive_index <= 501; archive_index++)); do
  : > "$ARCHIVE_COUNT_OVERFLOW/file-$archive_index.txt"
done
if ruby "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb" \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example" > "$TEST_ROOT/archive-generator-count-limit.log" 2>&1; then
  fail "archive-manifest generator accepted too many archive files"
fi
grep -Eq "archive would have [0-9]+ regular files.*maximum is 500" "$TEST_ROOT/archive-generator-count-limit.log" ||
  fail "archive-manifest generator reported the wrong file-count limit failure"
if ruby "$EVIDENCE_FIXTURE/scripts/validate-evidence.rb" > "$TEST_ROOT/archive-count-limit.log" 2>&1; then
  fail "evidence validator accepted too many archive files"
fi
grep -Eq "archive has [0-9]+ files; maximum is 500" "$TEST_ROOT/archive-count-limit.log" ||
  fail "evidence validator reported the wrong file-count limit failure"
rm -rf "$ARCHIVE_COUNT_OVERFLOW"
ruby "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb" \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example" >/dev/null
pass "evidence archives reject file counts above the publication limit"

ARCHIVE_ENTRY_OVERFLOW="$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/entry-overflow"
mkdir -p "$ARCHIVE_ENTRY_OVERFLOW"
ruby -e '
  root = ARGV.fetch(0)
  2_001.times { |index| Dir.mkdir(File.join(root, format("%04d", index))) }
' "$ARCHIVE_ENTRY_OVERFLOW"
if ruby "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb" \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example" > "$TEST_ROOT/archive-generator-entry-limit.log" 2>&1; then
  fail "archive-manifest generator accepted too many archive tree entries"
fi
grep -q "archive has more than 2000 tree entries" "$TEST_ROOT/archive-generator-entry-limit.log" ||
  fail "archive-manifest generator reported the wrong tree-entry limit failure"
if ruby "$EVIDENCE_FIXTURE/scripts/validate-evidence.rb" > "$TEST_ROOT/archive-entry-limit.log" 2>&1; then
  fail "evidence validator accepted too many archive tree entries"
fi
grep -q "archive has more than 2000 tree entries" "$TEST_ROOT/archive-entry-limit.log" ||
  fail "evidence validator reported the wrong tree-entry limit failure"
rm -rf "$ARCHIVE_ENTRY_OVERFLOW"
ruby "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb" \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example" >/dev/null
pass "evidence archives reject empty-directory entry exhaustion"

ARCHIVE_SET_OVERFLOW_PREFIX="$EVIDENCE_FIXTURE/evals/runs/2026-02-01-overflow-"
ruby -e '
  prefix = ARGV.fetch(0)
  1_000.times { |index| Dir.mkdir("#{prefix}#{format("%04d", index)}") }
' "$ARCHIVE_SET_OVERFLOW_PREFIX"
if ruby "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb" --check \
  > "$TEST_ROOT/archive-generator-set-limit.log" 2>&1; then
  fail "archive-manifest generator accepted too many archive directories"
fi
grep -q "evals/runs has more than 1000 top-level entries" "$TEST_ROOT/archive-generator-set-limit.log" ||
  fail "archive-manifest generator reported the wrong archive-set limit failure"
if ruby "$EVIDENCE_FIXTURE/scripts/validate-evidence.rb" > "$TEST_ROOT/archive-set-limit.log" 2>&1; then
  fail "evidence validator accepted too many archive directories"
fi
grep -q "evals/runs has more than 1000 top-level entries" "$TEST_ROOT/archive-set-limit.log" ||
  fail "evidence validator reported the wrong archive-set limit failure"
ruby -e '
  prefix = ARGV.fetch(0)
  Dir.glob("#{prefix}*").each { |path| Dir.rmdir(path) }
' "$ARCHIVE_SET_OVERFLOW_PREFIX"
pass "evidence tools bound the archive collection before traversal"

EVIDENCE_LIMITS_PATH="$EVIDENCE_FIXTURE/scripts/lib/eval_limits.rb"
cp "$EVIDENCE_LIMITS_PATH" "$EVIDENCE_FIXTURE/eval_limits.before-global-tree-test.rb"
ruby -e '
  path = ARGV.fetch(0)
  content = File.read(path)
  replacement = content.sub("MAX_EVIDENCE_TREE_ENTRIES = 100_000", "MAX_EVIDENCE_TREE_ENTRIES = 5")
  abort "global evidence-tree fixture did not change" if replacement == content
  File.write(path, replacement)
' "$EVIDENCE_LIMITS_PATH"
if ruby "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb" \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example" > "$TEST_ROOT/archive-generator-global-tree-limit.log" 2>&1; then
  fail "archive-manifest generator accepted an oversized evidence collection"
fi
grep -q "evidence tree has more than 5 entries" "$TEST_ROOT/archive-generator-global-tree-limit.log" ||
  fail "archive-manifest generator reported the wrong global tree limit"
if ruby "$EVIDENCE_FIXTURE/scripts/validate-evidence.rb" > "$TEST_ROOT/archive-validator-global-tree-limit.log" 2>&1; then
  fail "evidence validator accepted an oversized evidence collection"
fi
grep -q "evidence tree has more than 5 entries" "$TEST_ROOT/archive-validator-global-tree-limit.log" ||
  fail "evidence validator reported the wrong global tree limit"
if ruby -I "$ROOT/scripts/lib" -r eval_evidence_tree -e '
  Zstack::EvalLimits.send(:remove_const, :MAX_EVIDENCE_TREE_ENTRIES)
  Zstack::EvalLimits.const_set(:MAX_EVIDENCE_TREE_ENTRIES, 5)
  Zstack::EvalEvidenceTree.capture(ARGV.fetch(0))
' "$EVIDENCE_FIXTURE/evals/runs" > "$TEST_ROOT/archive-coverage-global-tree-limit.log" 2>&1; then
  fail "evidence snapshot accepted an oversized evidence collection"
fi
grep -q "evidence tree has more than 5 entries" "$TEST_ROOT/archive-coverage-global-tree-limit.log" ||
  fail "evidence snapshot reported the wrong global tree limit"
mv "$EVIDENCE_FIXTURE/eval_limits.before-global-tree-test.rb" "$EVIDENCE_LIMITS_PATH"
pass "evidence tools enforce one whole-collection tree budget"

ARCHIVE_TOTAL_OVERFLOW="$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/total-overflow"
mkdir -p "$ARCHIVE_TOTAL_OVERFLOW"
for archive_index in 1 2 3 4 5; do
  dd if=/dev/zero \
    of="$ARCHIVE_TOTAL_OVERFLOW/file-$archive_index.bin" \
    bs=$((2 * 1024 * 1024)) count=1 2>/dev/null
done
if ruby "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb" \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example" > "$TEST_ROOT/archive-generator-total-limit.log" 2>&1; then
  fail "archive-manifest generator accepted an oversized archive"
fi
grep -Eq "archive input is [0-9]+ bytes.*maximum published archive is 10485760" "$TEST_ROOT/archive-generator-total-limit.log" ||
  fail "archive-manifest generator reported the wrong total-size limit failure"
if ruby "$EVIDENCE_FIXTURE/scripts/validate-evidence.rb" > "$TEST_ROOT/archive-total-limit.log" 2>&1; then
  fail "evidence validator accepted an oversized archive"
fi
grep -Eq "archive is [0-9]+ bytes; maximum is 10485760" "$TEST_ROOT/archive-total-limit.log" ||
  fail "evidence validator reported the wrong total-size limit failure"
rm -rf "$ARCHIVE_TOTAL_OVERFLOW"
ruby "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb" \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example" >/dev/null
pass "evidence archives reject total bytes above the publication limit"

printf '%s\n' 'changed summary' >> "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/summary.md"
if ruby "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb" --check \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example" > "$TEST_ROOT/archive-stale.log" 2>&1; then
  fail "archive-manifest check accepted changed control metadata"
fi
grep -q "STALE:" "$TEST_ROOT/archive-stale.log" || fail "archive-manifest check reported the wrong stale failure"
if ruby "$EVIDENCE_FIXTURE/scripts/validate-evidence.rb" > "$TEST_ROOT/archive-summary-hash.log" 2>&1; then
  fail "evidence validator accepted changed summary metadata"
fi
grep -q "SHA-256 mismatch for summary.md" "$TEST_ROOT/archive-summary-hash.log" || fail "evidence validator reported the wrong summary-hash failure"
printf '%s\n' '# Summary' > "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/summary.md"
printf '%s\n' 'unlisted control file' > "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/notes.md"
if ruby "$EVIDENCE_FIXTURE/scripts/validate-evidence.rb" > "$TEST_ROOT/archive-coverage.log" 2>&1; then
  fail "evidence validator accepted an unlisted archive control file"
fi
grep -q "archive file is not covered: notes.md" "$TEST_ROOT/archive-coverage.log" || fail "evidence validator reported the wrong archive-coverage failure"
rm -f "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/notes.md"
if ruby "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb" "$EVIDENCE_FIXTURE" > "$TEST_ROOT/archive-target.log" 2>&1; then
  fail "archive-manifest generator accepted a target outside evals/runs"
fi
grep -q "target must be one archive directory" "$TEST_ROOT/archive-target.log" || fail "archive-manifest generator reported the wrong target-boundary failure"
printf '%s\n' 'ambiguous path' > "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/ leading-space.md"
if ruby "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb" \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example" > "$TEST_ROOT/archive-path.log" 2>&1; then
  fail "archive-manifest generator accepted a non-canonical filename"
fi
grep -q "path is not canonical and portable" "$TEST_ROOT/archive-path.log" || fail "archive-manifest generator reported the wrong path failure"
rm -f "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/ leading-space.md"
control_name=$'control\ncharacter.md'
printf '%s\n' 'ambiguous path' > "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/$control_name"
if ruby "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb" \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example" > "$TEST_ROOT/archive-control-path.log" 2>&1; then
  fail "archive-manifest generator accepted a control character in a filename"
fi
grep -q "path is not canonical and portable" "$TEST_ROOT/archive-control-path.log" || fail "archive-manifest generator reported the wrong control-path failure"
rm -f "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/$control_name"
SPECIAL_ARCHIVE_ENTRY="$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/raw/special.fifo"
mkfifo "$SPECIAL_ARCHIVE_ENTRY"
if ruby "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb" \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example" > "$TEST_ROOT/archive-special-generator.log" 2>&1; then
  fail "archive-manifest generator accepted a non-regular archive entry"
fi
grep -q "archive content must be a regular file or directory" "$TEST_ROOT/archive-special-generator.log" ||
  fail "archive-manifest generator reported the wrong special-entry failure"
if ruby "$EVIDENCE_FIXTURE/scripts/validate-evidence.rb" > "$TEST_ROOT/archive-special-validator.log" 2>&1; then
  fail "evidence validator accepted a non-regular archive entry"
fi
grep -q "archive content must be a regular file or directory" "$TEST_ROOT/archive-special-validator.log" ||
  fail "evidence validator reported the wrong special-entry failure"
rm -f "$SPECIAL_ARCHIVE_ENTRY"
pass "evidence tools reject non-regular archive entries"

VALIDATION_MUTATION_TARGET="$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/summary.md"
mv "$EVIDENCE_FIXTURE/scripts/lib/eval_input_file.rb" \
  "$EVIDENCE_FIXTURE/scripts/lib/eval_input_file_real.rb"
printf '%s\n' \
  '# frozen_string_literal: true' \
  'require_relative "eval_input_file_real"' \
  'module Zstack' \
  '  module EvalInputFile' \
  '    class << self' \
  '      alias_method :zstack_original_read_for_tree_state_test, :read' \
  '      def read(path, **options)' \
  '        content = zstack_original_read_for_tree_state_test(path, **options)' \
  '        target = File.expand_path(ENV.fetch("VALIDATION_MUTATION_TARGET"))' \
  '        if File.realpath(path) == File.realpath(target) && !instance_variable_defined?(:@zstack_tree_state_mutated)' \
  '          instance_variable_set(:@zstack_tree_state_mutated, true)' \
  '          File.write(target, "# Summary changed after its verified read\n")' \
  '        end' \
  '        content' \
  '      end' \
  '    end' \
  '  end' \
  'end' > "$EVIDENCE_FIXTURE/scripts/lib/eval_input_file.rb"
VALIDATION_MUTATION_TARGET="$VALIDATION_MUTATION_TARGET" \
ruby "$EVIDENCE_FIXTURE/scripts/validate-evidence.rb" \
  > "$TEST_ROOT/evidence-late-mutation.log" 2>&1 &&
  fail "evidence validator accepted an archive changed after a verified read"
grep -q "archive changed while evidence validation was running" "$TEST_ROOT/evidence-late-mutation.log" ||
  fail "evidence validator reported the wrong late-mutation failure"
mv "$EVIDENCE_FIXTURE/scripts/lib/eval_input_file_real.rb" \
  "$EVIDENCE_FIXTURE/scripts/lib/eval_input_file.rb"
printf '%s\n' '# Summary' > "$VALIDATION_MUTATION_TARGET"
pass "evidence validation binds all checks to one unchanged archive tree"

sed 's/"response.md"/".\/response.md"/' \
  "$EVIDENCE_FIXTURE/run.valid.json" > "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/run.json"
if ruby "$EVIDENCE_FIXTURE/scripts/validate-evidence.rb" > "$TEST_ROOT/evidence-metadata-path.log" 2>&1; then
  fail "evidence validator accepted a non-canonical metadata artifact path"
fi
grep -q "artifacts contains an unsafe or invalid path" "$TEST_ROOT/evidence-metadata-path.log" || fail "evidence validator reported the wrong metadata-path failure"
cp "$EVIDENCE_FIXTURE/run.valid.json" "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/run.json"
sed 's/  response.md$/  .\/response.md/' \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/raw/artifact-manifest.txt" > "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/raw/artifact-manifest.next.txt"
mv "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/raw/artifact-manifest.next.txt" "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/raw/artifact-manifest.txt"
if ruby "$EVIDENCE_FIXTURE/scripts/validate-evidence.rb" > "$TEST_ROOT/evidence-raw-path.log" 2>&1; then
  fail "evidence validator accepted a non-canonical raw-manifest path"
fi
grep -q "artifact path must be canonical" "$TEST_ROOT/evidence-raw-path.log" || fail "evidence validator reported the wrong raw-path failure"
printf '%s\n' \
  'sha256                                                            bytes  path' \
  "$artifact_digest  8  response.md" > "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/raw/artifact-manifest.txt"
sed 's/^[0-9a-f]\{64\}/0000000000000000000000000000000000000000000000000000000000000000/' \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/raw/artifact-manifest.txt" > "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/raw/artifact-manifest.next.txt"
mv "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/raw/artifact-manifest.next.txt" "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/raw/artifact-manifest.txt"
if ruby "$EVIDENCE_FIXTURE/scripts/validate-evidence.rb" > "$TEST_ROOT/evidence-hash.log" 2>&1; then
  fail "evidence validator accepted a mismatched artifact hash"
fi
grep -q "SHA-256 mismatch" "$TEST_ROOT/evidence-hash.log" || fail "evidence validator reported the wrong hash failure"
printf '%s\n' \
  'sha256                                                            bytes  path' \
  "$artifact_digest  8  response.md" > "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/raw/artifact-manifest.txt"
printf '%s' 'unlisted' > "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/raw/unlisted.md"
if ruby "$EVIDENCE_FIXTURE/scripts/validate-evidence.rb" > "$TEST_ROOT/evidence-coverage.log" 2>&1; then
  fail "evidence validator accepted an unlisted raw artifact"
fi
grep -q "raw artifact is not covered by a manifest" "$TEST_ROOT/evidence-coverage.log" || fail "evidence validator reported the wrong raw-coverage failure"
rm -f "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/raw/unlisted.md"
mv "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/raw/response.md" "$EVIDENCE_FIXTURE/outside-response.md"
ln -s "$EVIDENCE_FIXTURE/outside-response.md" "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/raw/response.md"
if ruby "$EVIDENCE_FIXTURE/scripts/validate-evidence.rb" > "$TEST_ROOT/evidence-symlink.log" 2>&1; then
  fail "evidence validator followed a symbolic-link artifact"
fi
grep -q "archive content must not be a symbolic link" "$TEST_ROOT/evidence-symlink.log" || fail "evidence validator reported the wrong symbolic-link failure"
rm -f "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/raw/response.md"
mv "$EVIDENCE_FIXTURE/outside-response.md" "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/raw/response.md"
sed 's/  8  response.md/  9  response.md/' \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/raw/artifact-manifest.txt" > "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/raw/artifact-manifest.next.txt"
mv "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/raw/artifact-manifest.next.txt" "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/raw/artifact-manifest.txt"
if ruby "$EVIDENCE_FIXTURE/scripts/validate-evidence.rb" > "$TEST_ROOT/evidence-bytes.log" 2>&1; then
  fail "evidence validator accepted an incorrect artifact byte count"
fi
grep -q "byte count mismatch" "$TEST_ROOT/evidence-bytes.log" || fail "evidence validator reported the wrong byte-count failure"
printf '%s\n' \
  'sha256                                                            bytes  path' \
  "$artifact_digest  8  response.md" > "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/raw/artifact-manifest.txt"
sed 's/"status":"complete","gaps":\[\]/"status":"partial","gaps":[]/' \
  "$EVIDENCE_FIXTURE/run.valid.json" > "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/run.json"
if ruby "$EVIDENCE_FIXTURE/scripts/validate-evidence.rb" > "$TEST_ROOT/evidence-provenance.log" 2>&1; then
  fail "evidence validator accepted unexplained partial provenance"
fi
grep -q "partial provenance must explain" "$TEST_ROOT/evidence-provenance.log" || fail "evidence validator reported the wrong provenance failure"
sed 's/"schemaVersion":2/"schemaVersion":99/' \
  "$EVIDENCE_FIXTURE/run.valid.json" > "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/run.next.json"
mv "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/run.next.json" "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/run.json"
if ruby "$EVIDENCE_FIXTURE/scripts/validate-evidence.rb" > "$TEST_ROOT/evidence-schema.log" 2>&1; then
  fail "evidence validator accepted an unknown metadata schema"
fi
grep -q "schemaVersion must equal 2" "$TEST_ROOT/evidence-schema.log" || fail "evidence validator reported the wrong metadata-schema failure"
sed 's/"case":"example-case"/"case":"missing-case"/' \
  "$EVIDENCE_FIXTURE/run.valid.json" > "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/run.next.json"
mv "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/run.next.json" "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/run.json"
if ruby "$EVIDENCE_FIXTURE/scripts/validate-evidence.rb" > "$TEST_ROOT/evidence-case.log" 2>&1; then
  fail "evidence validator accepted an unregistered suite case"
fi
grep -q "case must reference an id in the behavioral suite" "$TEST_ROOT/evidence-case.log" || fail "evidence validator reported the wrong suite-case failure"
cp "$EVIDENCE_FIXTURE/run.valid.json" "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/run.json"
mv "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/raw/artifact-manifest.txt" "$EVIDENCE_FIXTURE/artifact-manifest.txt"
if ruby "$EVIDENCE_FIXTURE/scripts/validate-evidence.rb" > "$TEST_ROOT/evidence-manifest.log" 2>&1; then
  fail "evidence validator accepted an archive without an artifact manifest"
fi
grep -q "missing artifact manifest" "$TEST_ROOT/evidence-manifest.log" || fail "evidence validator reported the wrong missing-manifest failure"
mv "$EVIDENCE_FIXTURE/artifact-manifest.txt" "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/raw/artifact-manifest.txt"
ruby "$EVIDENCE_FIXTURE/scripts/validate-evidence.rb" >/dev/null || fail "evidence fixture did not recover after fault injection"
printf '%s\n' '# Summary' 'Reviewed with /tmp/private-check.rb.' > "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/summary.md"
ruby "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb" \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example" >/dev/null
if ruby "$EVIDENCE_FIXTURE/scripts/validate-evidence.rb" > "$TEST_ROOT/evidence-public-review-path.log" 2>&1; then
  fail "evidence validator accepted a machine-local path in public review text"
fi
grep -q "public review text contains a machine-local path" "$TEST_ROOT/evidence-public-review-path.log" || fail "evidence validator reported the wrong public-review path failure"
printf '%s\n' '# Summary' > "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/summary.md"
ruby "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb" \
  "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example" >/dev/null
ruby "$EVIDENCE_FIXTURE/scripts/validate-evidence.rb" >/dev/null || fail "evidence fixture did not recover after public-review path injection"
pass "evidence tools check archive metadata, schema v2, raw coverage, symlinks, bytes, hashes, and public review paths"

SCAFFOLD_FIXTURE="$(copy_fixture scaffold)"
"$SCAFFOLD_FIXTURE/scripts/new-skill.sh" z-test-workflow product >/dev/null
scaffold_keys="$(awk 'NR == 1 {next} /^---$/{exit} /^[a-zA-Z0-9_-]+:/{count++} END{print count + 0}' "$SCAFFOLD_FIXTURE/skills/z-test-workflow/SKILL.md")"
[[ "$scaffold_keys" -eq 2 ]] || fail "new-skill generated non-minimal frontmatter"
[[ -f "$SCAFFOLD_FIXTURE/skills/z-test-workflow/references/quality-bar.md" ]] || fail "new-skill did not generate a quality bar"
grep -Fq 'references/quality-bar.md' "$SCAFFOLD_FIXTURE/skills/z-test-workflow/SKILL.md" || fail "new-skill did not link the quality bar"
grep -q '^## Evidence handoff$' "$SCAFFOLD_FIXTURE/skills/z-test-workflow/SKILL.md" || fail "new-skill did not generate the evidence handoff"
grep -Fq 'Evidence does not upgrade on handoff' "$SCAFFOLD_FIXTURE/skills/z-test-workflow/SKILL.md" || fail "new-skill did not preserve evidence classes"
grep -Fq 'The handoff is a fixed interface.' "$SCAFFOLD_FIXTURE/skills/z-test-workflow/SKILL.md" || fail "new-skill did not generate the fixed handoff contract"
grep -Fq 'TBD after test' "$SCAFFOLD_FIXTURE/skills/z-test-workflow/SKILL.md" || fail "new-skill did not generate the pre-result handoff state"
grep -q '^  - id: z-test-workflow$' "$SCAFFOLD_FIXTURE/catalog.yaml" || fail "new-skill did not register the draft"
grep -A4 '^  - id: z-test-workflow$' "$SCAFFOLD_FIXTURE/catalog.yaml" | grep -q '^    status: draft$' || fail "new-skill did not use draft status"
grep -A4 '^  - id: z-test-workflow$' "$SCAFFOLD_FIXTURE/catalog.yaml" | grep -q '^    category: product$' || fail "new-skill ignored the requested category"
if "$SCAFFOLD_FIXTURE/scripts/doctor.sh" --source-only > "$TEST_ROOT/scaffold.log" 2>&1; then
  fail "doctor accepted scaffold placeholders"
fi
grep -q "SKILL.md still contains scaffold placeholder content" "$TEST_ROOT/scaffold.log" || fail "doctor did not reject skill placeholders"
grep -q "catalog.yaml still contains TODO placeholder content" "$TEST_ROOT/scaffold.log" || fail "doctor did not reject the catalog placeholder"

sed \
  -e 's/TODO: Describe the recurring independent-developer outcome in one or two sentences\./A reusable workflow for solo developers that produces a concrete, verifiable outcome./' \
  -e 's/^1\. …$/1. Inspect the available inputs./' \
  -e 's/^2\. …$/2. Produce a concrete, verifiable output./' \
  "$SCAFFOLD_FIXTURE/skills/z-test-workflow/SKILL.md" > "$SCAFFOLD_FIXTURE/skills/z-test-workflow/SKILL.md.next"
mv "$SCAFFOLD_FIXTURE/skills/z-test-workflow/SKILL.md.next" "$SCAFFOLD_FIXTURE/skills/z-test-workflow/SKILL.md"
sed 's/TODO: Describe the recurring solo-developer outcome for Test Workflow\./A reusable product workflow for independent developers./' \
  "$SCAFFOLD_FIXTURE/catalog.yaml" > "$SCAFFOLD_FIXTURE/catalog.yaml.next"
mv "$SCAFFOLD_FIXTURE/catalog.yaml.next" "$SCAFFOLD_FIXTURE/catalog.yaml"
"$SCAFFOLD_FIXTURE/scripts/doctor.sh" --source-only >/dev/null

cp "$SCAFFOLD_FIXTURE/catalog.yaml" "$TEST_ROOT/scaffold-catalog.before"
if "$SCAFFOLD_FIXTURE/scripts/new-skill.sh" z-test-workflow product > "$TEST_ROOT/duplicate.log" 2>&1; then
  fail "new-skill accepted a duplicate skill"
fi
cmp -s "$TEST_ROOT/scaffold-catalog.before" "$SCAFFOLD_FIXTURE/catalog.yaml" || fail "duplicate creation changed catalog.yaml"
pass "new-skill atomically registers a draft and doctor gates placeholders"

SCAFFOLD_CATALOG_DRIFT_FIXTURE="$(copy_fixture scaffold-catalog-drift)"
mkdir -p "$TEST_ROOT/catalog-drift-cp-bin"
# These single-quoted lines are the source of the generated fault-injection shim.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'count=0' \
  '"$REAL_CP_BIN" "$@"' \
  'if [[ "$1" == "$CATALOG_PATH" ]]; then' \
  '  [[ -f "$CP_STATE_FILE" ]] && read -r count < "$CP_STATE_FILE"' \
  '  count=$((count + 1))' \
  '  printf "%s\n" "$count" > "$CP_STATE_FILE"' \
  'fi' \
  'if [[ "$1" == "$CATALOG_PATH" && "$count" -eq 1 ]]; then' \
  '  printf "%s\n" "# external in-place catalog edit must survive" >> "$CATALOG_PATH"' \
  'fi' > "$TEST_ROOT/catalog-drift-cp-bin/cp"
chmod +x "$TEST_ROOT/catalog-drift-cp-bin/cp"
if PATH="$TEST_ROOT/catalog-drift-cp-bin:$PATH" \
  CP_STATE_FILE="$TEST_ROOT/catalog-drift-cp-state" \
  REAL_CP_BIN="$(command -v cp)" \
  CATALOG_PATH="$SCAFFOLD_CATALOG_DRIFT_FIXTURE/catalog.yaml" \
  "$SCAFFOLD_CATALOG_DRIFT_FIXTURE/scripts/new-skill.sh" z-catalog-drift product \
  > "$TEST_ROOT/scaffold-catalog-drift.log" 2>&1; then
  fail "new-skill published against an in-place catalog edit"
fi
tail -n 1 "$SCAFFOLD_CATALOG_DRIFT_FIXTURE/catalog.yaml" |
  grep -qx '# external in-place catalog edit must survive' ||
  fail "new-skill discarded an in-place catalog edit"
[[ ! -e "$SCAFFOLD_CATALOG_DRIFT_FIXTURE/skills/z-catalog-drift" ]] ||
  fail "new-skill moved a skill after catalog content drift"
grep -q 'catalog.yaml changed while its original bytes were captured' \
  "$TEST_ROOT/scaffold-catalog-drift.log" ||
  fail "new-skill reported the wrong catalog content-drift failure"
[[ ! -e "$SCAFFOLD_CATALOG_DRIFT_FIXTURE/.zstack-new-skill.lock" ]] ||
  fail "new-skill catalog drift left its transaction lock"
catalog_drift_temps="$(find "$SCAFFOLD_CATALOG_DRIFT_FIXTURE" -maxdepth 1 -name '.zstack-new-skill.*' ! -name '.zstack-new-skill.lock' | wc -l | tr -d ' ')"
[[ "$catalog_drift_temps" -eq 0 ]] || fail "new-skill catalog drift left transaction files"
pass "new-skill binds publication to exact preflight catalog bytes"

SCAFFOLD_TEMPLATE_DRIFT_FIXTURE="$(copy_fixture scaffold-template-drift)"
SCAFFOLD_TEMPLATE_DRIFT_SOURCE="$SCAFFOLD_TEMPLATE_DRIFT_FIXTURE/skills/_template/references/quality-bar.md"
mkdir -p "$TEST_ROOT/template-drift-cp-bin"
# These single-quoted lines are the source of the generated fault-injection shim.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  '"$REAL_CP_BIN" "$@"' \
  'if [[ "$1" == "$QUALITY_TEMPLATE_PATH" ]]; then' \
  '  printf "%s\n" "<!-- external template edit must survive -->" >> "$QUALITY_TEMPLATE_PATH"' \
  'fi' > "$TEST_ROOT/template-drift-cp-bin/cp"
chmod +x "$TEST_ROOT/template-drift-cp-bin/cp"
if PATH="$TEST_ROOT/template-drift-cp-bin:$PATH" \
  REAL_CP_BIN="$(command -v cp)" \
  QUALITY_TEMPLATE_PATH="$SCAFFOLD_TEMPLATE_DRIFT_SOURCE" \
  "$SCAFFOLD_TEMPLATE_DRIFT_FIXTURE/scripts/new-skill.sh" z-template-drift product \
  > "$TEST_ROOT/scaffold-template-drift.log" 2>&1; then
  fail "new-skill published against a changed scaffold template"
fi
tail -n 1 "$SCAFFOLD_TEMPLATE_DRIFT_SOURCE" |
  grep -qx '<!-- external template edit must survive -->' ||
  fail "new-skill discarded an external template edit"
[[ ! -e "$SCAFFOLD_TEMPLATE_DRIFT_FIXTURE/skills/z-template-drift" ]] ||
  fail "new-skill moved a skill after template drift"
grep -q 'Scaffold templates changed while they were captured' \
  "$TEST_ROOT/scaffold-template-drift.log" ||
  fail "new-skill reported the wrong template-drift failure"
[[ ! -e "$SCAFFOLD_TEMPLATE_DRIFT_FIXTURE/.zstack-new-skill.lock" ]] ||
  fail "new-skill template drift left its transaction lock"
template_drift_temps="$(find "$SCAFFOLD_TEMPLATE_DRIFT_FIXTURE" -maxdepth 1 -name '.zstack-new-skill.*' ! -name '.zstack-new-skill.lock' | wc -l | tr -d ' ')"
[[ "$template_drift_temps" -eq 0 ]] || fail "new-skill template drift left transaction files"
pass "new-skill snapshots templates and rejects mixed-version scaffolds"

SCAFFOLD_TEMPLATE_HARDLINK_FIXTURE="$(copy_fixture scaffold-template-hardlink)"
SCAFFOLD_TEMPLATE_HARDLINK_ALIAS="$TEST_ROOT/scaffold-template-hardlink-alias"
cp "$SCAFFOLD_TEMPLATE_HARDLINK_FIXTURE/catalog.yaml" \
  "$TEST_ROOT/scaffold-template-hardlink-catalog.before"
mkdir -p "$TEST_ROOT/template-hardlink-cp-bin"
# These single-quoted lines are the source of the generated fault-injection shim.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  '"$REAL_CP_BIN" "$@"' \
  'if [[ "${2:-}" == */template.skill.* ]]; then' \
  '  ln "$2" "$SNAPSHOT_ALIAS"' \
  'fi' > "$TEST_ROOT/template-hardlink-cp-bin/cp"
chmod +x "$TEST_ROOT/template-hardlink-cp-bin/cp"
if PATH="$TEST_ROOT/template-hardlink-cp-bin:$PATH" \
  REAL_CP_BIN="$(command -v cp)" \
  SNAPSHOT_ALIAS="$SCAFFOLD_TEMPLATE_HARDLINK_ALIAS" \
  "$SCAFFOLD_TEMPLATE_HARDLINK_FIXTURE/scripts/new-skill.sh" \
  z-template-hardlink product > "$TEST_ROOT/scaffold-template-hardlink.log" 2>&1; then
  fail "new-skill accepted a hardlinked scaffold-template snapshot"
fi
cmp -s "$TEST_ROOT/scaffold-template-hardlink-catalog.before" \
  "$SCAFFOLD_TEMPLATE_HARDLINK_FIXTURE/catalog.yaml" ||
  fail "new-skill changed catalog after rejecting a hardlinked template snapshot"
[[ ! -e "$SCAFFOLD_TEMPLATE_HARDLINK_FIXTURE/skills/z-template-hardlink" ]] ||
  fail "new-skill published a skill after rejecting a hardlinked template snapshot"
[[ ! -e "$SCAFFOLD_TEMPLATE_HARDLINK_FIXTURE/.zstack-new-skill.lock" ]] ||
  fail "new-skill hardlinked template snapshot left its transaction lock"
grep -q 'Scaffold templates changed while they were captured' \
  "$TEST_ROOT/scaffold-template-hardlink.log" ||
  fail "new-skill reported the wrong hardlinked template-snapshot failure"
template_hardlink_temp="$(find "$SCAFFOLD_TEMPLATE_HARDLINK_FIXTURE" \
  -maxdepth 2 -path '*/.zstack-new-skill.*/template.skill.*' -print -quit)"
[[ -n "$template_hardlink_temp" ]] ||
  fail "new-skill removed a template snapshot with an external hardlink"
[[ "$(zstack_file_link_count "$template_hardlink_temp")" == "2" ]] ||
  fail "new-skill template hardlink fixture did not preserve the raced inode"
template_hardlink_work_dir="$(dirname "$template_hardlink_temp")"
unlink "$SCAFFOLD_TEMPLATE_HARDLINK_ALIAS"
unlink "$template_hardlink_temp"
rmdir "$template_hardlink_work_dir"
pass "new-skill requires exclusive scaffold-template snapshots"

SCAFFOLD_DESTINATION_RACE_FIXTURE="$(copy_fixture scaffold-destination-race)"
SCAFFOLD_DESTINATION_RACE="$SCAFFOLD_DESTINATION_RACE_FIXTURE/skills/z-destination-race"
mkdir -p "$TEST_ROOT/destination-race-mv-bin"
# These single-quoted lines are the source of the generated fault-injection shim.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'if [[ "$2" == "$DESTINATION_PATH" ]]; then' \
  '  mkdir -p "$DESTINATION_PATH"' \
  '  printf "%s\n" "replacement destination must survive" > "$DESTINATION_PATH/replacement.txt"' \
  'fi' \
  'exec "$REAL_MV_BIN" "$@"' > "$TEST_ROOT/destination-race-mv-bin/mv"
chmod +x "$TEST_ROOT/destination-race-mv-bin/mv"
if PATH="$TEST_ROOT/destination-race-mv-bin:$PATH" \
  REAL_MV_BIN="$(command -v mv)" \
  DESTINATION_PATH="$SCAFFOLD_DESTINATION_RACE" \
  "$SCAFFOLD_DESTINATION_RACE_FIXTURE/scripts/new-skill.sh" z-destination-race product \
  > "$TEST_ROOT/scaffold-destination-race.log" 2>&1; then
  fail "new-skill accepted a destination created during publication"
fi
grep -qx 'replacement destination must survive' "$SCAFFOLD_DESTINATION_RACE/replacement.txt" ||
  fail "new-skill destination rollback removed the replacement directory"
[[ ! -e "$SCAFFOLD_DESTINATION_RACE/z-destination-race" ]] ||
  fail "new-skill left a generated skill nested under a replacement destination"
if grep -q '^  - id: z-destination-race$' "$SCAFFOLD_DESTINATION_RACE_FIXTURE/catalog.yaml"; then
  fail "new-skill updated catalog after destination replacement"
fi
grep -q 'Skill destination changed during publication' "$TEST_ROOT/scaffold-destination-race.log" ||
  fail "new-skill reported the wrong destination-race failure"
[[ ! -e "$SCAFFOLD_DESTINATION_RACE_FIXTURE/.zstack-new-skill.lock" ]] ||
  fail "new-skill destination race left its transaction lock"
destination_race_temps="$(find "$SCAFFOLD_DESTINATION_RACE_FIXTURE" -maxdepth 1 -name '.zstack-new-skill.*' ! -name '.zstack-new-skill.lock' | wc -l | tr -d ' ')"
[[ "$destination_race_temps" -eq 0 ]] || fail "new-skill destination race left transaction files"
pass "new-skill rejects mv nesting under a raced destination"

TRANSACTION_FIXTURE="$(copy_fixture scaffold-rollback)"
cp "$TRANSACTION_FIXTURE/catalog.yaml" "$TEST_ROOT/transaction-catalog.before"
mkdir -p "$TEST_ROOT/fail-mv-bin"
# These single-quoted lines are the source of the generated fault-injection shim.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'if [[ "${1:-}" == */catalog.next.* && "${2:-}" == "$CATALOG_PATH" ]]; then' \
  '  exit 1' \
  'fi' \
  'exec "$REAL_MV_BIN" "$@"' > "$TEST_ROOT/fail-mv-bin/mv"
chmod +x "$TEST_ROOT/fail-mv-bin/mv"
if PATH="$TEST_ROOT/fail-mv-bin:$PATH" \
  REAL_MV_BIN="$(command -v mv)" \
  CATALOG_PATH="$TRANSACTION_FIXTURE/catalog.yaml" \
  "$TRANSACTION_FIXTURE/scripts/new-skill.sh" z-rollback-test product > "$TEST_ROOT/scaffold-rollback.log" 2>&1; then
  fail "new-skill reported success after catalog replacement failure"
fi
cmp -s "$TEST_ROOT/transaction-catalog.before" "$TRANSACTION_FIXTURE/catalog.yaml" || fail "new-skill did not restore catalog after replacement failure"
[[ ! -e "$TRANSACTION_FIXTURE/skills/z-rollback-test" ]] || fail "new-skill left a partial skill after replacement failure"
[[ ! -e "$TRANSACTION_FIXTURE/.zstack-new-skill.lock" ]] || fail "new-skill left its transaction lock"
transaction_temps="$(find "$TRANSACTION_FIXTURE" -maxdepth 1 -name '.zstack-new-skill.*' ! -name '.zstack-new-skill.lock' | wc -l | tr -d ' ')"
[[ "$transaction_temps" -eq 0 ]] || fail "new-skill left transaction files"
pass "new-skill rolls back a failed catalog replacement"

SCAFFOLD_REPLACEMENT_FIXTURE="$(copy_fixture scaffold-replacement-rollback)"
cp "$SCAFFOLD_REPLACEMENT_FIXTURE/catalog.yaml" "$TEST_ROOT/scaffold-replacement-catalog.before"
SCAFFOLD_REPLACEMENT_SKILL="$SCAFFOLD_REPLACEMENT_FIXTURE/skills/z-replacement-rollback/SKILL.md"
SCAFFOLD_REPLACEMENT_MOVED="$SCAFFOLD_REPLACEMENT_FIXTURE/skills/z-replacement-rollback/SKILL.md.created"
mkdir -p "$TEST_ROOT/fail-mv-replacement-bin"
# These single-quoted lines are the source of the generated fault-injection shim.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'if [[ "${1:-}" == */catalog.next.* && "${2:-}" == "$CATALOG_PATH" ]]; then' \
  '  "$REAL_MV_BIN" "$REPLACEMENT_SKILL" "$REPLACEMENT_MOVED"' \
  '  printf "%s\n" "replacement scaffold must survive" > "$REPLACEMENT_SKILL"' \
  '  exit 1' \
  'fi' \
  'exec "$REAL_MV_BIN" "$@"' > "$TEST_ROOT/fail-mv-replacement-bin/mv"
chmod +x "$TEST_ROOT/fail-mv-replacement-bin/mv"
if PATH="$TEST_ROOT/fail-mv-replacement-bin:$PATH" \
  REAL_MV_BIN="$(command -v mv)" \
  CATALOG_PATH="$SCAFFOLD_REPLACEMENT_FIXTURE/catalog.yaml" \
  REPLACEMENT_SKILL="$SCAFFOLD_REPLACEMENT_SKILL" \
  REPLACEMENT_MOVED="$SCAFFOLD_REPLACEMENT_MOVED" \
  "$SCAFFOLD_REPLACEMENT_FIXTURE/scripts/new-skill.sh" z-replacement-rollback product \
  > "$TEST_ROOT/scaffold-replacement-rollback.log" 2>&1; then
  fail "new-skill accepted a replaced scaffold after catalog failure"
fi
cmp -s "$TEST_ROOT/scaffold-replacement-catalog.before" "$SCAFFOLD_REPLACEMENT_FIXTURE/catalog.yaml" ||
  fail "new-skill replacement rollback did not restore catalog.yaml"
grep -qx 'replacement scaffold must survive' "$SCAFFOLD_REPLACEMENT_SKILL" ||
  fail "new-skill rollback removed a replacement scaffold file"
[[ -f "$SCAFFOLD_REPLACEMENT_MOVED" ]] ||
  fail "new-skill rollback removed the displaced original scaffold file"
[[ ! -e "$SCAFFOLD_REPLACEMENT_FIXTURE/.zstack-new-skill.lock" ]] ||
  fail "new-skill replacement rollback left its transaction lock"
replacement_transaction_temps="$(find "$SCAFFOLD_REPLACEMENT_FIXTURE" -maxdepth 1 -name '.zstack-new-skill.*' ! -name '.zstack-new-skill.lock' | wc -l | tr -d ' ')"
[[ "$replacement_transaction_temps" -eq 0 ]] ||
  fail "new-skill replacement rollback left transaction files"
rm -rf "$SCAFFOLD_REPLACEMENT_FIXTURE/skills/z-replacement-rollback"
pass "new-skill rollback removes only identity-matched scaffold files"

SCAFFOLD_CATALOG_REPLACEMENT_FIXTURE="$(copy_fixture scaffold-catalog-replacement)"
SCAFFOLD_CATALOG_REPLACEMENT="$SCAFFOLD_CATALOG_REPLACEMENT_FIXTURE/catalog.yaml"
SCAFFOLD_CATALOG_DISPLACED="$SCAFFOLD_CATALOG_REPLACEMENT_FIXTURE/catalog.yaml.created"
mkdir -p "$TEST_ROOT/fail-mv-catalog-replacement-bin"
# These single-quoted lines are the source of the generated fault-injection shim.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'if [[ "${1:-}" == */catalog.next.* && "${2:-}" == "$CATALOG_PATH" ]]; then' \
  '  "$REAL_MV_BIN" "$CATALOG_PATH" "$CATALOG_DISPLACED"' \
  '  printf "%s\n" "external catalog replacement must survive" > "$CATALOG_PATH"' \
  '  exit 1' \
  'fi' \
  'exec "$REAL_MV_BIN" "$@"' > "$TEST_ROOT/fail-mv-catalog-replacement-bin/mv"
chmod +x "$TEST_ROOT/fail-mv-catalog-replacement-bin/mv"
if PATH="$TEST_ROOT/fail-mv-catalog-replacement-bin:$PATH" \
  REAL_MV_BIN="$(command -v mv)" \
  CATALOG_PATH="$SCAFFOLD_CATALOG_REPLACEMENT" \
  CATALOG_DISPLACED="$SCAFFOLD_CATALOG_DISPLACED" \
  "$SCAFFOLD_CATALOG_REPLACEMENT_FIXTURE/scripts/new-skill.sh" z-catalog-replacement product \
  > "$TEST_ROOT/scaffold-catalog-replacement.log" 2>&1; then
  fail "new-skill accepted an externally replaced catalog"
fi
grep -qx 'external catalog replacement must survive' "$SCAFFOLD_CATALOG_REPLACEMENT" ||
  fail "new-skill rollback overwrote an external catalog replacement"
[[ -f "$SCAFFOLD_CATALOG_DISPLACED" ]] ||
  fail "new-skill rollback removed the displaced catalog"
[[ -f "$SCAFFOLD_CATALOG_REPLACEMENT_FIXTURE/skills/z-catalog-replacement/SKILL.md" ]] ||
  fail "new-skill rollback removed a skill after external catalog replacement"
grep -q 'catalog.yaml was replaced externally; preserving it' \
  "$TEST_ROOT/scaffold-catalog-replacement.log" ||
  fail "new-skill rollback did not report external catalog replacement"
[[ ! -e "$SCAFFOLD_CATALOG_REPLACEMENT_FIXTURE/.zstack-new-skill.lock" ]] ||
  fail "new-skill external-catalog rollback left its transaction lock"
catalog_replacement_temps="$(find "$SCAFFOLD_CATALOG_REPLACEMENT_FIXTURE" -maxdepth 1 -name '.zstack-new-skill.*' ! -name '.zstack-new-skill.lock' | wc -l | tr -d ' ')"
[[ "$catalog_replacement_temps" -eq 0 ]] ||
  fail "new-skill external-catalog rollback left transaction files"
pass "new-skill rollback preserves external catalog replacements"

SCAFFOLD_POSTPUBLISH_EDIT_FIXTURE="$(copy_fixture scaffold-postpublish-edit)"
SCAFFOLD_POSTPUBLISH_CATALOG="$SCAFFOLD_POSTPUBLISH_EDIT_FIXTURE/catalog.yaml"
mkdir -p "$TEST_ROOT/postpublish-edit-mv-bin"
# These single-quoted lines are the source of the generated fault-injection shim.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  '"$REAL_MV_BIN" "$@"' \
  'if [[ "${1:-}" == */catalog.next.* && "${2:-}" == "$CATALOG_PATH" ]]; then' \
  '  printf "%s\n" "# post-publish catalog edit must survive" >> "$CATALOG_PATH"' \
  'fi' > "$TEST_ROOT/postpublish-edit-mv-bin/mv"
chmod +x "$TEST_ROOT/postpublish-edit-mv-bin/mv"
if PATH="$TEST_ROOT/postpublish-edit-mv-bin:$PATH" \
  REAL_MV_BIN="$(command -v mv)" \
  CATALOG_PATH="$SCAFFOLD_POSTPUBLISH_CATALOG" \
  "$SCAFFOLD_POSTPUBLISH_EDIT_FIXTURE/scripts/new-skill.sh" z-postpublish-edit product \
  > "$TEST_ROOT/scaffold-postpublish-edit.log" 2>&1; then
  fail "new-skill accepted a catalog edited immediately after publication"
fi
tail -n 1 "$SCAFFOLD_POSTPUBLISH_CATALOG" |
  grep -qx '# post-publish catalog edit must survive' ||
  fail "new-skill rollback discarded a post-publish catalog edit"
[[ -f "$SCAFFOLD_POSTPUBLISH_EDIT_FIXTURE/skills/z-postpublish-edit/SKILL.md" ]] ||
  fail "new-skill rollback removed a skill after post-publish catalog editing"
grep -q 'catalog.yaml changed during publication' "$TEST_ROOT/scaffold-postpublish-edit.log" ||
  fail "new-skill reported the wrong post-publish catalog failure"
grep -q 'published catalog inode was edited externally; preserving it' \
  "$TEST_ROOT/scaffold-postpublish-edit.log" ||
  fail "new-skill rollback did not report post-publish catalog preservation"
[[ ! -e "$SCAFFOLD_POSTPUBLISH_EDIT_FIXTURE/.zstack-new-skill.lock" ]] ||
  fail "new-skill post-publish catalog edit left its transaction lock"
postpublish_edit_temps="$(find "$SCAFFOLD_POSTPUBLISH_EDIT_FIXTURE" -maxdepth 1 -name '.zstack-new-skill.*' ! -name '.zstack-new-skill.lock' | wc -l | tr -d ' ')"
[[ "$postpublish_edit_temps" -eq 0 ]] ||
  fail "new-skill post-publish catalog edit left transaction files"
pass "new-skill verifies published catalog bytes before success"

SCAFFOLD_EXPECTED_HARDLINK_FIXTURE="$(copy_fixture scaffold-expected-hardlink)"
SCAFFOLD_EXPECTED_HARDLINK_CATALOG="$SCAFFOLD_EXPECTED_HARDLINK_FIXTURE/catalog.yaml"
SCAFFOLD_EXPECTED_HARDLINK_ALIAS="$TEST_ROOT/scaffold-expected-hardlink-alias"
mkdir -p "$TEST_ROOT/scaffold-expected-hardlink-mv-bin"
# These single-quoted lines are the source of the generated fault-injection shim.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  '"$REAL_MV_BIN" "$@"' \
  'if [[ "${1:-}" == */catalog.next.* && "${2:-}" == "$CATALOG_PATH" ]]; then' \
  '  for expected_path in "$ROOT_PATH"/.zstack-new-skill.*/catalog.expected.*; do' \
  '    [[ -f "$expected_path" ]] || continue' \
  '    ln "$expected_path" "$EXPECTED_ALIAS"' \
  '    break' \
  '  done' \
  'fi' > "$TEST_ROOT/scaffold-expected-hardlink-mv-bin/mv"
chmod +x "$TEST_ROOT/scaffold-expected-hardlink-mv-bin/mv"
if PATH="$TEST_ROOT/scaffold-expected-hardlink-mv-bin:$PATH" \
  REAL_MV_BIN="$(command -v mv)" \
  CATALOG_PATH="$SCAFFOLD_EXPECTED_HARDLINK_CATALOG" \
  ROOT_PATH="$SCAFFOLD_EXPECTED_HARDLINK_FIXTURE" \
  EXPECTED_ALIAS="$SCAFFOLD_EXPECTED_HARDLINK_ALIAS" \
  "$SCAFFOLD_EXPECTED_HARDLINK_FIXTURE/scripts/new-skill.sh" \
  z-expected-hardlink product > "$TEST_ROOT/scaffold-expected-hardlink.log" 2>&1; then
  fail "new-skill accepted a catalog expected snapshot hardlinked after publication"
fi
grep -q '^  - id: z-expected-hardlink$' "$SCAFFOLD_EXPECTED_HARDLINK_CATALOG" ||
  fail "new-skill expected-hardlink fixture did not publish the catalog candidate"
[[ -f "$SCAFFOLD_EXPECTED_HARDLINK_FIXTURE/skills/z-expected-hardlink/SKILL.md" ]] ||
  fail "new-skill removed the scaffold after its rollback proof lost exclusivity"
[[ ! -e "$SCAFFOLD_EXPECTED_HARDLINK_FIXTURE/.zstack-new-skill.lock" ]] ||
  fail "new-skill expected catalog hardlink left its transaction lock"
grep -q 'catalog.yaml changed during publication' \
  "$TEST_ROOT/scaffold-expected-hardlink.log" ||
  fail "new-skill reported the wrong expected catalog hardlink failure"
grep -q 'published catalog inode was edited externally; preserving it' \
  "$TEST_ROOT/scaffold-expected-hardlink.log" ||
  fail "new-skill used a non-exclusive expected snapshot for rollback"
scaffold_expected_hardlink_temp="$(find "$SCAFFOLD_EXPECTED_HARDLINK_FIXTURE" \
  -maxdepth 2 -path '*/.zstack-new-skill.*/catalog.expected.*' -print -quit)"
[[ -n "$scaffold_expected_hardlink_temp" ]] ||
  fail "new-skill removed an expected catalog snapshot with an external hardlink"
[[ "$(zstack_file_link_count "$scaffold_expected_hardlink_temp")" == "2" ]] ||
  fail "new-skill expected catalog hardlink fixture did not preserve the raced inode"
scaffold_expected_hardlink_work_dir="$(dirname "$scaffold_expected_hardlink_temp")"
unlink "$SCAFFOLD_EXPECTED_HARDLINK_ALIAS"
unlink "$scaffold_expected_hardlink_temp"
rmdir "$scaffold_expected_hardlink_work_dir"
pass "new-skill requires exclusive catalog publication and rollback proof"

if "$TRANSACTION_FIXTURE/scripts/new-skill.sh" z-too-many product extra > "$TEST_ROOT/scaffold-args.log" 2>&1; then
  fail "new-skill accepted extra positional arguments"
fi
cmp -s "$TEST_ROOT/transaction-catalog.before" "$TRANSACTION_FIXTURE/catalog.yaml" || fail "invalid arguments changed catalog.yaml"

mkdir "$TRANSACTION_FIXTURE/.zstack-new-skill.lock"
printf '%s\n' "$$" > "$TRANSACTION_FIXTURE/.zstack-new-skill.lock/pid"
chmod 700 "$TRANSACTION_FIXTURE/.zstack-new-skill.lock"
chmod 600 "$TRANSACTION_FIXTURE/.zstack-new-skill.lock/pid"
if "$TRANSACTION_FIXTURE/scripts/new-skill.sh" z-lock-test product > "$TEST_ROOT/scaffold-lock.log" 2>&1; then
  fail "new-skill ignored an active transaction lock"
fi
cmp -s "$TEST_ROOT/transaction-catalog.before" "$TRANSACTION_FIXTURE/catalog.yaml" || fail "lock contention changed catalog.yaml"
[[ ! -e "$TRANSACTION_FIXTURE/skills/z-lock-test" ]] || fail "lock contention created a partial skill"
rm -f "$TRANSACTION_FIXTURE/.zstack-new-skill.lock/pid"
rmdir "$TRANSACTION_FIXTURE/.zstack-new-skill.lock"
pass "new-skill rejects concurrent catalog mutation"

mkdir "$TRANSACTION_FIXTURE/.zstack-new-skill.lock"
printf '%s\n' "999999999" > "$TRANSACTION_FIXTURE/.zstack-new-skill.lock/pid"
chmod 700 "$TRANSACTION_FIXTURE/.zstack-new-skill.lock"
chmod 600 "$TRANSACTION_FIXTURE/.zstack-new-skill.lock/pid"
"$TRANSACTION_FIXTURE/scripts/new-skill.sh" z-stale-lock product > "$TEST_ROOT/stale-lock.log" 2>&1
grep -q "Recovered stale new-skill lock" "$TEST_ROOT/stale-lock.log" || fail "new-skill did not report stale-lock recovery"
[[ -f "$TRANSACTION_FIXTURE/skills/z-stale-lock/SKILL.md" ]] || fail "new-skill did not continue after stale-lock recovery"
[[ ! -e "$TRANSACTION_FIXTURE/.zstack-new-skill.lock" ]] || fail "new-skill left a recovered lock behind"
pass "new-skill recovers a stale transaction lock"

echo "All tests passed."
