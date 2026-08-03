#!/usr/bin/env ruby
# Promote a reviewed behavioral-runner directory into an atomic schema-v2 archive.

require "date"
require "digest"
require "fileutils"
require "find"
require "json"
require "optparse"
require "pathname"
require "rbconfig"
require "set"
require "tmpdir"
require "yaml"
require_relative "lib/eval_archive_candidate"
require_relative "lib/eval_archive_lock"
require_relative "lib/eval_archive_name"
require_relative "lib/eval_archive_output"
require_relative "lib/eval_archive_raw_files"
require_relative "lib/eval_bounded_command"
require_relative "lib/eval_codex_home"
require_relative "lib/eval_behavioral_prompt"
require_relative "lib/evidence_handoff_contract"
require_relative "lib/eval_host_contracts"
require_relative "lib/eval_input_file"
require_relative "lib/eval_limits"
require_relative "lib/eval_owned_directory"
require_relative "lib/eval_private_paths"
require_relative "lib/eval_process_supervisor"
require_relative "lib/eval_public_text"
require_relative "lib/eval_source_snapshot"
require_relative "lib/eval_strict_json"
require_relative "lib/eval_strict_yaml"

ROOT = File.expand_path("..", __dir__)
RUNS_ROOT = File.join(ROOT, "evals", "runs")
CASES_PATH = File.join(ROOT, "evals", "cases.yaml")
HOST_FAMILY = ENV.fetch("ZSTACK_BEHAVIORAL_HOST", "")
HOST_NAMES = { "codex" => "Codex CLI", "claude" => "Claude Code", "grok" => "Grok Build" }.freeze
EXPECTED_HOST = HOST_NAMES[HOST_FAMILY]
raise "set ZSTACK_BEHAVIORAL_HOST to codex, claude, or grok" unless EXPECTED_HOST
ARCHIVE_MANIFEST_SCRIPT = File.join(ROOT, "scripts", "generate-evidence-manifests.rb")
EVIDENCE_VALIDATOR = File.join(ROOT, "scripts", "validate-evidence.rb")
RAW_MANIFEST_HEADER = "sha256                                                            bytes  path"
EXECUTION_MODES = %w[response artifact].freeze
STRUCTURED_HOSTS = %w[claude grok].freeze
EVAL_HOST_CONTRACTS = Zstack::EvalHostContracts
EVAL_ARCHIVE_CANDIDATE = Zstack::EvalArchiveCandidate
EVAL_ARCHIVE_NAME = Zstack::EvalArchiveName
EVAL_ARCHIVE_OUTPUT = Zstack::EvalArchiveOutput
EVAL_ARCHIVE_RAW_FILES = Zstack::EvalArchiveRawFiles
EVAL_CODEX_HOME = Zstack::EvalCodexHome
EVAL_BEHAVIORAL_PROMPT = Zstack::EvalBehavioralPrompt
EVAL_BOUNDED_COMMAND = Zstack::EvalBoundedCommand
EVAL_PRIVATE_PATHS = Zstack::EvalPrivatePaths
EVAL_PROCESS_SUPERVISOR = Zstack::EvalProcessSupervisor
EVAL_PUBLIC_TEXT = Zstack::EvalPublicText
EVIDENCE_HANDOFF_CONTRACT = Zstack::EvidenceHandoffContract
GROK_SYSTEM_PROMPT = EVAL_HOST_CONTRACTS.grok_system_prompt("behavioral")
GROK_ISOLATED_CONFIG = EVAL_HOST_CONTRACTS::GROK_ISOLATED_CONFIG
GROK_FINAL_MARKER = EVAL_HOST_CONTRACTS::GROK_FINAL_MARKER
GROK_PROMPT_PATH = EVAL_HOST_CONTRACTS::GROK_PROMPT_PATH
REQUIRED_DISABLED_FEATURES = %w[
  multi_agent
  multi_agent_v2
  browser_use
  in_app_browser
  computer_use
  apps
  skill_search
  plugins
  remote_plugin
  plugin_sharing
  hooks
  memories
  skill_mcp_dependency_install
  workspace_dependencies
  goals
  tool_suggest
].freeze
REQUIRED_RESULT_FIELDS = %w[
  id
  skill
  completed
  exitStatus
  elapsedSeconds
  timedOut
  outputLimited
  workspaceLimitError
  hostOutputBytes
  promptPath
  responsePath
  logPath
  executionMode
  artifactPaths
  artifactError
  responsePrivacyError
  responseFileError
  evidenceHandoffContract
  grade
].freeze

def fail_usage(message, parser = nil)
  warn "ERROR: #{message}"
  warn parser if parser
  exit 2
end

def load_json(source_snapshot, path)
  data = Zstack::EvalStrictJson.parse(source_snapshot.read_text(path))
  raise "#{path}: JSON root must be an object or array" unless data.is_a?(Hash) || data.is_a?(Array)
  raise "#{path}: JSON contains a non-finite number" unless Zstack::EvalLimits.finite_json_value?(data)

  data
rescue Errno::ENOENT, JSON::ParserError => e
  raise "cannot load #{path}: #{e.message}"
end

def load_behavioral_cases
  content = Zstack::EvalInputFile.read(
    CASES_PATH,
    label: "evals/cases.yaml",
    root: ROOT
  )
  document = Zstack::EvalStrictYaml.parse(
    content,
    CASES_PATH
  )
  contract_must = Array(document.fetch("contract_must"))
  raise "evals/cases.yaml has no contract_must criteria" if contract_must.empty?
  unless contract_must.include?(EVIDENCE_HANDOFF_CONTRACT::CRITERION)
    raise "evals/cases.yaml is missing the mechanical Evidence handoff criterion"
  end
  cases = Array(document.fetch("cases")).to_h do |entry|
    merged = entry.merge("must" => contract_must + Array(entry["must"]))
    [merged.fetch("id"), merged]
  end
  [cases, content]
rescue Errno::ENOENT, KeyError, Psych::Exception => e
  raise "cannot load evals/cases.yaml: #{e.message}"
end

def execution_mode(entry)
  entry.fetch("execution", "response")
end

def regular_source_file(source_snapshot, relative_path)
  source_snapshot.capture(relative_path)
end

def validate_controls!(controls, result_ids)
  required = {
    "host" => String,
    "hostVersion" => String,
    "model" => String,
    "reasoningEffort" => String,
    "sandbox" => String,
    "approvalPolicy" => String,
    "cases" => Array
  }
  required.each do |field, type|
    value = controls[field]
    raise "controls.json: #{field} must be a non-empty #{type}" unless value.is_a?(type) && (!value.respond_to?(:empty?) || !value.empty?)
  end
  raise "controls.json: host must be #{EXPECTED_HOST}" unless controls["host"] == EXPECTED_HOST
  raise "controls.json: dryRun must be false" unless controls["dryRun"] == false
  raise "controls.json: ephemeralSession must be true" unless controls["ephemeralSession"] == true
  unless controls["timeoutSecondsPerCase"].is_a?(Integer) &&
         controls["timeoutSecondsPerCase"].between?(1, Zstack::EvalLimits::MAX_RUNNER_TIMEOUT_SECONDS)
    raise "controls.json: timeoutSecondsPerCase is outside the runner safety limit"
  end
  unless controls["jobs"].is_a?(Integer) && controls["jobs"].between?(1, Zstack::EvalLimits::MAX_RUNNER_JOBS)
    raise "controls.json: jobs is outside the runner safety limit"
  end
  unless controls["maxCasesPerRun"] == Zstack::EvalLimits::MAX_RUNNER_CASES &&
         result_ids.length <= Zstack::EvalLimits::MAX_RUNNER_CASES
    raise "controls.json: case count exceeds the runner safety limit"
  end
  unless controls["maxHostOutputBytesPerCase"] == Zstack::EvalProcessSupervisor::MAX_HOST_OUTPUT_BYTES
    raise "controls.json: maxHostOutputBytesPerCase must match the runner safety limit"
  end
  unless controls["maxPromptBytesPerCase"] == Zstack::EvalLimits::MAX_PROMPT_BYTES &&
         controls["maxPromptBytesPerRun"] == Zstack::EvalLimits::MAX_RUN_PROMPT_BYTES &&
         controls["promptBytes"].is_a?(Integer) &&
         controls["promptBytes"].between?(1, Zstack::EvalLimits::MAX_RUN_PROMPT_BYTES)
    raise "controls.json: prompt byte limits must match the runner safety limits"
  end
  unless controls["runtimeTreeMonitoring"] == true &&
         controls["concurrentRuntimeMonitoring"] == true &&
         controls["pidMonitoringStartsAtSpawn"] == true &&
         controls["sharedRootMonitoring"] == true &&
         controls["privatePromptIntegrityMonitoring"] == (HOST_FAMILY == "grok") &&
         controls["outputDirectoryIdentityMonitoring"] == true &&
         controls["outputTreeMonitoring"] == true &&
         controls["exclusiveRunnerOutputs"] == true &&
         controls["workspaceViolationStopsRun"] == true &&
         controls["copiedSkillIntegrityMonitoring"] == true &&
         controls["anonymousPromptDescriptor"] == true &&
         controls["singleLinkInputFiles"] == true &&
         controls["singleLinkRuntimeFiles"] == true &&
         controls["maxRuntimeOutputFiles"] == Zstack::EvalLimits::MAX_RUNTIME_OUTPUT_FILES &&
         controls["maxRuntimeOutputTreeEntries"] == Zstack::EvalLimits::MAX_RUNTIME_OUTPUT_TREE_ENTRIES &&
         controls["maxRuntimeOutputBytes"] == Zstack::EvalLimits::MAX_RUNTIME_OUTPUT_BYTES &&
         controls["maxRuntimeGitFiles"] == Zstack::EvalLimits::MAX_RUNTIME_GIT_FILES &&
         controls["maxRuntimeGitTreeEntries"] == Zstack::EvalLimits::MAX_RUNTIME_GIT_TREE_ENTRIES &&
         controls["maxRuntimeGitBytes"] == Zstack::EvalLimits::MAX_RUNTIME_GIT_BYTES &&
         controls["maxRuntimeHostHomeFiles"] == Zstack::EvalLimits::MAX_RUNTIME_HOST_HOME_FILES &&
         controls["maxRuntimeHostHomeTreeEntries"] == Zstack::EvalLimits::MAX_RUNTIME_HOST_HOME_TREE_ENTRIES &&
         controls["maxRuntimeHostHomeBytes"] == Zstack::EvalLimits::MAX_RUNTIME_HOST_HOME_BYTES
    raise "controls.json: runtime tree limits must match the runner safety limits"
  end
  expected_transport = HOST_FAMILY == "grok" ? "generated prompt through anonymous descriptor" : "generated prompt through stdin"
  raise "controls.json: prompt transport changed" unless controls["promptTransport"] == expected_transport
  if HOST_FAMILY == "grok" && controls["promptDescriptorPath"] != GROK_PROMPT_PATH
    raise "controls.json: Grok prompt descriptor path changed"
  end
  unless controls["privateCaseIdentifiers"] == EVAL_PRIVATE_PATHS::STRATEGY
    raise "controls.json: private case-identifier strategy changed"
  end
  raise "controls.json: skillSource must identify exact snapshots" unless controls["skillSource"] == "exact copied source snapshots"
  raise "controls.json: webSearch must be false" unless controls["webSearch"] == false
  raise "controls.json: subagents must be false" unless controls["subagents"] == false
  raise "controls.json: grading boundary changed" unless controls["grading"] == "not performed by runner"
  raise "controls.json: executionMode must be present" unless controls.key?("executionMode")
  mode = controls.fetch("executionMode")
  raise "controls.json: executionMode must be response or artifact" unless EXECUTION_MODES.include?(mode)
  raise "controls.json: artifactCapture does not match executionMode" unless controls["artifactCapture"] == (mode == "artifact")
  if mode == "artifact"
    unless controls["writeBoundary"] == "artifacts/ only; audited after execution"
      raise "controls.json: artifact write boundary changed"
    end
    unless controls["maxArtifactFilesPerCase"] == Zstack::EvalLimits::MAX_ARTIFACT_FILES &&
           controls["maxArtifactFileBytes"] == Zstack::EvalLimits::MAX_RETAINED_FILE_BYTES &&
           controls["maxArtifactBytesPerCase"] == Zstack::EvalLimits::MAX_ARTIFACT_BYTES &&
           controls["maxArtifactTreeEntriesPerCase"] == Zstack::EvalLimits::MAX_ARTIFACT_TREE_ENTRIES &&
           controls["maxArtifactFilesPerRun"] == Zstack::EvalLimits::MAX_RUN_ARTIFACT_FILES &&
           controls["maxArtifactBytesPerRun"] == Zstack::EvalLimits::MAX_RUN_ARTIFACT_BYTES &&
           controls["maxArtifactJobs"] == Zstack::EvalLimits::MAX_ARTIFACT_RUNNER_JOBS &&
           controls["artifactRuntimeMonitoring"] == true &&
           controls["artifactManifestFromCapturedBytes"] == true
      raise "controls.json: artifact limits must match the runner safety limits"
    end
  end
  if HOST_FAMILY == "codex"
    expected_sandbox = mode == "artifact" ? "workspace-write" : "read-only"
    raise "controls.json: sandbox must be #{expected_sandbox}" unless controls["sandbox"] == expected_sandbox
    raise "controls.json: approvalPolicy must be never" unless controls["approvalPolicy"] == "never"
    raise "controls.json: ignoreUserConfig must be true" unless controls["ignoreUserConfig"] == true
    raise "controls.json: ignoreRules must be true" unless controls["ignoreRules"] == true
    raise "controls.json: Codex host home must be isolated" unless controls["isolatedHostHome"] == true
    unless controls["ambientDesktopContextDisabled"] == EVAL_CODEX_HOME::AMBIENT_CONTEXT_KEYS
      raise "controls.json: Codex ambient desktop context controls changed"
    end
    disabled = controls["disabledFeatures"]
    raise "controls.json: disabledFeatures must be a non-empty Array" unless disabled.is_a?(Array) && !disabled.empty?
    missing_features = REQUIRED_DISABLED_FEATURES - disabled
    raise "controls.json: required disabled features are missing: #{missing_features.join(", ")}" unless missing_features.empty?
  elsif HOST_FAMILY == "claude"
    expected_sandbox = mode == "artifact" ? "workspace-write" : "Read tool only"
    expected_tools = mode == "artifact" ? %w[Read Write Edit] : ["Read"]
    raise "controls.json: Claude sandbox does not match executionMode" unless controls["sandbox"] == expected_sandbox
    raise "controls.json: Claude approval policy must be dontAsk" unless controls["approvalPolicy"] == "dontAsk"
    raise "controls.json: Claude safeMode must be true" unless controls["safeMode"] == true
    raise "controls.json: Claude customizations must be disabled" unless controls["customizationsDisabled"] == true
    raise "controls.json: Claude provider-config disclosure is missing" unless controls["hostProviderConfigMayApply"] == true
    raise "controls.json: Claude allowedTools do not match executionMode" unless controls["allowedTools"] == expected_tools
    raise "controls.json: Claude Chrome must be disabled" unless controls["chrome"] == false
    raise "controls.json: Claude MCP servers must be disabled" unless controls["mcpServers"] == false
    raise "controls.json: Claude session persistence must be disabled" unless controls["sessionPersistence"] == false
    unless Zstack::EvalLimits.finite_positive_number?(controls["maxBudgetUsdPerCase"])
      raise "controls.json: Claude maxBudgetUsdPerCase must be finite and positive"
    end
    raise "controls.json: Claude resultFormat must be json" unless controls["resultFormat"] == "json"
  else
    expected_sandbox = mode == "artifact" ? "workspace" : "read-only"
    expected_tools = mode == "artifact" ? %w[Read Write Edit] : ["Read"]
    raise "controls.json: Grok sandbox does not match executionMode" unless controls["sandbox"] == expected_sandbox
    expected_approval = mode == "artifact" ? "bypassPermissions" : "dontAsk"
    raise "controls.json: Grok approval policy must be #{expected_approval}" unless controls["approvalPolicy"] == expected_approval
    raise "controls.json: Grok allowedTools do not match executionMode" unless controls["allowedTools"] == expected_tools
    raise "controls.json: Grok system prompt override changed" unless controls["systemPromptOverride"] == GROK_SYSTEM_PROMPT
    raise "controls.json: Grok final-response boundary changed" unless controls["finalResponseBoundary"] == GROK_FINAL_MARKER
    raise "controls.json: Grok host home must be isolated" unless controls["isolatedHostHome"] == true
    unless controls["isolatedHostConfigSha256"] == Digest::SHA256.hexdigest(GROK_ISOLATED_CONFIG)
      raise "controls.json: Grok isolated host config changed"
    end
    unless controls["foreignCompatibilityDisabled"] == %w[claude cursor codex-sessions]
      raise "controls.json: Grok foreign compatibility controls changed"
    end
    raise "controls.json: Grok ambient Agent Skills disclosure is missing" unless controls["ambientAgentSkillsMayBeDiscovered"] == true
    raise "controls.json: Grok provider-config disclosure is missing" unless controls["hostProviderConfigMayApply"] == true
    raise "controls.json: Grok MCP tools must be excluded" unless controls["mcpToolsAllowed"] == false
    raise "controls.json: Grok managed MCP must be disabled" unless controls["managedMcpDisabled"] == true
    raise "controls.json: Grok marketplace auto-registration must be disabled" unless controls["officialMarketplaceAutoRegister"] == false
    raise "controls.json: Grok memory must be disabled" unless controls["memory"] == false
    raise "controls.json: Grok plan mode must be disabled" unless controls["planMode"] == false
    raise "controls.json: Grok prompt must be verbatim" unless controls["verbatimPrompt"] == true
    raise "controls.json: Grok session persistence must be disabled" unless controls["sessionPersistence"] == false
    unless controls["maxTurnsPerCase"].is_a?(Integer) &&
           controls["maxTurnsPerCase"].between?(1, Zstack::EvalLimits::MAX_GROK_TURNS)
      raise "controls.json: Grok maxTurnsPerCase is outside the runner safety limit"
    end
    raise "controls.json: Grok resultFormat must be json" unless controls["resultFormat"] == "json"
  end
  raise "controls.json: cases must exactly match results.json order" unless controls.fetch("cases") == result_ids
end

def expected_prompt(entry)
  EVAL_BEHAVIORAL_PROMPT.build(entry)
end

def validate_review!(review, results, cases)
  raise "review.json must contain an object" unless review.is_a?(Hash)
  raise "review.json: schemaVersion must equal 1" unless review["schemaVersion"] == 1
  reviewer = review["reviewer"]
  raise "review.json: reviewer must be a non-empty public label" unless reviewer.is_a?(String) && !reviewer.strip.empty?
  if EVAL_PUBLIC_TEXT.machine_local_path?(reviewer)
    raise "review.json: reviewer must not contain a machine-local path"
  end
  reviews = review["cases"]
  raise "review.json: cases must be a non-empty array" unless reviews.is_a?(Array) && !reviews.empty?
  result_ids = results.map { |entry| entry.fetch("id") }
  raise "review.json: case order must match results.json" unless reviews.map { |entry| entry["id"] } == result_ids

  reviews.each do |entry|
    id = entry.fetch("id")
    registered = cases.fetch(id)
    raise "#{id}: review skill does not match evals/cases.yaml" unless entry["skill"] == registered.fetch("skill")
    grade = entry["grade"]
    raise "#{id}: review grade must be pass or fail" unless %w[pass fail].include?(grade)
    expected = registered.fetch("must").map { |criterion| ["present", criterion] }
    expected.concat(registered.fetch("must_not").map { |criterion| ["absent", criterion] })
    criteria = entry["criteria"]
    raise "#{id}: review criteria must exactly match evals/cases.yaml" unless criteria.is_a?(Array) && criteria.map { |item| [item["expectation"], item["criterion"]] } == expected
    criteria.each_with_index do |criterion, index|
      observed = criterion["observed"]
      evidence = criterion["evidence"]
      raise "#{id}: criterion #{index + 1} observed must be true or false" unless [true, false].include?(observed)
      raise "#{id}: criterion #{index + 1} needs concise evidence" unless evidence.is_a?(String) && !evidence.strip.empty?
      if EVAL_PUBLIC_TEXT.machine_local_path?(evidence)
        raise "#{id}: criterion #{index + 1} evidence must not contain a machine-local path"
      end
    end
    mismatches = criteria.select do |criterion|
      criterion.fetch("expectation") == "present" ? criterion.fetch("observed") != true : criterion.fetch("observed") != false
    end
    if grade == "pass" && !mismatches.empty?
      raise "#{id}: pass grade conflicts with observed criteria"
    elsif grade == "fail" && mismatches.empty?
      raise "#{id}: fail grade needs at least one observed criterion mismatch"
    end
  end
  reviews
end

def current_skill_file_inventory!(skill)
  current_root = File.join(ROOT, "skills", skill)
  root_stat = File.lstat(current_root)
  unless root_stat.directory? && !root_stat.symlink?
    raise "current skill source is not a real directory: #{skill}"
  end

  files = []
  entries = 0
  Find.find(current_root) do |path|
    next if path == current_root

    entries += 1
    if entries > Zstack::EvalLimits::MAX_SKILL_TREE_ENTRIES
      raise "current skill source exceeds #{Zstack::EvalLimits::MAX_SKILL_TREE_ENTRIES} tree entries: #{skill}"
    end
    stat = File.lstat(path)
    relative = Pathname.new(path).relative_path_from(Pathname.new(current_root)).to_s
    raise "current skill source contains a symbolic link: skills/#{skill}/#{relative}" if stat.symlink?
    next if stat.directory?
    unless stat.file?
      raise "current skill source contains a special file: skills/#{skill}/#{relative}"
    end

    files << relative
    if files.length > Zstack::EvalLimits::MAX_SKILL_FILES
      raise "current skill source exceeds #{Zstack::EvalLimits::MAX_SKILL_FILES} files: #{skill}"
    end
  end
  files.sort
rescue SystemCallError => e
  raise "current skill source could not be enumerated safely: #{skill}: #{e.class}"
end

def capture_current_skill_state!(skill)
  inventory = current_skill_file_inventory!(skill)
  total_bytes = 0
  state = inventory.to_h do |relative|
    path = File.join(ROOT, "skills", skill, relative)
    content = Zstack::EvalInputFile.read(
      path,
      label: "skills/#{skill}/#{relative}",
      require_utf8: false,
      root: ROOT
    )
    total_bytes += content.bytesize
    if total_bytes > Zstack::EvalLimits::MAX_SKILL_BYTES
      raise "current skill source exceeds #{Zstack::EvalLimits::MAX_SKILL_BYTES} bytes: #{skill}"
    end
    [relative, [content.bytesize, Digest::SHA256.hexdigest(content)]]
  end
  unless current_skill_file_inventory!(skill) == inventory
    raise "current skill file inventory changed while it was captured: #{skill}"
  end

  state
end

def capture_current_skill_states!(skills)
  total_files = 0
  total_bytes = 0
  states = skills.to_h do |skill|
    state = capture_current_skill_state!(skill)
    total_files += state.length
    total_bytes += state.values.sum(&:first)
    if total_files > Zstack::EvalLimits::MAX_ARCHIVER_SOURCE_FILES
      raise "current skill sources exceed #{Zstack::EvalLimits::MAX_ARCHIVER_SOURCE_FILES} files"
    end
    if total_bytes > Zstack::EvalLimits::MAX_ARCHIVER_SOURCE_BYTES
      raise "current skill sources exceed #{Zstack::EvalLimits::MAX_ARCHIVER_SOURCE_BYTES} bytes"
    end
    [skill, state]
  end
  states
end

def assert_behavioral_sources_unchanged!(expected_cases_content, expected_skill_states)
  current_cases_content = Zstack::EvalInputFile.read(
    CASES_PATH,
    label: "evals/cases.yaml",
    root: ROOT
  )
  unless current_cases_content == expected_cases_content
    raise "evals/cases.yaml changed while archive was being prepared"
  end

  current_skill_states = capture_current_skill_states!(expected_skill_states.keys)
  expected_skill_states.each do |skill, expected_state|
    next if current_skill_states.fetch(skill) == expected_state

    raise "current skill source changed while archive was being prepared: #{skill}"
  end
end

def validate_snapshot!(source_snapshot, selected_skills)
  run_directory = source_snapshot.run_directory
  manifest_path = regular_source_file(source_snapshot, "skill-snapshot-manifest.txt")
  lines = source_snapshot.read_text(manifest_path).lines.map(&:chomp)
  raise "skill snapshot manifest has the wrong header" unless lines.shift == RAW_MANIFEST_HEADER
  current_skill_states = capture_current_skill_states!(selected_skills)
  listed = Set.new
  snapshot_files = []
  lines.each_with_index do |line, index|
    match = line.match(/\A([0-9a-f]{64})[[:space:]]+(\d+)[[:space:]]+(skill-snapshots\/(z-[a-z0-9-]+)\/(.+))\z/)
    raise "skill snapshot manifest line #{index + 2} is invalid" unless match
    digest, bytes, relative, skill, source_relative = match.captures
    raise "skill snapshot manifest includes an unselected skill: #{skill}" unless selected_skills.include?(skill)
    raise "skill snapshot manifest duplicates #{relative}" if listed.include?(relative)
    listed << relative
    snapshot_path = regular_source_file(source_snapshot, relative)
    snapshot_content = source_snapshot.read(snapshot_path)
    raise "snapshot byte count changed: #{relative}" unless snapshot_content.bytesize == bytes.to_i
    raise "snapshot digest changed: #{relative}" unless Digest::SHA256.hexdigest(snapshot_content) == digest
    current_state = current_skill_states.fetch(skill)[source_relative]
    raise "current skill source is missing: skills/#{skill}/#{source_relative}" unless current_state
    unless current_state == [bytes.to_i, digest]
      raise "current skill source differs from the reviewed snapshot: skills/#{skill}/#{source_relative}"
    end
    snapshot_files << [relative, snapshot_path, skill]
  end
  actual = selected_skills.flat_map do |skill|
    root = File.join(run_directory, "skill-snapshots", skill)
    raise "skill snapshot directory is missing: #{skill}" unless File.directory?(root) && !File.symlink?(root)
    Dir.glob(File.join(root, "**", "*"), File::FNM_DOTMATCH).select { |path| File.file?(path) }.map do |path|
      Pathname.new(path).relative_path_from(Pathname.new(run_directory)).to_s
    end
  end.to_set
  raise "skill snapshot manifest does not cover every snapshot file" unless actual == listed

  selected_skills.each do |skill|
    snapshot_inventory = snapshot_files.select { |entry| entry[2] == skill }.map do |entry|
      entry[0].delete_prefix("skill-snapshots/#{skill}/")
    end.to_set
    current_inventory = current_skill_states.fetch(skill).keys.to_set
    unless current_inventory == snapshot_inventory
      raise "current skill file inventory differs from the reviewed snapshot: #{skill}"
    end
  end
  [manifest_path, snapshot_files, current_skill_states]
end

def validate_artifacts!(source_snapshot, results, mode)
  run_directory = source_snapshot.run_directory
  if mode == "response"
    results.each do |result|
      paths = result.fetch("artifactPaths", [])
      raise "#{result.fetch("id")}: response case must not retain artifacts" unless paths == []
      raise "#{result.fetch("id")}: response case must not report an artifact error" unless result["artifactError"].nil?
    end
    raise "response run must not contain artifact-manifest.txt" if File.exist?(File.join(run_directory, "artifact-manifest.txt"))
    return [nil, []]
  end

  manifest_path = regular_source_file(source_snapshot, "artifact-manifest.txt")
  lines = source_snapshot.read_text(manifest_path).lines.map(&:chomp)
  raise "artifact manifest has the wrong header" unless lines.shift == RAW_MANIFEST_HEADER
  selected_ids = results.map { |result| result.fetch("id") }
  listed = Set.new
  artifact_files = []
  lines.each_with_index do |line, index|
    match = line.match(/\A([0-9a-f]{64})[[:space:]]+(\d+)[[:space:]]+(artifacts\/([a-z0-9][a-z0-9-]*)\/(.+))\z/)
    raise "artifact manifest line #{index + 2} is invalid" unless match
    digest, bytes, relative, id, = match.captures
    raise "artifact manifest includes an unselected case: #{id}" unless selected_ids.include?(id)
    unless Zstack::EvalLimits.portable_relative_path?(relative)
      raise "artifact manifest path must be canonical portable UTF-8: #{relative.dump}"
    end
    raise "artifact manifest duplicates #{relative}" if listed.include?(relative)
    listed << relative
    path = regular_source_file(source_snapshot, relative)
    artifact_content = source_snapshot.read(path)
    raise "artifact byte count changed: #{relative}" unless artifact_content.bytesize == bytes.to_i
    raise "artifact digest changed: #{relative}" unless Digest::SHA256.hexdigest(artifact_content) == digest
    artifact_files << [relative, path, id]
  end
  raise "artifact manifest contains no files" if artifact_files.empty?
  if artifact_files.length > Zstack::EvalLimits::MAX_RUN_ARTIFACT_FILES
    raise "artifact run exceeds #{Zstack::EvalLimits::MAX_RUN_ARTIFACT_FILES} retained files"
  end
  artifact_bytes = artifact_files.sum { |entry| source_snapshot.bytesize(entry[1]) }
  if artifact_bytes > Zstack::EvalLimits::MAX_RUN_ARTIFACT_BYTES
    raise "artifact run exceeds #{Zstack::EvalLimits::MAX_RUN_ARTIFACT_BYTES} retained bytes"
  end

  actual = Set.new
  selected_ids.each do |id|
    root = File.join(run_directory, "artifacts", id)
    raise "artifact directory is missing: #{id}" unless File.directory?(root) && !File.symlink?(root)
    entries = 0
    Find.find(root) do |path|
      next if path == root
      entries += 1
      if entries > Zstack::EvalLimits::MAX_ARTIFACT_TREE_ENTRIES
        raise "artifact tree exceeds #{Zstack::EvalLimits::MAX_ARTIFACT_TREE_ENTRIES} entries: #{id}"
      end
      relative = Pathname.new(path).relative_path_from(Pathname.new(run_directory)).to_s
      raise "artifact tree contains a symbolic link: #{relative}" if File.symlink?(path)
      actual << relative if File.file?(path)
      unless File.file?(path) || File.directory?(path)
        raise "artifact tree contains a non-regular entry: #{relative}"
      end
    end
  end
  raise "artifact manifest does not cover every artifact file" unless actual == listed

  results.each do |result|
    id = result.fetch("id")
    expected = artifact_files.select { |entry| entry[2] == id }.map { |entry| entry[0] }.sort
    raise "#{id}: artifactPaths must exactly match the artifact manifest" unless result["artifactPaths"] == expected
    raise "#{id}: artifact run must retain at least one file" if expected.empty?
    raise "#{id}: artifactError must be null" unless result["artifactError"].nil?
  end
  [manifest_path, artifact_files]
end

def validate_evidence_handoff_contracts!(source_snapshot, results, artifact_files, reviews)
  review_by_id = reviews.to_h { |entry| [entry.fetch("id"), entry] }
  results.each do |result|
    id = result.fetch("id")
    sources = [{ name: "responses/#{id}.txt", content: source_snapshot.read(result.fetch("responseSource")) }]
    artifact_files.select { |entry| entry[2] == id }.each do |relative, path, _case_id|
      next unless EVIDENCE_HANDOFF_CONTRACT.markdown_source?(relative)

      sources << { name: relative, content: source_snapshot.read(path) }
    end
    observed = EVIDENCE_HANDOFF_CONTRACT.evaluate(sources)
    recorded = result.delete("runnerEvidenceHandoffContract")
    unless recorded.is_a?(Hash) && recorded == observed
      raise "#{id}: recorded Evidence handoff check differs from retained output bytes"
    end

    criterion = review_by_id.fetch(id).fetch("criteria").find do |candidate|
      candidate["expectation"] == "present" && candidate["criterion"] == EVIDENCE_HANDOFF_CONTRACT::CRITERION
    end
    raise "#{id}: review is missing the mechanical Evidence handoff criterion" unless criterion
    unless criterion["observed"] == observed.fetch("passed")
      raise "#{id}: Evidence handoff review contradicts the mechanical output check"
    end
    result["evidenceHandoffContract"] = observed
  end
end

def reject_private_runner_data!(source_snapshot, path)
  content = source_snapshot.read(path)
  if content.match?(/session id:\s*[0-9a-f-]{16,}/in) ||
     content.match?(/zstack-(?:codex|claude|grok)-behavioral-workspaces-/n) ||
     content.match?(/case-[0-9a-f]{32}/n)
    raise "runner artifact contains an ephemeral session id or workspace path: #{path}"
  end
end

def log_field(content, field, case_id)
  match = content.match(/^#{Regexp.escape(field)}:[[:space:]]*(.+?)[[:space:]]*$/)
  raise "#{case_id}: runner log is missing #{field}" unless match
  match[1]
end

def codex_runner_incidents(source_snapshot, results, controls)
  patterns = {
    "state-database fallback" => /state db discrepancy/,
    "Cloudflare MCP OAuth invalid_grant" => /invalid_grant/,
    "installed-skill context-budget warning" => /Skill descriptions were shortened/
  }
  counts = patterns.each_with_object({}) { |(label, _pattern), memo| memo[label] = 0 }
  seen_tokens = Set.new
  results.each do |result|
    id = result.fetch("id")
    content = source_snapshot.read_text(result.fetch("logSource"))
    if content.match?(/^Reading additional input from stdin|^<stdin>$/)
      raise "#{id}: runner log shows additional stdin beyond the generated prompt"
    end
    expected_version = controls.fetch("hostVersion").sub(/\Acodex-cli[[:space:]]+/, "")
    version_match = content.match(/^OpenAI Codex v(.+?)[[:space:]]*$/)
    unless version_match && version_match[1] == expected_version
      raise "#{id}: runner log host version does not match controls.json"
    end
    {
      "model" => controls.fetch("model"),
      "approval" => controls.fetch("approvalPolicy"),
      "sandbox" => controls.fetch("sandbox"),
      "reasoning effort" => controls.fetch("reasoningEffort")
    }.each do |field, expected|
      actual = log_field(content, field, id)
      if field == "sandbox" && expected == "workspace-write"
        actual = actual.sub(/[[:space:]]+\[.*\]\z/, "")
      end
      raise "#{id}: runner log #{field} does not match controls.json" unless actual == expected
    end
    workdir = log_field(content, "workdir", id)
    private_token = File.basename(workdir)
    unless EVAL_PRIVATE_PATHS.token?(private_token) && workdir.include?("zstack-codex-behavioral-workspaces-")
      raise "#{id}: runner log workdir is not the isolated case workspace"
    end
    raise "#{id}: private case token was reused" unless seen_tokens.add?(private_token)
    prompt = source_snapshot.read_text(result.fetch("promptSource")).rstrip
    response = source_snapshot.read_text(result.fetch("responseSource")).strip
    raise "#{id}: runner log does not contain the exact generated prompt" unless content.include?(prompt)
    raise "#{id}: runner log does not contain the retained final response" unless content.include?(response)
    patterns.each { |label, pattern| counts[label] += 1 if content.match?(pattern) }
  end
  ["Cloudflare MCP OAuth invalid_grant", "installed-skill context-budget warning"].each do |label|
    raise "isolated Codex run retained ambient #{label}" unless counts.fetch(label).zero?
  end
  counts.each_with_object([]) do |(label, count), incidents|
    incidents << "#{count}/#{results.length} runner logs contained the #{label}." unless count.zero?
  end
end

def expected_claude_arguments(controls)
  [
    "-p", "--safe-mode", "--no-session-persistence",
    "--permission-mode", "dontAsk", "--tools", controls.fetch("allowedTools").join(","), "--no-chrome",
    "--strict-mcp-config", "--mcp-config", '{"mcpServers":{}}',
    "--input-format", "text", "--output-format", "json",
    "--model", controls.fetch("model"), "--effort", controls.fetch("reasoningEffort"),
    "--max-budget-usd", controls.fetch("maxBudgetUsdPerCase").to_s
  ]
end

def claude_runner_incidents(source_snapshot, results, controls)
  seen_tokens = Set.new
  results.each_with_object([]) do |result, incidents|
    id = result.fetch("id")
    invocation = load_json(source_snapshot, result.fetch("invocationSource"))
    raw = load_json(source_snapshot, result.fetch("rawResultSource"))
    raise "#{id}: private invocation must be an object" unless invocation.is_a?(Hash)
    raise "#{id}: private Claude result must be an object" unless raw.is_a?(Hash)
    raise "#{id}: invocation schemaVersion must equal 2" unless invocation["schemaVersion"] == 2
    raise "#{id}: invocation host must be Claude Code" unless invocation["host"] == "Claude Code"
    executable = invocation["executable"]
    raise "#{id}: invocation executable must be non-empty" unless executable.is_a?(String) && !executable.empty?
    unless invocation["arguments"] == expected_claude_arguments(controls)
      raise "#{id}: invocation arguments do not match the isolated Claude contract"
    end
    workspace = invocation["workspace"]
    private_token = invocation["privateCaseToken"]
    unless EVAL_PRIVATE_PATHS.token?(private_token) && workspace.is_a?(String) &&
           File.basename(workspace) == private_token && workspace.include?("zstack-claude-behavioral-workspaces-")
      raise "#{id}: invocation workspace is not the isolated case workspace"
    end
    raise "#{id}: private case token was reused" unless seen_tokens.add?(private_token)
    prompt = source_snapshot.read(result.fetch("promptSource"))
    unless invocation["promptSha256"] == Digest::SHA256.hexdigest(prompt) && invocation["promptBytes"] == prompt.bytesize
      raise "#{id}: invocation prompt digest or byte count changed"
    end
    raise "#{id}: Claude result type must be result" unless raw["type"] == "result"
    raise "#{id}: Claude result subtype must be success" unless raw["subtype"] == "success"
    raise "#{id}: Claude result is marked as an API error" unless raw["is_error"] == false
    raise "#{id}: isError differs from Claude JSON" unless result["isError"] == raw["is_error"]
    raise "#{id}: subtype differs from Claude JSON" unless result["subtype"] == raw["subtype"]
    response = source_snapshot.read_text(result.fetch("responseSource"))
    raise "#{id}: retained response differs from the Claude JSON result" unless raw["result"] == response
    models = raw.fetch("modelUsage", {})
    raise "#{id}: Claude modelUsage must be a non-empty object" unless models.is_a?(Hash) && !models.empty?
    raise "#{id}: actualModels differs from Claude modelUsage" unless result["actualModels"] == models.keys.sort
    raise "#{id}: Claude run must use exactly one actual model" unless result.fetch("actualModels").length == 1
    raise "#{id}: numTurns differs from Claude JSON" unless result["numTurns"] == raw["num_turns"]
    raise "#{id}: numTurns must be a positive integer" unless result["numTurns"].is_a?(Integer) && result["numTurns"].positive?
    %w[stopReason terminalReason totalCostUsd].each do |field|
      raw_field = { "stopReason" => "stop_reason", "terminalReason" => "terminal_reason", "totalCostUsd" => "total_cost_usd" }.fetch(field)
      raise "#{id}: #{field} differs from Claude JSON" unless result[field] == raw[raw_field]
    end
    unless Zstack::EvalLimits.finite_nonnegative_number?(result["totalCostUsd"])
      raise "#{id}: totalCostUsd must be a finite non-negative number"
    end
    denials = raw.fetch("permission_denials", [])
    raise "#{id}: Claude permission_denials must be an array" unless denials.is_a?(Array)
    raise "#{id}: permissionDenials differs from Claude JSON" unless result["permissionDenials"] == denials.length
    raise "#{id}: Claude run recorded a permission denial" unless denials.empty?
    raise "#{id}: parseError must be null" unless result["parseError"].nil?

    stderr = source_snapshot.read_text(result.fetch("logSource"))
    incidents << "#{id}: Claude wrote #{stderr.bytesize} private stderr bytes." unless stderr.empty?
  end
end

def expected_grok_arguments(controls, prompt_path, workspace)
  [
    "--prompt-file", prompt_path, "--output-format", "json",
    "--model", controls.fetch("model"), "--reasoning-effort", controls.fetch("reasoningEffort"),
    "--disable-web-search", "--no-subagents", "--no-memory", "--no-plan", "--verbatim",
    "--tools", controls.fetch("allowedTools").join(","), "--permission-mode", controls.fetch("approvalPolicy"),
    "--max-turns", controls.fetch("maxTurnsPerCase").to_s, "--cwd", workspace,
    "--sandbox", controls.fetch("sandbox"), "--system-prompt-override", controls.fetch("systemPromptOverride")
  ]
end

def extract_grok_final_response(raw_text, id)
  raise "#{id}: Grok text must be a string" unless raw_text.is_a?(String)

  matches = raw_text.to_enum(:scan, /^#{Regexp.escape(GROK_FINAL_MARKER)}\r?$/).map { Regexp.last_match }
  raise "#{id}: Grok result must contain exactly one final-response marker" unless matches.length == 1

  marker = matches.fetch(0)
  response = raw_text[marker.end(0)..]&.sub(/\A\r?\n/, "")
  raise "#{id}: Grok final response after marker is empty" unless response.is_a?(String) && !response.strip.empty?

  [response, raw_text[0...marker.begin(0)].to_s.bytesize]
end

def grok_runner_incidents(source_snapshot, results, controls)
  seen_tokens = Set.new
  results.each_with_object([]) do |result, incidents|
    id = result.fetch("id")
    invocation = load_json(source_snapshot, result.fetch("invocationSource"))
    raw = load_json(source_snapshot, result.fetch("rawResultSource"))
    raise "#{id}: private invocation must be an object" unless invocation.is_a?(Hash)
    raise "#{id}: private Grok result must be an object" unless raw.is_a?(Hash)
    raise "#{id}: invocation schemaVersion must equal 2" unless invocation["schemaVersion"] == 2
    raise "#{id}: invocation host must be Grok Build" unless invocation["host"] == "Grok Build"
    executable = invocation["executable"]
    raise "#{id}: invocation executable must be non-empty" unless executable.is_a?(String) && !executable.empty?
    workspace = invocation["workspace"]
    private_token = invocation["privateCaseToken"]
    unless EVAL_PRIVATE_PATHS.token?(private_token) && workspace.is_a?(String) &&
           File.basename(workspace) == private_token && workspace.include?("zstack-grok-behavioral-workspaces-")
      raise "#{id}: invocation workspace is not the isolated case workspace"
    end
    raise "#{id}: private case token was reused" unless seen_tokens.add?(private_token)
    arguments = invocation["arguments"]
    raise "#{id}: Grok invocation arguments must be an array" unless arguments.is_a?(Array)
    prompt_indexes = arguments.each_index.select { |index| arguments[index] == "--prompt-file" }
    raise "#{id}: Grok invocation must contain one prompt-file argument" unless prompt_indexes.length == 1
    private_prompt_path = arguments[prompt_indexes.fetch(0) + 1]
    unless private_prompt_path == GROK_PROMPT_PATH
      raise "#{id}: Grok prompt transport must use the inherited anonymous descriptor"
    end
    unless arguments == expected_grok_arguments(controls, private_prompt_path, workspace)
      raise "#{id}: invocation arguments do not match the isolated Grok contract"
    end
    environment = invocation["environment"]
    raise "#{id}: invocation environment must be an object" unless environment.is_a?(Hash)
    unless environment.keys.sort == %w[GROK_AUTH_PATH GROK_HOME GROK_MANAGED_MCPS_ENABLED GROK_OFFICIAL_MARKETPLACE_AUTO_REGISTER]
      raise "#{id}: Grok invocation environment keys changed"
    end
    grok_home = environment["GROK_HOME"]
    unless grok_home.is_a?(String) && File.basename(grok_home) == private_token && File.basename(File.dirname(grok_home)) == ".grok-homes" &&
           File.dirname(File.dirname(grok_home)) == File.dirname(workspace)
      raise "#{id}: Grok home is not isolated beside the case workspace"
    end
    auth_path = environment["GROK_AUTH_PATH"]
    unless auth_path.is_a?(String) && File.dirname(auth_path) == grok_home && File.basename(auth_path) == "auth.json"
      raise "#{id}: Grok auth path must stay inside the isolated Grok home"
    end
    unless environment["GROK_MANAGED_MCPS_ENABLED"] == "0" && environment["GROK_OFFICIAL_MARKETPLACE_AUTO_REGISTER"] == "0"
      raise "#{id}: Grok environment isolation flags changed"
    end
    unless invocation["isolatedConfigSha256"] == Digest::SHA256.hexdigest(GROK_ISOLATED_CONFIG) &&
           invocation["isolatedConfigBytes"] == GROK_ISOLATED_CONFIG.bytesize
      raise "#{id}: Grok isolated config digest or byte count changed"
    end
    prompt = source_snapshot.read(result.fetch("promptSource"))
    unless invocation["promptSha256"] == Digest::SHA256.hexdigest(prompt) && invocation["promptBytes"] == prompt.bytesize
      raise "#{id}: invocation prompt digest or byte count changed"
    end
    raise "#{id}: Grok result is marked as an API error" if raw["type"] == "error"
    raise "#{id}: isError differs from Grok JSON" unless result["isError"] == (raw["type"] == "error")
    raise "#{id}: errorType differs from Grok JSON" unless result["errorType"] == raw["type"]
    response = source_snapshot.read_text(result.fetch("responseSource"))
    extracted_response, prefinal_bytes = extract_grok_final_response(raw["text"], id)
    raise "#{id}: retained response differs from the marked Grok final response" unless extracted_response == response
    raise "#{id}: prefinalNarrationBytes differs from the Grok JSON result" unless result["prefinalNarrationBytes"] == prefinal_bytes
    raise "#{id}: finalBoundaryError must be null" unless result["finalBoundaryError"].nil?
    raise "#{id}: Grok API status must be null for a complete run" unless result["apiErrorStatus"].nil?
    raise "#{id}: Grok error category must be null for a complete run" unless result["errorCategory"].nil?
    models = raw.fetch("modelUsage", {})
    raise "#{id}: Grok modelUsage must be a non-empty object" unless models.is_a?(Hash) && !models.empty?
    raise "#{id}: actualModels differs from Grok modelUsage" unless result["actualModels"] == models.keys.sort
    raise "#{id}: Grok run must use exactly one actual model" unless result.fetch("actualModels").length == 1
    raise "#{id}: numTurns differs from Grok JSON" unless result["numTurns"] == raw["num_turns"]
    unless result["numTurns"].is_a?(Integer) && result["numTurns"].positive? && result["numTurns"] <= controls.fetch("maxTurnsPerCase")
      raise "#{id}: numTurns must be within the configured Grok turn budget"
    end
    raise "#{id}: stopReason differs from Grok JSON" unless result["stopReason"] == raw["stopReason"]
    raise "#{id}: Grok run did not finish with end_turn" unless result["stopReason"] == "end_turn"
    raise "#{id}: totalCostUsd differs from Grok JSON" unless result["totalCostUsd"] == raw["total_cost_usd"]
    unless Zstack::EvalLimits.finite_nonnegative_number?(result["totalCostUsd"])
      raise "#{id}: totalCostUsd must be a finite non-negative number"
    end
    raise "#{id}: tokenUsage differs from Grok JSON" unless result["tokenUsage"] == raw["usage"]
    unless result["tokenUsage"].is_a?(Hash) && Zstack::EvalLimits.nonnegative_finite_json_value?(result["tokenUsage"])
      raise "#{id}: Grok token usage must be an object with finite non-negative numbers"
    end
    raise "#{id}: parseError must be null" unless result["parseError"].nil?

    incidents << "#{id}: discarded #{prefinal_bytes} pre-final narration bytes from private Grok output." if prefinal_bytes.positive?
    stderr = source_snapshot.read_text(result.fetch("logSource"))
    incidents << "#{id}: Grok wrote #{stderr.bytesize} private stderr bytes." unless stderr.empty?
    incidents << "#{id}: Grok attempted MCP startup despite the MCP tool exclusion." if stderr.match?(/MCP server/i)
  end
end

def runner_incidents(source_snapshot, results, controls)
  case HOST_FAMILY
  when "codex" then codex_runner_incidents(source_snapshot, results, controls)
  when "claude" then claude_runner_incidents(source_snapshot, results, controls)
  else grok_runner_incidents(source_snapshot, results, controls)
  end
end

def json_content(data)
  content = JSON.pretty_generate(data)
  content = content.gsub(/\[\n[[:space:]]*\]/, "[]").gsub(/\{\n[[:space:]]*\}/, "{}")
  content + "\n"
end

def run_checked(*command)
  result = EVAL_BOUNDED_COMMAND.capture(
    *command,
    timeout_seconds: Zstack::EvalLimits::EVIDENCE_TOOL_TIMEOUT_SECONDS,
    max_output_bytes: Zstack::EvalLimits::MAX_EVIDENCE_TOOL_OUTPUT_BYTES
  )
  rendered = command.join(" ")
  if result.timed_out
    raise "command timed out after #{Zstack::EvalLimits::EVIDENCE_TOOL_TIMEOUT_SECONDS} seconds: #{rendered}"
  end
  if result.output_limited
    raise "command exceeded #{Zstack::EvalLimits::MAX_EVIDENCE_TOOL_OUTPUT_BYTES} output bytes: #{rendered}"
  end
  return result.stdout.strip if result.status.success?

  detail = [result.stdout, result.stderr].reject(&:empty?).join("\n").strip
  raise "command failed: #{command.join(" ")}#{detail.empty? ? "" : "\n#{detail}"}"
end

def table_cell(value)
  value.to_s.gsub(/\s+/, " ").gsub("|", "\\|").strip
end

options = { archive: nil, phase: nil, run_directory: nil }
parser = OptionParser.new do |opts|
  opts.banner = "Usage: ruby scripts/archive-#{HOST_FAMILY}-behavioral-run.rb --run-dir DIR --archive YYYY-MM-DD-SLUG --phase PHASE"
  opts.on("--run-dir DIR", "Reviewed output from run-#{HOST_FAMILY}-behavioral-evals.rb") { |value| options[:run_directory] = value }
  opts.on("--archive NAME", "New directory name directly under evals/runs") { |value| options[:archive] = value }
  opts.on("--phase PHASE", "Kebab-case phase recorded for every case") { |value| options[:phase] = value }
  opts.on("-h", "--help", "Show help") do
    puts opts
    exit 0
  end
end

begin
  parser.parse!
rescue OptionParser::ParseError => e
  fail_usage(e.message, parser)
end
fail_usage("unexpected positional arguments: #{ARGV.join(" ")}", parser) unless ARGV.empty?
%i[run_directory archive phase].each { |field| fail_usage("--#{field.to_s.tr("_", "-")} is required", parser) unless options[field] }
fail_usage("--archive must use a valid ISO calendar date and YYYY-MM-DD-kebab-slug") unless EVAL_ARCHIVE_NAME.valid_candidate?(options[:archive])
fail_usage("--phase must be kebab-case") unless options[:phase].match?(/\A[a-z0-9][a-z0-9-]*\z/)
archive_date = options[:archive][0, 10]
run_directory = File.expand_path(options[:run_directory])
fail_usage("--run-dir must be a real directory") unless File.directory?(run_directory) && !File.symlink?(run_directory)

temporary_archive = nil
temporary_archive_identity = nil
published_archive = nil
published_archive_identity = nil
source_snapshot = nil
publication_lock = nil
begin
  source_snapshot = Zstack::EvalSourceSnapshot.new(run_directory)
  controls_path = regular_source_file(source_snapshot, "controls.json")
  results_path = regular_source_file(source_snapshot, "results.json")
  review_path = regular_source_file(source_snapshot, "review.json")
  controls = load_json(source_snapshot, controls_path)
  results = load_json(source_snapshot, results_path)
  review = load_json(source_snapshot, review_path)
  raise "controls.json must contain an object" unless controls.is_a?(Hash)
  raise "results.json must contain a non-empty array" unless results.is_a?(Array) && !results.empty?
  raise "results.json entries must be objects" unless results.all? { |entry| entry.is_a?(Hash) }
  result_ids = results.map { |entry| entry["id"] }
  unless result_ids.all? { |id| id.is_a?(String) && id.match?(/\A[a-z0-9][a-z0-9-]*\z/) } && result_ids.uniq.length == result_ids.length
    raise "results.json ids must be unique kebab-case strings"
  end
  validate_controls!(controls, result_ids)
  behavioral_cases, cases_manifest_content = load_behavioral_cases
  reviews = validate_review!(review, results, behavioral_cases)
  review_by_id = reviews.each_with_object({}) { |entry, memo| memo[entry.fetch("id")] = entry }

  normalized_results = results.map do |result|
    id = result.fetch("id")
    missing_fields = REQUIRED_RESULT_FIELDS.reject { |field| result.key?(field) }
    unless missing_fields.empty?
      raise "#{id}: result is missing required fields: #{missing_fields.join(", ")}"
    end
    registered = behavioral_cases[id]
    raise "results.json references unknown behavioral case: #{id}" unless registered
    raise "#{id}: result skill does not match evals/cases.yaml" unless result["skill"] == registered.fetch("skill")
    registered_mode = execution_mode(registered)
    controls_mode = controls.fetch("executionMode")
    result_mode = result.fetch("executionMode")
    unless registered_mode == controls_mode && result_mode == controls_mode
      raise "#{id}: execution mode differs across case, controls, and result"
    end
    unless result["promptPath"] == "prompts/#{id}.txt" && result["responsePath"] == "responses/#{id}.txt" && result["logPath"] == "logs/#{id}.log"
      raise "#{id}: runner paths do not match the canonical output layout"
    end
    prompt_path = regular_source_file(source_snapshot, result.fetch("promptPath"))
    response_path = regular_source_file(source_snapshot, result.fetch("responsePath"))
    log_path = regular_source_file(source_snapshot, result.fetch("logPath"))
    raw_result_path = nil
    invocation_path = nil
    if STRUCTURED_HOSTS.include?(HOST_FAMILY)
      host_result_fields = HOST_FAMILY == "claude" ? EVAL_HOST_CONTRACTS::CLAUDE_RESULT_FIELDS : EVAL_HOST_CONTRACTS::GROK_RESULT_FIELDS
      missing_fields = (%w[rawResultPath invocationPath] + host_result_fields).reject { |field| result.key?(field) }
      unless missing_fields.empty?
        raise "#{id}: structured-host result is missing required fields: #{missing_fields.join(", ")}"
      end
      unless result["rawResultPath"] == "logs/#{id}.json" && result["invocationPath"] == "logs/#{id}.invocation.json"
        raise "#{id}: structured-host private runner paths do not match the canonical output layout"
      end
      raw_result_path = regular_source_file(source_snapshot, result.fetch("rawResultPath"))
      invocation_path = regular_source_file(source_snapshot, result.fetch("invocationPath"))
    end
    unless source_snapshot.read(prompt_path) == expected_prompt(registered).b
      raise "#{id}: prompt differs from the registered case wrapper"
    end
    raise "#{id}: final response is empty" if source_snapshot.read_text(response_path).strip.empty?
    exit_status = result["exitStatus"]
    raise "#{id}: exitStatus must equal 0 for archiving" unless exit_status == 0
    raise "#{id}: completed must be true for archiving" unless result["completed"] == true
    raise "#{id}: timedOut must be false for archiving" unless result["timedOut"] == false
    elapsed_seconds = result["elapsedSeconds"]
    unless Zstack::EvalLimits.finite_nonnegative_number?(elapsed_seconds)
      raise "#{id}: elapsedSeconds must be a finite non-negative number"
    end
    raise "#{id}: runner must leave grade null" unless result["grade"].nil?
    unless result.key?("responsePrivacyError") && result["responsePrivacyError"].nil?
      raise "#{id}: responsePrivacyError must be present and null"
    end
    unless result.key?("responseFileError") && result["responseFileError"].nil?
      raise "#{id}: responseFileError must be present and null"
    end
    normalized = {
      "id" => id,
      "skill" => registered.fetch("skill"),
      "grade" => review_by_id.fetch(id).fetch("grade"),
      "exitStatus" => exit_status,
      "elapsedSeconds" => elapsed_seconds,
      "promptSource" => prompt_path,
      "responseSource" => response_path,
      "logSource" => log_path,
      "executionMode" => result_mode,
      "artifactPaths" => result.fetch("artifactPaths"),
      "artifactError" => result["artifactError"],
      "runnerEvidenceHandoffContract" => result["evidenceHandoffContract"]
    }
    if HOST_FAMILY == "claude"
      EVAL_HOST_CONTRACTS::CLAUDE_RESULT_FIELDS.each do |field|
        normalized[field] = result.fetch(field)
      end
      normalized["rawResultSource"] = raw_result_path
      normalized["invocationSource"] = invocation_path
    elsif HOST_FAMILY == "grok"
      EVAL_HOST_CONTRACTS::GROK_RESULT_FIELDS.each do |field|
        normalized[field] = result.fetch(field)
      end
      normalized["rawResultSource"] = raw_result_path
      normalized["invocationSource"] = invocation_path
    end
    raise "#{id}: outputLimited must be false for archiving" unless result["outputLimited"] == false
    raise "#{id}: workspaceLimitError must be null for archiving" unless result["workspaceLimitError"].nil?
    host_output_bytes = result["hostOutputBytes"]
    unless host_output_bytes.is_a?(Integer) && host_output_bytes >= 0
      raise "#{id}: hostOutputBytes must be a non-negative integer"
    end
    host_output_paths = STRUCTURED_HOSTS.include?(HOST_FAMILY) ? [raw_result_path, log_path] : [log_path, response_path]
    retained_host_output_bytes = host_output_paths.sum { |path| source_snapshot.bytesize(path) }
    unless host_output_bytes == retained_host_output_bytes
      raise "#{id}: hostOutputBytes does not match retained host output"
    end
    if host_output_bytes > EVAL_PROCESS_SUPERVISOR::MAX_HOST_OUTPUT_BYTES
      raise "#{id}: hostOutputBytes exceeds the runner safety limit"
    end
    normalized
  end
  actual_prompt_bytes = normalized_results.sum { |result| source_snapshot.bytesize(result.fetch("promptSource")) }
  raise "controls.json: promptBytes differs from retained prompts" unless controls.fetch("promptBytes") == actual_prompt_bytes
  selected_skills = normalized_results.map { |entry| entry.fetch("skill") }.uniq.sort
  snapshot_manifest, snapshot_files, current_skill_states = validate_snapshot!(source_snapshot, selected_skills)
  artifact_manifest, artifact_files = validate_artifacts!(source_snapshot, normalized_results, controls.fetch("executionMode", "response"))
  validate_evidence_handoff_contracts!(source_snapshot, normalized_results, artifact_files, reviews)
  public_sources = [controls_path, results_path, review_path, snapshot_manifest]
  public_sources << artifact_manifest if artifact_manifest
  public_sources.concat(normalized_results.flat_map { |entry| [entry.fetch("promptSource"), entry.fetch("responseSource")] })
  public_sources.concat(snapshot_files.map { |entry| entry[1] })
  public_sources.concat(artifact_files.map { |entry| entry[1] })
  public_sources.each { |path| reject_private_runner_data!(source_snapshot, path) }
  incidents = runner_incidents(source_snapshot, normalized_results, controls)

  FileUtils.mkdir_p(RUNS_ROOT)
  raise "evals/runs must not be a symbolic link" if File.symlink?(RUNS_ROOT)
  publication_lock = Zstack::EvalArchiveLock.acquire(RUNS_ROOT)
  target = File.join(RUNS_ROOT, options[:archive])
  raise "archive target already exists: #{target}" if File.exist?(target) || File.symlink?(target)
  run_checked(RbConfig.ruby, EVIDENCE_VALIDATOR)

  temporary_archive = Dir.mktmpdir(".zstack-behavioral-archive-", RUNS_ROOT)
  temporary_archive_identity = Zstack::EvalOwnedDirectory.capture(
    temporary_archive,
    label: "behavioral archive transaction directory"
  )
  archive_output = EVAL_ARCHIVE_OUTPUT.new(temporary_archive)
  raw_directory = File.join(temporary_archive, "raw")
  FileUtils.mkdir_p(File.join(raw_directory, "prompts"))
  FileUtils.mkdir_p(File.join(raw_directory, "responses"))
  FileUtils.mkdir_p(File.join(raw_directory, "skill-snapshots"))
  raw_contents = {}
  raw_contents["skill-snapshot-manifest.txt"] = source_snapshot.read(snapshot_manifest)
  source_snapshot.copy(snapshot_manifest, File.join(raw_directory, "skill-snapshot-manifest.txt"))
  snapshot_files.each do |relative, source, _skill|
    snapshot_target = File.join(raw_directory, relative)
    FileUtils.mkdir_p(File.dirname(snapshot_target))
    raw_contents[relative] = source_snapshot.read(source)
    source_snapshot.copy(source, snapshot_target)
  end
  normalized_results.each do |result|
    id = result.fetch("id")
    prompt_relative = "prompts/#{id}.txt"
    response_relative = "responses/#{id}.txt"
    raw_contents[prompt_relative] = source_snapshot.read(result.fetch("promptSource"))
    raw_contents[response_relative] = source_snapshot.read(result.fetch("responseSource"))
    source_snapshot.copy(result.fetch("promptSource"), File.join(raw_directory, prompt_relative))
    source_snapshot.copy(result.fetch("responseSource"), File.join(raw_directory, response_relative))
  end
  if artifact_manifest
    raw_contents["runner-artifact-manifest.txt"] = source_snapshot.read(artifact_manifest)
    source_snapshot.copy(artifact_manifest, File.join(raw_directory, "runner-artifact-manifest.txt"))
    artifact_files.each do |relative, source, _id|
      artifact_target = File.join(raw_directory, relative)
      FileUtils.mkdir_p(File.dirname(artifact_target))
      raw_contents[relative] = source_snapshot.read(source)
      source_snapshot.copy(source, artifact_target)
    end
  end

  prompt_index = [
    "# #{controls.fetch("host")} behavioral prompts",
    "",
    "Exact generated prompt bytes are retained under `raw/prompts/`. The grading",
    "criteria and review were never present in a case workspace or model prompt.",
    ""
  ]
  normalized_results.each { |result| prompt_index << "- [#{result.fetch("id")}](./raw/prompts/#{result.fetch("id")}.txt)" }
  archive_output.write("prompts.md", prompt_index.join("\n") + "\n")

  host_revision = nil
  host_version = case HOST_FAMILY
                 when "codex"
                   controls.fetch("hostVersion").sub(/\Acodex-cli\s+/, "")
                 when "claude"
                   controls.fetch("hostVersion").sub(/\s+\(Claude Code\)\z/, "")
                 else
                   match = controls.fetch("hostVersion").match(/\Agrok\s+([^\s]+)(?:\s+\(([^)]+)\))?\z/)
                   raise "controls.json: Grok hostVersion has an unexpected format" unless match
                   host_revision = match[2]
                   match[1]
                 end
  pass_count = normalized_results.count { |result| result.fetch("grade") == "pass" }
  summary = [
    "# #{controls.fetch("host")} behavioral run",
    "",
    "## Outcome",
    "",
    "**#{pass_count}/#{normalized_results.length} passed after explicit criterion review.**",
    "",
    "| Case | Skill | Grade |",
    "|------|-------|-------|"
  ]
  normalized_results.each { |result| summary << "| #{result.fetch("id")} | #{result.fetch("skill")} | #{result.fetch("grade")} |" }
  summary.concat(["", "## Criterion review", ""])
  reviews.each do |entry|
    summary.concat([
      "### `#{entry.fetch("id")}`",
      "",
      "| Expectation | Criterion | Observed | Evidence |",
      "|-------------|-----------|----------|----------|"
    ])
    entry.fetch("criteria").each do |criterion|
      summary << "| #{criterion.fetch("expectation")} | #{table_cell(criterion.fetch("criterion"))} | #{criterion.fetch("observed")} | #{table_cell(criterion.fetch("evidence"))} |"
    end
    summary << ""
  end
  unless artifact_files.empty?
    summary.concat(["## Retained deliverables", ""])
    normalized_results.each do |result|
      retained = artifact_files.select { |entry| entry[2] == result.fetch("id") }
      retained.each do |relative, _source, _id|
        summary << "- `#{result.fetch("id")}`: [`#{relative}`](./raw/#{relative})"
      end
    end
    summary << ""
  end
  execution_lines = if HOST_FAMILY == "codex"
                      if controls.fetch("executionMode", "response") == "artifact"
                        [
                          "#{controls.fetch("host")} #{host_version} used `#{controls.fetch("model")}` with",
                          "#{controls.fetch("reasoningEffort")} reasoning, one ephemeral turn per case,",
                          "exact copied skill snapshots, generated prompts through stdin, isolated",
                          "initialized Git workspaces, a minimal per-case `CODEX_HOME`, a workspace-write sandbox, approval policy",
                          "`never`, and disabled web/browser/apps/computer access and subagents.",
                          "Post-run auditing rejected writes outside `artifacts/` and any change to",
                          "the copied skill; retained deliverables are covered by exact hashes."
                        ]
                      else
                        [
                          "#{controls.fetch("host")} #{host_version} used `#{controls.fetch("model")}` with",
                          "#{controls.fetch("reasoningEffort")} reasoning, one ephemeral turn per case,",
                          "exact copied skill snapshots, generated prompts through stdin, isolated",
                          "initialized Git workspaces, a minimal per-case `CODEX_HOME`, a read-only sandbox,",
                          "approval policy `never`, ignored user config/rules, removed ambient desktop context,",
                          "and disabled web/browser/apps/computer access",
                          "and subagents."
                        ]
                      end
                    elsif HOST_FAMILY == "claude"
                      actual_models = normalized_results.flat_map { |result| result.fetch("actualModels") }.uniq.sort
                      claude_lines = [
                        "#{controls.fetch("host")} #{host_version} requested `#{controls.fetch("model")}` and used",
                        "`#{actual_models.join("`, `")}` with #{controls.fetch("reasoningEffort")} effort.",
                        "Each case used an ephemeral non-persistent session, an exact copied skill",
                        "snapshot, a generated stdin prompt, and an isolated initialized Git",
                        "workspace. Safe mode disabled customizations; permission mode was `dontAsk`;",
                        "Chrome, MCP, web, and subagents were unavailable. Host authentication/provider settings could",
                        "still apply and are disclosed by the requested-versus-actual model record."
                      ]
                      if controls.fetch("executionMode", "response") == "artifact"
                        claude_lines.concat([
                          "The tool allowlist contained `Read`, `Write`, and `Edit`; post-run auditing",
                          "rejected writes outside `artifacts/` and any change to the copied skill."
                        ])
                      else
                        claude_lines << "The tool allowlist contained only `Read`, and file writes were unavailable."
                      end
                      claude_lines
                    else
                      actual_models = normalized_results.flat_map { |result| result.fetch("actualModels") }.uniq.sort
                      grok_lines = [
                        "#{controls.fetch("host")} #{host_version} requested `#{controls.fetch("model")}` and used",
                        "`#{actual_models.join("`, `")}` with #{controls.fetch("reasoningEffort")} reasoning.",
                        "Each case used at most #{controls.fetch("maxTurnsPerCase")} turns, an isolated ephemeral `GROK_HOME`,",
                        "a fixed system-prompt override, an exact copied skill snapshot, a generated prompt file,",
                        "and an initialized Git workspace. Web search, memory, plan mode, subagents, managed MCP,",
                        "marketplace auto-registration, and MCP tools were disabled; permission mode was",
                        "`#{controls.fetch("approvalPolicy")}`."
                      ]
                      if controls.fetch("executionMode", "response") == "artifact"
                        grok_lines.concat([
                          "The workspace sandbox allowed only `Read`, `Write`, and `Edit`; post-run auditing",
                          "rejected writes outside `artifacts/` and any change to the copied skill."
                        ])
                      else
                        grok_lines << "The read-only sandbox allowed only `Read`, so file writes were unavailable."
                      end
                      grok_lines.concat([
                        "Grok can still discover the standard Agent Skills hub outside its isolated host home;",
                        "the fixed system prompt and case prompt required it to use only the retained target snapshot.",
                        "Host authentication/provider settings could still apply and are disclosed by the",
                        "requested-versus-actual model record."
                      ])
                      grok_lines
                    end
  summary.concat([
    "## Execution controls",
    "",
    *execution_lines,
    "",
    "## Runner incidents",
    ""
  ])
  incidents.empty? ? summary << "No recognized runner incidents were recorded." : incidents.each { |incident| summary << "- #{incident}" }
  summary.concat([
    "",
    "Private runner records corroborated host, requested and actual model, permissions,",
    "isolation flags, workspaces, prompt bytes, response bytes, and incident counts, then",
    "were excluded because they contain ephemeral session identifiers and local",
    "paths. Results apply to the retained skill snapshots and execution controls."
  ])
  archive_output.write("summary.md", summary.join("\n") + "\n")

  metadata_runs = normalized_results.map do |result|
    id = result.fetch("id")
    skill_artifacts = snapshot_files.select { |entry| entry[2] == result.fetch("skill") }.map { |entry| entry[0] }
    generated_artifacts = artifact_files.select { |entry| entry[2] == id }.map { |entry| entry[0] }
    control_artifacts = artifact_manifest ? ["runner-artifact-manifest.txt"] : []
    run = {
      "id" => "#{options[:phase]}-#{id}",
      "case" => id,
      "phase" => options[:phase],
      "grade" => result.fetch("grade"),
      "exitStatus" => result.fetch("exitStatus"),
      "elapsedSeconds" => result["elapsedSeconds"],
      "stopStatus" => "completed with CLI exit #{result.fetch("exitStatus")}",
      "evidenceHandoffContract" => result.fetch("evidenceHandoffContract"),
      "artifacts" => ["skill-snapshot-manifest.txt", "prompts/#{id}.txt", "responses/#{id}.txt"] + control_artifacts + skill_artifacts + generated_artifacts
    }
    if HOST_FAMILY == "claude"
      run["model"] = result.fetch("actualModels").fetch(0)
      run["turns"] = result.fetch("numTurns")
      run["stopStatus"] = [result["stopReason"], result["terminalReason"]].compact.join(" / ")
      run["totalCostUsd"] = result["totalCostUsd"]
    elsif HOST_FAMILY == "grok"
      run["model"] = result.fetch("actualModels").fetch(0)
      run["turns"] = result.fetch("numTurns")
      run["stopStatus"] = result.fetch("stopReason")
      run["totalCostUsd"] = result["totalCostUsd"]
      run["tokenUsage"] = result["tokenUsage"]
    end
    run
  end
  execution_defaults = {
    "workspace" => "separate initialized disposable Git repository containing only the target skill snapshot",
    "permissions" => if controls.fetch("executionMode", "response") == "artifact"
                       if HOST_FAMILY == "codex"
                         "workspace-write sandbox; writes limited by prompt and post-run audit to artifacts/; approval policy never"
                       elsif HOST_FAMILY == "claude"
                         "safe mode; Read, Write, and Edit tools only; writes limited by prompt and post-run audit to artifacts/; permission mode dontAsk"
                       else
                         "workspace sandbox; Read, Write, and Edit tools only; writes limited by prompt and post-run audit to artifacts/; permission mode bypassPermissions"
                       end
                     elsif HOST_FAMILY == "codex"
                       "read-only sandbox; approval policy never"
                     elsif HOST_FAMILY == "claude"
                       "safe mode; Read tool only; permission mode dontAsk"
                     else
                       "read-only sandbox; Read tool only; permission mode dontAsk"
                     end,
    "webSearch" => false,
    "subagents" => false,
    "reasoningEffort" => controls.fetch("reasoningEffort"),
    "ephemeralSession" => true,
    "timeoutSecondsPerCase" => controls.fetch("timeoutSecondsPerCase"),
    "maxCasesPerRun" => controls.fetch("maxCasesPerRun"),
    "maxHostOutputBytesPerCase" => controls.fetch("maxHostOutputBytesPerCase"),
    "maxPromptBytesPerCase" => controls.fetch("maxPromptBytesPerCase"),
    "maxPromptBytesPerRun" => controls.fetch("maxPromptBytesPerRun"),
    "promptBytes" => controls.fetch("promptBytes"),
    "skillSource" => "exact retained source snapshot",
    "runtimeTreeMonitoring" => controls.fetch("runtimeTreeMonitoring"),
    "concurrentRuntimeMonitoring" => controls.fetch("concurrentRuntimeMonitoring"),
    "pidMonitoringStartsAtSpawn" => controls.fetch("pidMonitoringStartsAtSpawn"),
    "sharedRootMonitoring" => controls.fetch("sharedRootMonitoring"),
    "privatePromptIntegrityMonitoring" => controls.fetch("privatePromptIntegrityMonitoring"),
    "anonymousPromptDescriptor" => controls.fetch("anonymousPromptDescriptor"),
    "promptDescriptorPath" => controls["promptDescriptorPath"],
    "outputDirectoryIdentityMonitoring" => controls.fetch("outputDirectoryIdentityMonitoring"),
    "outputTreeMonitoring" => controls.fetch("outputTreeMonitoring"),
    "exclusiveRunnerOutputs" => controls.fetch("exclusiveRunnerOutputs"),
    "workspaceViolationStopsRun" => controls.fetch("workspaceViolationStopsRun"),
    "copiedSkillIntegrityMonitoring" => controls.fetch("copiedSkillIntegrityMonitoring"),
    "singleLinkInputFiles" => controls.fetch("singleLinkInputFiles"),
    "singleLinkRuntimeFiles" => controls.fetch("singleLinkRuntimeFiles"),
    "maxRuntimeOutputFiles" => controls.fetch("maxRuntimeOutputFiles"),
    "maxRuntimeOutputTreeEntries" => controls.fetch("maxRuntimeOutputTreeEntries"),
    "maxRuntimeOutputBytes" => controls.fetch("maxRuntimeOutputBytes"),
    "maxRuntimeGitFiles" => controls.fetch("maxRuntimeGitFiles"),
    "maxRuntimeGitTreeEntries" => controls.fetch("maxRuntimeGitTreeEntries"),
    "maxRuntimeGitBytes" => controls.fetch("maxRuntimeGitBytes"),
    "maxRuntimeHostHomeFiles" => controls.fetch("maxRuntimeHostHomeFiles"),
    "maxRuntimeHostHomeTreeEntries" => controls.fetch("maxRuntimeHostHomeTreeEntries"),
    "maxRuntimeHostHomeBytes" => controls.fetch("maxRuntimeHostHomeBytes")
  }
  execution_defaults["executionMode"] = controls.fetch("executionMode", "response")
  if controls.fetch("executionMode", "response") == "artifact"
    execution_defaults["maxArtifactFilesPerCase"] = controls.fetch("maxArtifactFilesPerCase")
    execution_defaults["maxArtifactFileBytes"] = controls.fetch("maxArtifactFileBytes")
    execution_defaults["maxArtifactBytesPerCase"] = controls.fetch("maxArtifactBytesPerCase")
    execution_defaults["maxArtifactTreeEntriesPerCase"] = controls.fetch("maxArtifactTreeEntriesPerCase")
    execution_defaults["maxArtifactFilesPerRun"] = controls.fetch("maxArtifactFilesPerRun")
    execution_defaults["maxArtifactBytesPerRun"] = controls.fetch("maxArtifactBytesPerRun")
    execution_defaults["maxArtifactJobs"] = controls.fetch("maxArtifactJobs")
    execution_defaults["artifactRuntimeMonitoring"] = controls.fetch("artifactRuntimeMonitoring")
    execution_defaults["artifactManifestFromCapturedBytes"] = controls.fetch("artifactManifestFromCapturedBytes")
  end
  if HOST_FAMILY == "codex"
    execution_defaults["model"] = controls.fetch("model")
    execution_defaults["turns"] = 1
    execution_defaults["isolatedHostHome"] = true
    execution_defaults["ambientDesktopContextDisabled"] = controls.fetch("ambientDesktopContextDisabled")
  elsif HOST_FAMILY == "claude"
    execution_defaults["requestedModel"] = controls.fetch("model")
    execution_defaults["sessionPersistence"] = false
    execution_defaults["maxBudgetUsdPerCase"] = controls.fetch("maxBudgetUsdPerCase")
  else
    execution_defaults["requestedModel"] = controls.fetch("model")
    execution_defaults["sessionPersistence"] = false
    execution_defaults["maxTurnsPerCase"] = controls.fetch("maxTurnsPerCase")
    execution_defaults["ambientAgentSkillsMayBeDiscovered"] = true
  end
  host_metadata = { "name" => controls.fetch("host"), "version" => host_version }
  host_metadata["revision"] = host_revision if host_revision
  metadata = {
    "schemaVersion" => 2,
    "archiveDate" => archive_date,
    "suite" => "behavioral",
    "host" => host_metadata,
    "provenance" => { "status" => "complete", "gaps" => [] },
    "executionDefaults" => execution_defaults,
    "runs" => metadata_runs,
    "runnerIncidents" => incidents,
    "archiveNote" => "Prompts, responses, and skill sources are exact runner files. The criterion review is separate. Private host execution records corroborated controls and bytes, then were excluded."
  }
  archive_output.write("run.json", json_content(metadata))
  archive_output.write("runner-controls.json", json_content(controls))
  archive_output.write("runner-results.json", json_content(results))
  archive_output.write("runner-review.json", json_content(review))
  raw_manifest_content = EVAL_ARCHIVE_RAW_FILES.write_manifest(raw_directory, raw_contents)
  publication_lock.verify!
  run_checked(RbConfig.ruby, ARCHIVE_MANIFEST_SCRIPT, "--publication-lock-held", temporary_archive)
  candidate_snapshot = EVAL_ARCHIVE_CANDIDATE.capture(temporary_archive)
  publication_lock.verify!
  run_checked(
    RbConfig.ruby, EVIDENCE_VALIDATOR,
    "--candidate", temporary_archive,
    "--candidate-name", options[:archive]
  )
  EVAL_ARCHIVE_RAW_FILES.verify!(raw_directory, raw_contents, raw_manifest_content)
  EVAL_ARCHIVE_CANDIDATE.verify!(temporary_archive, candidate_snapshot)
  assert_behavioral_sources_unchanged!(cases_manifest_content, current_skill_states)
  publication_lock.verify!
  raise "archive target appeared during publication: #{target}" if File.exist?(target) || File.symlink?(target)
  File.rename(temporary_archive, target)
  published_archive = target
  published_archive_identity = temporary_archive_identity
  temporary_archive = nil
  temporary_archive_identity = nil
  publication_lock.verify!
  validation_output = run_checked(RbConfig.ruby, EVIDENCE_VALIDATOR)
  EVAL_ARCHIVE_CANDIDATE.verify!(target, candidate_snapshot, relocated: true)
  EVAL_ARCHIVE_RAW_FILES.verify!(File.join(target, "raw"), raw_contents, raw_manifest_content)
  assert_behavioral_sources_unchanged!(cases_manifest_content, current_skill_states)
  publication_lock.verify!
  puts "ARCHIVE=#{Pathname.new(target).relative_path_from(Pathname.new(ROOT))}"
  puts validation_output
rescue Interrupt
  warn "ERROR: interrupted"
  exit 130
rescue StandardError => e
  if published_archive
    Zstack::EvalOwnedDirectory.remove_if_same(published_archive, published_archive_identity)
    published_archive = nil
    published_archive_identity = nil
  end
  warn "ERROR: #{e.message}"
  exit 2
ensure
  source_snapshot&.close
  Zstack::EvalOwnedDirectory.remove_if_same(temporary_archive, temporary_archive_identity)
  publication_lock&.close
end
