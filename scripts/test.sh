#!/usr/bin/env bash
# Integration tests for validation and install safety.
# Single-quoted fixture lines intentionally defer expansion to generated fake CLIs.
# shellcheck disable=SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/zstack-tests.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

pass() { echo "PASS: $*"; }
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

"$ROOT/scripts/doctor.sh" --source-only >/dev/null
pass "repository passes source validation"

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

ruby -I "$ROOT/scripts/lib" -r eval_host_contracts -e '
  contracts = Zstack::EvalHostContracts
  abort "Grok isolated config is mutable" unless contracts::GROK_ISOLATED_CONFIG.frozen?
  abort "Grok final marker is mutable" unless contracts::GROK_FINAL_MARKER.frozen?
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

source "$ROOT/scripts/lib/common.sh"
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
pass "state leaves accept only regular files"

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

LOCK_RELEASE_CONTRACT="$TEST_ROOT/lock-release-contract"
mkdir -p "$LOCK_RELEASE_CONTRACT/directory.lock"
printf '%s\n' "$$" > "$LOCK_RELEASE_CONTRACT/owner"
ln -s "$LOCK_RELEASE_CONTRACT/owner" "$LOCK_RELEASE_CONTRACT/symlink.lock"
ln -s "$LOCK_RELEASE_CONTRACT/owner" "$LOCK_RELEASE_CONTRACT/directory.lock/pid"
zstack_release_pid_lock "$LOCK_RELEASE_CONTRACT/symlink.lock"
zstack_release_pid_lock "$LOCK_RELEASE_CONTRACT/directory.lock"
[[ -L "$LOCK_RELEASE_CONTRACT/symlink.lock" ]] || fail "lock release removed a replaced lock symlink"
[[ -L "$LOCK_RELEASE_CONTRACT/directory.lock/pid" ]] || fail "lock release removed a replaced owner symlink"
grep -qx "$$" "$LOCK_RELEASE_CONTRACT/owner" || fail "lock release changed an unsafe symlink target"
pass "PID lock release ignores replaced lock and owner symlinks"

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
pass "CLI help is side-effect free and host filters are strict"

ROUTING_DRY_RUN="$TEST_ROOT/routing-runner-dry"
"$ROOT/scripts/run-codex-routing-evals.rb" \
  --dry-run \
  --case zh-boundary-public-research \
  --case none-code-fix \
  --truncate-descriptions 180 \
  --output "$ROUTING_DRY_RUN" > "$TEST_ROOT/routing-runner-dry.log"
[[ -f "$ROUTING_DRY_RUN/prompts/zh-boundary-public-research.txt" ]] || fail "routing runner omitted a selected prompt"
[[ ! -e "$ROUTING_DRY_RUN/results.json" ]] || fail "routing dry-run invented graded results"
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

FAKE_CODEX="$TEST_ROOT/fake-codex"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'if [[ "${1:-}" == "--version" ]]; then' \
  '  echo "codex-cli fake-1.0"' \
  '  exit 0' \
  'fi' \
  '[[ "${1:-}" == "exec" ]] || exit 64' \
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
  'sleep "${FAKE_CODEX_SLEEP_SECONDS:-0}"' \
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
' "$ROUTING_FAKE_PASS/controls.json"
grep -q '"hostVersion": "codex-cli fake-1.0"' "$ROUTING_FAKE_PASS/controls.json" || fail "routing runner did not record the host version"
[[ ! -e "$ROUTING_FAKE_PASS/workspace" && ! -e "$ROUTING_FAKE_PASS/workspaces" ]] || fail "routing runner retained disposable workspaces"
pass "routing runner isolates and grades clean fake Codex cases"

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
ruby "$ROUTING_ARCHIVE_FIXTURE/scripts/validate-evidence.rb" >/dev/null
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
pass "routing archiver atomically preserves prompts and responses without private logs"

ROUTING_ROLLBACK_FIXTURE="$(copy_fixture routing-archive-rollback)"
ROLLBACK_COUNTER="$TEST_ROOT/routing-archive-validation-counter"
printf '%s\n' \
  '#!/usr/bin/env ruby' \
  'counter = ENV.fetch("ROUTING_ARCHIVE_VALIDATION_COUNTER")' \
  'if File.exist?(counter)' \
  '  warn "injected post-publish validation failure"' \
  '  exit 1' \
  'end' \
  'File.write(counter, "preflight passed\n")' \
  'puts "preflight evidence valid"' > "$ROUTING_ROLLBACK_FIXTURE/scripts/validate-evidence.rb"
chmod +x "$ROUTING_ROLLBACK_FIXTURE/scripts/validate-evidence.rb"
if ROUTING_ARCHIVE_VALIDATION_COUNTER="$ROLLBACK_COUNTER" \
  "$ROUTING_ROLLBACK_FIXTURE/scripts/archive-codex-routing-run.rb" \
  --run-dir "$ROUTING_FAKE_PASS" \
  --archive 2026-08-01-rollback-routing \
  --phase rollback > "$TEST_ROOT/routing-archive-rollback.log" 2>&1; then
  fail "routing archiver reported success after post-publish validation failed"
fi
[[ ! -e "$ROUTING_ROLLBACK_FIXTURE/evals/runs/2026-08-01-rollback-routing" ]] || fail "routing archiver left a failed published archive"
rollback_temps="$(find "$ROUTING_ROLLBACK_FIXTURE/evals/runs" -maxdepth 1 -name '.zstack-routing-archive-*' -print | wc -l | tr -d ' ')"
[[ "$rollback_temps" -eq 0 ]] || fail "routing archiver left a transaction directory after rollback"
pass "routing archiver rolls back post-publish validation failures"

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

ROUTING_NONEMPTY="$TEST_ROOT/routing-runner-nonempty"
mkdir -p "$ROUTING_NONEMPTY"
printf '%s\n' "keep me" > "$ROUTING_NONEMPTY/owner.txt"
if "$ROOT/scripts/run-codex-routing-evals.rb" --dry-run --case none-code-fix --output "$ROUTING_NONEMPTY" > "$TEST_ROOT/routing-runner-nonempty.log" 2>&1; then
  fail "routing runner reused a non-empty output directory"
fi
grep -q "output directory must be empty" "$TEST_ROOT/routing-runner-nonempty.log" || fail "routing runner reported the wrong output-reuse failure"
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
  abort "Grok routing results lost final-boundary provenance" unless results.all? { |result| result.fetch("pass") && result.fetch("actualModels") == ["grok-fake-routing-1"] && result.fetch("prefinalNarrationBytes").positive? && result.fetch("finalBoundaryError").nil? }
  args = invocation.fetch("arguments")
  tools_index = args.index("--tools")
  abort "Grok routing invocation did not disable tools" unless tools_index && args.fetch(tools_index + 1) == ""
  token = invocation.fetch("privateCaseToken")
  abort "Grok routing private token is malformed" unless token.match?(/\Acase-[0-9a-f]{32}\z/)
  abort "Grok routing workspace leaked its semantic case id" unless File.basename(invocation.fetch("workspace")) == token && !invocation.fetch("workspace").include?("zh-market-public")
  prompt_index = args.index("--prompt-file")
  private_prompt = args.fetch(prompt_index + 1)
  abort "Grok routing prompt path is not opaque" unless File.basename(private_prompt) == "#{token}.txt" && File.basename(File.dirname(private_prompt)) == ".prompt-files" && !private_prompt.include?("zh-market-public")
  marker = controls.fetch("finalResponseBoundary")
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
  path = ARGV.fetch(0)
  raw = JSON.parse(File.read(path))
  raw["text"] = raw.fetch("text").sub("ZSTACK_FINAL_RESPONSE_V1\n", "")
  File.write(path, JSON.pretty_generate(raw) + "\n")
' "$GROK_ROUTING_BOUNDARY_TAMPERED/logs/zh-market-public.json"
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
if "$ROOT/scripts/report-evidence-coverage.rb" --require-complete-pass-host unknown > "$TEST_ROOT/behavior-coverage-unknown-host.log" 2>&1; then
  fail "behavioral coverage report accepted an unknown host family"
fi
grep -q "unknown host family" "$TEST_ROOT/behavior-coverage-unknown-host.log" || fail "behavioral coverage report returned the wrong unknown-host error"
pass "behavioral coverage report separates archived passes from complete provenance"

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
if "$ROOT/scripts/report-evidence-coverage.rb" --suite unknown > "$TEST_ROOT/routing-coverage-unknown-suite.log" 2>&1; then
  fail "evidence coverage report accepted an unknown suite"
fi
grep -q "unknown evidence suite" "$TEST_ROOT/routing-coverage-unknown-suite.log" || fail "evidence coverage report returned the wrong suite error"
pass "routing coverage report enforces complete Codex and Grok matrices"

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

FAKE_BEHAVIOR_CODEX="$TEST_ROOT/fake-behavior-codex"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'if [[ "${1:-}" == "--version" ]]; then' \
  '  echo "codex-cli fake-behavior-1.0"' \
  '  exit 0' \
  'fi' \
  '[[ "${1:-}" == "exec" ]] || exit 64' \
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
  'sleep "${FAKE_BEHAVIOR_SLEEP_SECONDS:-0}"' \
  'response="fake complete behavioral answer"' \
  'if [[ "${FAKE_BEHAVIOR_EMPTY:-0}" != "1" ]]; then' \
  '  printf "%s\n" "$response" "" "| Field | Value |" "|---|---|" "| Current decision | Validate first |" "| Evidence classes | assumption |" "| Supported claims | The fixture ran |" "| Still unproven | Product demand |" "| Contradictions / exclusions | None supplied |" "| Source anchors | Fixture response |" "| Next validation | Run a real test |" > "$output"' \
  '  response="$(cat "$output")"' \
  'fi' \
  'printf "OpenAI Codex vfake-behavior-1.0\n--------\nworkdir: %s\nmodel: gpt-5.6-sol\napproval: never\nsandbox: read-only\nreasoning effort: medium\nuser\n%s\ncodex\n%s\n" "$workspace" "$prompt" "$response"' > "$FAKE_BEHAVIOR_CODEX"
chmod +x "$FAKE_BEHAVIOR_CODEX"

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
behavior_archive_manifest_before="$(ruby -rdigest -e 'puts Digest::SHA256.file(ARGV.fetch(0)).hexdigest' "$BEHAVIOR_ARCHIVE/archive-manifest.txt")"
if "$BEHAVIOR_ARCHIVE_FIXTURE/scripts/archive-codex-behavioral-run.rb" \
  --run-dir "$BEHAVIOR_FAKE_PASS" \
  --archive 2026-08-01-fake-behavioral \
  --phase fake > "$TEST_ROOT/behavior-archive-duplicate.log" 2>&1; then
  fail "behavioral archiver overwrote an existing archive"
fi
[[ "$(ruby -rdigest -e 'puts Digest::SHA256.file(ARGV.fetch(0)).hexdigest' "$BEHAVIOR_ARCHIVE/archive-manifest.txt")" == "$behavior_archive_manifest_before" ]] || fail "duplicate behavioral archive attempt changed existing evidence"

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
  abort "artifact runner did not complete" unless result.fetch("completed") && result.fetch("artifactError").nil?
  abort "artifact runner did not validate the Evidence handoff" unless result.dig("evidenceHandoffContract", "passed") == true
  abort "artifact runner lost its retained files" unless result.fetch("artifactPaths") == ["artifacts/smoke-complete-pack/landing/index.html", "artifacts/smoke-complete-pack/landing/og-card.png"]
' "$ARTIFACT_FAKE_PASS/controls.json" "$ARTIFACT_FAKE_PASS/results.json"
grep -q 'artifacts/smoke-complete-pack/landing/index.html' "$ARTIFACT_FAKE_PASS/artifact-manifest.txt" || fail "artifact runner manifest omitted the retained page"
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
ruby "$ARTIFACT_ARCHIVE_FIXTURE/scripts/validate-evidence.rb" >/dev/null

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

for artifact_failure in empty:FAKE_ARTIFACT_EMPTY outside:FAKE_ARTIFACT_OUTSIDE; do
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
    abort "artifact failure reason was lost" unless result.fetch("artifactError").is_a?(String) && !result.fetch("artifactError").empty?
  ' "$failure_dir/results.json"
done
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
  abort "Grok runner did not transport exact prompt bytes through an opaque private path" unless private_prompt && File.basename(private_prompt) == "#{token}.txt" && File.basename(File.dirname(private_prompt)) == ".prompt-files" && !private_prompt.include?("market-tools-blocked")
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

GROK_BEHAVIOR_BOUNDARY_TAMPERED="$TEST_ROOT/grok-behavior-boundary-tampered"
cp -R "$GROK_BEHAVIOR_FAKE_PASS" "$GROK_BEHAVIOR_BOUNDARY_TAMPERED"
ruby -rjson -e '
  path = ARGV.fetch(0)
  raw = JSON.parse(File.read(path))
  raw["text"] = raw.fetch("text").sub("ZSTACK_FINAL_RESPONSE_V1\n", "")
  File.write(path, JSON.pretty_generate(raw) + "\n")
' "$GROK_BEHAVIOR_BOUNDARY_TAMPERED/logs/market-tools-blocked.json"
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

TEST_HOME="$TEST_ROOT/home"
mkdir -p "$TEST_HOME/.zstack"
printf '%s\n' "$$" > "$TEST_HOME/.zstack/operations.lock"
if HOME="$TEST_HOME" "$INSTALL_FIXTURE/scripts/setup.sh" --hosts agents > "$TEST_ROOT/setup-lock.log" 2>&1; then
  fail "setup ignored an active shared operation lock"
fi
grep -q "Another zstack setup/unlink operation is in progress" "$TEST_ROOT/setup-lock.log" || fail "setup reported the wrong operation-lock failure"
[[ ! -e "$TEST_HOME/.agents" ]] || fail "locked setup changed host roots"
rm -f "$TEST_HOME/.zstack/operations.lock"
pass "setup rejects concurrent setup/unlink mutation"

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
backup_count="$(find "$TEST_HOME/.agents/skills" -maxdepth 1 -name 'z-market-validate.zstack-backup-*' | wc -l | tr -d ' ')"
[[ "$backup_count" -eq 1 ]] || fail "--force did not preserve exactly one backup"
pass "--force preserves conflicting content in a backup"

grep -qF "$INSTALL_FIXTURE|$TEST_HOME/.agents/skills/z-market-validate" "$TEST_HOME/.zstack/links" || fail "setup did not record an installed link"
pass "setup records managed links for safe uninstall"

cp "$TEST_HOME/.zstack/links" "$TEST_ROOT/links.before"
cp "$TEST_HOME/.zstack/root" "$TEST_ROOT/root.before"
printf '%s|%s\n' "$INSTALL_FIXTURE" "$TEST_HOME/missing-project-link" >> "$TEST_HOME/.zstack/links"
printf '%s|%s\n' "$INSTALL_FIXTURE" "${TEST_HOME}/control"$'\t'"link" >> "$TEST_HOME/.zstack/links"
printf '%s\n' $'/tmp/unsafe\033[31m-root' > "$TEST_HOME/.zstack/root"
HOME="$TEST_HOME" "$INSTALL_FIXTURE/scripts/doctor.sh" > "$TEST_ROOT/manifest.log" 2>&1
grep -q "tracked link is missing or no longer a symlink" "$TEST_ROOT/manifest.log" || fail "doctor did not audit a stale manifest entry"
grep -q "install manifest line .* has unsafe path fields" "$TEST_ROOT/manifest.log" || fail "doctor accepted a control character in the install manifest"
grep -q "recorded ZSTACK_ROOT is unsafe" "$TEST_ROOT/manifest.log" || fail "doctor accepted an unsafe root record"
if LC_ALL=C grep -q $'\033' "$TEST_ROOT/manifest.log"; then
  fail "doctor emitted a raw terminal control character from state"
fi
mv "$TEST_ROOT/links.before" "$TEST_HOME/.zstack/links"
mv "$TEST_ROOT/root.before" "$TEST_HOME/.zstack/root"
pass "doctor audits state consistently without emitting unsafe values"

CODEX_HOME_FIXTURE="$TEST_ROOT/codex-home"
mkdir -p "$CODEX_HOME_FIXTURE/.zstack"
printf '%s\n' "stale" > "$CODEX_HOME_FIXTURE/.zstack/operations.lock"
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
pass "setup, unlink, and doctor reject unsafe state leaf files before acting"

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
printf '%s\n' '#!/usr/bin/env bash' 'exit 1' > "$TEST_ROOT/fail-commit-bin/mv"
chmod +x "$TEST_ROOT/fail-commit-bin/mv"
if PATH="$TEST_ROOT/fail-commit-bin:$PATH" HOME="$COMMIT_HOME" "$COMMIT_FIXTURE/scripts/setup.sh" --hosts agents > "$TEST_ROOT/manifest-commit.log" 2>&1; then
  fail "setup reported success after manifest commit failure"
fi
[[ -L "$COMMIT_HOME/.agents/skills/z-market-validate" ]] || fail "manifest failure unexpectedly rolled back a valid link"
[[ ! -e "$COMMIT_HOME/.zstack/operations.lock" ]] || fail "manifest failure left the operation lock"
[[ ! -e "$COMMIT_HOME/.zstack/links" ]] || fail "manifest failure published a partial link manifest"
commit_temps="$(find "$COMMIT_HOME/.zstack" -maxdepth 1 \( -name '*.pending.*' -o -name '*.next.*' \) -print | wc -l | tr -d ' ')"
[[ "$commit_temps" -eq 0 ]] || fail "manifest failure left transaction files"

HOME="$COMMIT_HOME" "$COMMIT_FIXTURE/scripts/setup.sh" --hosts agents >/dev/null
commit_manifest_count="$(awk -F'|' -v root="$COMMIT_FIXTURE" '$1 == root {count++} END {print count + 0}' "$COMMIT_HOME/.zstack/links")"
[[ "$commit_manifest_count" -eq 5 ]] || fail "setup did not recover and register existing links after manifest failure"
HOME="$COMMIT_HOME" "$COMMIT_FIXTURE/scripts/unlink.sh" >/dev/null
pass "setup cleans failed manifest transactions and recovers on the next run"

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
rm -f "$VALIDATION_FIXTURE/evals/leak.txt"

printf '%s\n' '[broken](missing-file.md)' > "$VALIDATION_FIXTURE/evals/broken-link.md"
if "$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only --fail-fast > "$TEST_ROOT/markdown-link.log" 2>&1; then
  fail "doctor accepted a broken link in unignored Markdown"
fi
grep -q "broken local Markdown link in evals/broken-link.md" "$TEST_ROOT/markdown-link.log" || fail "doctor reported the wrong Markdown-link failure"
rm -f "$VALIDATION_FIXTURE/evals/broken-link.md"
pass "doctor checks Markdown links in commit candidates"

printf 'ghp_%020d\n' 0 > "$VALIDATION_FIXTURE/.env"
mkdir -p "$VALIDATION_FIXTURE/.gstack"
printf '%s\n' '[ignored broken link](missing-file.md)' > "$VALIDATION_FIXTURE/.gstack/ignored.md"
"$VALIDATION_FIXTURE/scripts/doctor.sh" --source-only >/dev/null || fail "doctor scanned Git-ignored local content"
pass "doctor skips ignored local secrets and Markdown"

EVIDENCE_FIXTURE="$TEST_ROOT/evidence-validation"
mkdir -p "$EVIDENCE_FIXTURE/scripts/lib" "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/raw"
cp "$ROOT/scripts/validate-evidence.rb" "$EVIDENCE_FIXTURE/scripts/validate-evidence.rb"
cp "$ROOT/scripts/generate-evidence-manifests.rb" "$EVIDENCE_FIXTURE/scripts/generate-evidence-manifests.rb"
cp "$ROOT/scripts/lib/eval_public_text.rb" "$EVIDENCE_FIXTURE/scripts/lib/eval_public_text.rb"
printf '%s\n' 'version: 1' 'cases:' '  - id: example-case' > "$EVIDENCE_FIXTURE/evals/cases.yaml"
printf '%s\n' 'version: 1' 'cases:' '  - id: example-route' > "$EVIDENCE_FIXTURE/evals/routing.yaml"
printf '%s\n' '# Prompt' > "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/prompts.md"
printf '%s\n' '# Summary' > "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/summary.md"
printf '%s\n' '{"schemaVersion":2,"archiveDate":"2026-01-01","suite":"behavioral","host":{"name":"Example","version":"1.0"},"provenance":{"status":"complete","gaps":[]},"runs":[{"id":"baseline","case":"example-case","phase":"baseline","model":"example-model","workspace":"temporary directory","permissions":"writes limited to temporary directory","webSearch":false,"subagents":false,"maxTurns":1,"stopStatus":"stop","grade":"pass","artifacts":["response.md"]}],"runnerIncidents":[]}' > "$EVIDENCE_FIXTURE/evals/runs/2026-01-01-example/run.json"
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

TRANSACTION_FIXTURE="$(copy_fixture scaffold-rollback)"
cp "$TRANSACTION_FIXTURE/catalog.yaml" "$TEST_ROOT/transaction-catalog.before"
mkdir -p "$TEST_ROOT/fail-mv-bin"
# These single-quoted lines are the source of the generated fault-injection shim.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'count=0' \
  '[[ -f "$MV_STATE_FILE" ]] && read -r count < "$MV_STATE_FILE"' \
  'count=$((count + 1))' \
  'printf "%s\\n" "$count" > "$MV_STATE_FILE"' \
  '[[ "$count" -eq 2 ]] && exit 1' \
  'exec "$REAL_MV_BIN" "$@"' > "$TEST_ROOT/fail-mv-bin/mv"
chmod +x "$TEST_ROOT/fail-mv-bin/mv"
if PATH="$TEST_ROOT/fail-mv-bin:$PATH" MV_STATE_FILE="$TEST_ROOT/mv-state" REAL_MV_BIN="$(command -v mv)" \
  "$TRANSACTION_FIXTURE/scripts/new-skill.sh" z-rollback-test product > "$TEST_ROOT/scaffold-rollback.log" 2>&1; then
  fail "new-skill reported success after catalog replacement failure"
fi
cmp -s "$TEST_ROOT/transaction-catalog.before" "$TRANSACTION_FIXTURE/catalog.yaml" || fail "new-skill did not restore catalog after replacement failure"
[[ ! -e "$TRANSACTION_FIXTURE/skills/z-rollback-test" ]] || fail "new-skill left a partial skill after replacement failure"
[[ ! -e "$TRANSACTION_FIXTURE/.zstack-new-skill.lock" ]] || fail "new-skill left its transaction lock"
transaction_temps="$(find "$TRANSACTION_FIXTURE" -maxdepth 1 -name '.zstack-new-skill.*' ! -name '.zstack-new-skill.lock' | wc -l | tr -d ' ')"
[[ "$transaction_temps" -eq 0 ]] || fail "new-skill left transaction files"
pass "new-skill rolls back a failed catalog replacement"

if "$TRANSACTION_FIXTURE/scripts/new-skill.sh" z-too-many product extra > "$TEST_ROOT/scaffold-args.log" 2>&1; then
  fail "new-skill accepted extra positional arguments"
fi
cmp -s "$TEST_ROOT/transaction-catalog.before" "$TRANSACTION_FIXTURE/catalog.yaml" || fail "invalid arguments changed catalog.yaml"

mkdir "$TRANSACTION_FIXTURE/.zstack-new-skill.lock"
printf '%s\n' "$$" > "$TRANSACTION_FIXTURE/.zstack-new-skill.lock/pid"
if "$TRANSACTION_FIXTURE/scripts/new-skill.sh" z-lock-test product > "$TEST_ROOT/scaffold-lock.log" 2>&1; then
  fail "new-skill ignored an active transaction lock"
fi
cmp -s "$TEST_ROOT/transaction-catalog.before" "$TRANSACTION_FIXTURE/catalog.yaml" || fail "lock contention changed catalog.yaml"
[[ ! -e "$TRANSACTION_FIXTURE/skills/z-lock-test" ]] || fail "lock contention created a partial skill"
rm -f "$TRANSACTION_FIXTURE/.zstack-new-skill.lock/pid"
rmdir "$TRANSACTION_FIXTURE/.zstack-new-skill.lock"
pass "new-skill rejects concurrent catalog mutation"

mkdir "$TRANSACTION_FIXTURE/.zstack-new-skill.lock"
printf '%s\n' "stale" > "$TRANSACTION_FIXTURE/.zstack-new-skill.lock/pid"
"$TRANSACTION_FIXTURE/scripts/new-skill.sh" z-stale-lock product > "$TEST_ROOT/stale-lock.log" 2>&1
grep -q "Recovered stale new-skill lock" "$TEST_ROOT/stale-lock.log" || fail "new-skill did not report stale-lock recovery"
[[ -f "$TRANSACTION_FIXTURE/skills/z-stale-lock/SKILL.md" ]] || fail "new-skill did not continue after stale-lock recovery"
[[ ! -e "$TRANSACTION_FIXTURE/.zstack-new-skill.lock" ]] || fail "new-skill left a recovered lock behind"
pass "new-skill recovers a stale transaction lock"

echo "All tests passed."
