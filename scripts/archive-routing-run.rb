#!/usr/bin/env ruby
# Shared atomic archiver for isolated host-specific routing runs.

require "date"
require "digest"
require "fileutils"
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
require_relative "lib/eval_host_contracts"
require_relative "lib/eval_input_file"
require_relative "lib/eval_limits"
require_relative "lib/eval_owned_directory"
require_relative "lib/eval_private_paths"
require_relative "lib/eval_process_supervisor"
require_relative "lib/eval_routing_prompt"
require_relative "lib/eval_source_snapshot"
require_relative "lib/eval_strict_json"
require_relative "lib/eval_strict_yaml"

ROOT = File.expand_path("..", __dir__)
RUNS_ROOT = File.join(ROOT, "evals", "runs")
ROUTING_PATH = File.join(ROOT, "evals", "routing.yaml")
ARCHIVE_MANIFEST_SCRIPT = File.join(ROOT, "scripts", "generate-evidence-manifests.rb")
EVIDENCE_VALIDATOR = File.join(ROOT, "scripts", "validate-evidence.rb")
HOST_FAMILY = ENV.fetch("ZSTACK_ROUTING_HOST", "")
HOST_NAMES = { "codex" => "Codex CLI", "claude" => "Claude Code", "grok" => "Grok Build" }.freeze
HOST_NAME = HOST_NAMES[HOST_FAMILY]
raise "set ZSTACK_ROUTING_HOST to codex, claude, or grok" unless HOST_NAME
STRUCTURED_HOSTS = %w[claude grok].freeze
EVAL_HOST_CONTRACTS = Zstack::EvalHostContracts
EVAL_ARCHIVE_CANDIDATE = Zstack::EvalArchiveCandidate
EVAL_ARCHIVE_NAME = Zstack::EvalArchiveName
EVAL_ARCHIVE_OUTPUT = Zstack::EvalArchiveOutput
EVAL_ARCHIVE_RAW_FILES = Zstack::EvalArchiveRawFiles
EVAL_BOUNDED_COMMAND = Zstack::EvalBoundedCommand
EVAL_CODEX_HOME = Zstack::EvalCodexHome
EVAL_PRIVATE_PATHS = Zstack::EvalPrivatePaths
EVAL_PROCESS_SUPERVISOR = Zstack::EvalProcessSupervisor
EVAL_ROUTING_PROMPT = Zstack::EvalRoutingPrompt
GROK_SYSTEM_PROMPT = EVAL_HOST_CONTRACTS.grok_system_prompt("routing")
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
  expected
  selected
  pass
  executionCompleted
  formatValid
  formatError
  exitStatus
  elapsedSeconds
  timedOut
  outputLimited
  workspaceLimitError
  hostOutputBytes
  promptPath
  responsePath
  logPath
  responsePrivacyError
  responseFileError
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

def load_routing_cases
  content = Zstack::EvalInputFile.read(
    ROUTING_PATH,
    label: "evals/routing.yaml",
    root: ROOT
  )
  document = Zstack::EvalStrictYaml.parse(
    content,
    ROUTING_PATH
  )
  [Array(document.fetch("cases")), content]
rescue Errno::ENOENT, KeyError, Psych::Exception => e
  raise "cannot load evals/routing.yaml: #{e.message}"
end

def assert_routing_manifest_unchanged!(expected_content)
  current_content = Zstack::EvalInputFile.read(
    ROUTING_PATH,
    label: "evals/routing.yaml",
    root: ROOT
  )
  return if current_content == expected_content

  raise "evals/routing.yaml changed while archive was being prepared"
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
  raise "controls.json: host must be #{HOST_NAME}" unless controls["host"] == HOST_NAME
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
  unless controls.fetch("cases") == result_ids
    raise "controls.json: cases must exactly match results.json order"
  end
  unless controls["privateCaseIdentifiers"] == EVAL_PRIVATE_PATHS::STRATEGY
    raise "controls.json: private case-identifier strategy changed"
  end
  raise "controls.json: webSearch must be false" unless controls["webSearch"] == false
  raise "controls.json: subagents must be false" unless controls["subagents"] == false
  unless %w[auto en zh].include?(controls["wrapper"])
    raise "controls.json: wrapper must be auto, en, or zh"
  end
  description_limit = controls["descriptionCharacterLimit"]
  unless description_limit.nil? || (description_limit.is_a?(Integer) &&
         description_limit.between?(80, Zstack::EvalLimits::MAX_DESCRIPTION_CHARACTERS))
    raise "controls.json: descriptionCharacterLimit is outside the runner safety limit"
  end
  unless controls["candidateRotation"] == "full manifest index modulo candidate count"
    raise "controls.json: candidateRotation changed"
  end

  if HOST_FAMILY == "codex"
    raise "controls.json: sandbox must be read-only" unless controls["sandbox"] == "read-only"
    raise "controls.json: approvalPolicy must be never" unless controls["approvalPolicy"] == "never"
    raise "controls.json: ignoreUserConfig must be true" unless controls["ignoreUserConfig"] == true
    raise "controls.json: ignoreRules must be true" unless controls["ignoreRules"] == true
    raise "controls.json: Codex host home must be isolated" unless controls["isolatedHostHome"] == true
    unless controls["ambientDesktopContextDisabled"] == EVAL_CODEX_HOME::AMBIENT_CONTEXT_KEYS
      raise "controls.json: Codex ambient desktop context controls changed"
    end
    unless controls["promptTransport"] == "generated prompt through stdin"
      raise "controls.json: promptTransport must exclude ambient stdin"
    end
    raise "controls.json: disabledFeatures must be an array" unless controls["disabledFeatures"].is_a?(Array)
    missing_features = REQUIRED_DISABLED_FEATURES - controls.fetch("disabledFeatures")
    unless missing_features.empty?
      raise "controls.json: required disabled features are missing: #{missing_features.join(", ")}"
    end
  elsif HOST_FAMILY == "claude"
    raise "controls.json: Claude sandbox must disable built-in tools" unless controls["sandbox"] == "no built-in tools"
    raise "controls.json: Claude approval policy must be dontAsk" unless controls["approvalPolicy"] == "dontAsk"
    raise "controls.json: Claude prompt transport must be stdin" unless controls["promptTransport"] == "generated prompt through stdin"
    raise "controls.json: Claude safeMode must be true" unless controls["safeMode"] == true
    raise "controls.json: Claude customizations must be disabled" unless controls["customizationsDisabled"] == true
    raise "controls.json: Claude provider-config disclosure is missing" unless controls["hostProviderConfigMayApply"] == true
    raise "controls.json: Claude allowedTools must be empty" unless controls["allowedTools"] == []
    raise "controls.json: Claude Chrome must be disabled" unless controls["chrome"] == false
    raise "controls.json: Claude MCP servers must be disabled" unless controls["mcpServers"] == false
    raise "controls.json: Claude session persistence must be disabled" unless controls["sessionPersistence"] == false
    unless Zstack::EvalLimits.finite_positive_number?(controls["maxBudgetUsdPerCase"])
      raise "controls.json: Claude maxBudgetUsdPerCase must be finite and positive"
    end
    raise "controls.json: Claude resultFormat must be json" unless controls["resultFormat"] == "json"
  else
    raise "controls.json: Grok sandbox must be read-only" unless controls["sandbox"] == "read-only"
    raise "controls.json: Grok approval policy must be dontAsk" unless controls["approvalPolicy"] == "dontAsk"
    unless controls["promptTransport"] == "generated prompt through anonymous descriptor"
      raise "controls.json: Grok prompt transport must use an anonymous descriptor"
    end
    raise "controls.json: Grok prompt descriptor path changed" unless controls["promptDescriptorPath"] == GROK_PROMPT_PATH
    raise "controls.json: Grok allowedTools must be empty" unless controls["allowedTools"] == []
    raise "controls.json: Grok system prompt changed" unless controls["systemPromptOverride"] == GROK_SYSTEM_PROMPT
    raise "controls.json: Grok final-response boundary changed" unless controls["finalResponseBoundary"] == GROK_FINAL_MARKER
    raise "controls.json: Grok host home must be isolated" unless controls["isolatedHostHome"] == true
    unless controls["isolatedHostConfigSha256"] == Digest::SHA256.hexdigest(GROK_ISOLATED_CONFIG)
      raise "controls.json: Grok isolated config digest changed"
    end
    unless controls["foreignCompatibilityDisabled"] == %w[claude cursor codex-sessions]
      raise "controls.json: Grok foreign compatibility controls changed"
    end
    raise "controls.json: Grok ambient-skill disclosure is missing" unless controls["ambientAgentSkillsMayBeDiscovered"] == true
    raise "controls.json: Grok provider-config disclosure is missing" unless controls["hostProviderConfigMayApply"] == true
    raise "controls.json: Grok MCP tools must be disallowed" unless controls["mcpToolsAllowed"] == false
    raise "controls.json: Grok managed MCP must be disabled" unless controls["managedMcpDisabled"] == true
    unless controls["officialMarketplaceAutoRegister"] == false
      raise "controls.json: Grok marketplace auto-registration must be disabled"
    end
    raise "controls.json: Grok memory must be disabled" unless controls["memory"] == false
    raise "controls.json: Grok plan mode must be disabled" unless controls["planMode"] == false
    raise "controls.json: Grok verbatim prompt must be true" unless controls["verbatimPrompt"] == true
    raise "controls.json: Grok session persistence must be disabled" unless controls["sessionPersistence"] == false
    unless controls["maxTurnsPerCase"].is_a?(Integer) &&
           controls["maxTurnsPerCase"].between?(1, Zstack::EvalLimits::MAX_GROK_TURNS)
      raise "controls.json: Grok maxTurnsPerCase is outside the runner safety limit"
    end
    raise "controls.json: Grok resultFormat must be json" unless controls["resultFormat"] == "json"
  end
end

def parse_response(source_snapshot, path, candidate_ids)
  raw = source_snapshot.read_text(path).strip
  lines = raw.lines.map(&:strip).reject(&:empty?)
  selection_match = lines.first&.match(/\Aselection:\s*(z-[a-z0-9-]+|none)\s*\z/i)
  reason_match = lines[1]&.match?(/\Areason:\s*\S.+\z/i)
  selected = selection_match && selection_match[1].downcase
  allowed = selected == "none" || candidate_ids.include?(selected)
  format_valid = lines.length == 2 && selection_match && reason_match && allowed
  error = if lines.length != 2
            "response must contain exactly two non-empty lines"
          elsif !selection_match
            "selection line is malformed"
          elsif !allowed
            "selection is not a candidate"
          elsif !reason_match
            "reason line is empty or malformed"
          end
  [selected, !!format_valid, error]
end

def load_candidate_entries(source_snapshot, path)
  entries = source_snapshot.read_text(path).lines.map(&:chomp).map do |line|
    id, description = line.split("\t", 2)
    unless id&.match?(/\Az-[a-z0-9-]+\z/) && description.is_a?(String) && !description.empty?
      raise "candidate-descriptions.txt has an invalid line"
    end
    [id, description]
  end
  ids = entries.map(&:first)
  raise "candidate-descriptions.txt has duplicate ids" unless ids.uniq.length == ids.length
  raise "candidate-descriptions.txt has no candidates" if ids.empty?

  entries
end

def reject_private_runner_data!(source_snapshot, path)
  content = source_snapshot.read_text(path)
  if content.match?(/session id:\s*[0-9a-f-]{16,}/i) ||
     content.match?(/zstack-(?:codex|claude|grok)-routing-workspaces-/) ||
     content.match?(/case-[0-9a-f]{32}/)
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
  counts = patterns.to_h { |label, _pattern| [label, 0] }
  seen_tokens = Set.new
  results.each do |result|
    id = result.fetch("id")
    log_path = result.fetch("logSource")
    content = source_snapshot.read_text(log_path)
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
      unless log_field(content, field, id) == expected
        raise "#{id}: runner log #{field} does not match controls.json"
      end
    end
    workdir = log_field(content, "workdir", id)
    private_token = File.basename(workdir)
    unless EVAL_PRIVATE_PATHS.token?(private_token) && workdir.include?("zstack-codex-routing-workspaces-")
      raise "#{id}: runner log workdir is not the isolated case workspace"
    end
    raise "#{id}: private case token was reused" unless seen_tokens.add?(private_token)
    prompt = source_snapshot.read_text(result.fetch("promptSource")).rstrip
    response = source_snapshot.read_text(result.fetch("responseSource")).strip
    raise "#{id}: runner log does not contain the exact generated prompt" unless content.include?(prompt)
    raise "#{id}: runner log does not contain the retained final response" unless content.include?(response)

    patterns.each do |label, pattern|
      counts[label] += 1 if content.match?(pattern)
    end
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
    "--permission-mode", controls.fetch("approvalPolicy"), "--tools", "", "--no-chrome",
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
      raise "#{id}: invocation arguments do not match the isolated Claude routing contract"
    end
    workspace = invocation["workspace"]
    private_token = invocation["privateCaseToken"]
    unless EVAL_PRIVATE_PATHS.token?(private_token) && workspace.is_a?(String) &&
           File.basename(workspace) == private_token && workspace.include?("zstack-claude-routing-workspaces-")
      raise "#{id}: invocation workspace is not the isolated routing workspace"
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
    raise "#{id}: Claude routing run must use exactly one actual model" unless result.fetch("actualModels").length == 1
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
    raise "#{id}: Claude routing run recorded a permission denial" unless denials.empty?
    raise "#{id}: Claude API status must be null for a complete run" unless result["apiErrorStatus"].nil?
    raise "#{id}: Claude error category must be null for a complete run" unless result["errorCategory"].nil?
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
    "--tools", "", "--permission-mode", controls.fetch("approvalPolicy"),
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
           File.basename(workspace) == private_token && workspace.include?("zstack-grok-routing-workspaces-")
      raise "#{id}: invocation workspace is not the isolated routing workspace"
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
      raise "#{id}: invocation arguments do not match the isolated Grok routing contract"
    end
    environment = invocation["environment"]
    raise "#{id}: invocation environment must be an object" unless environment.is_a?(Hash)
    unless environment.keys.sort == %w[GROK_AUTH_PATH GROK_HOME GROK_MANAGED_MCPS_ENABLED GROK_OFFICIAL_MARKETPLACE_AUTO_REGISTER]
      raise "#{id}: Grok invocation environment keys changed"
    end
    grok_home = environment["GROK_HOME"]
    unless grok_home.is_a?(String) && File.basename(grok_home) == private_token && File.basename(File.dirname(grok_home)) == ".grok-homes" &&
           File.dirname(File.dirname(grok_home)) == File.dirname(workspace)
      raise "#{id}: Grok home is not isolated beside the routing workspace"
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
    raise "#{id}: Grok routing run must use exactly one actual model" unless result.fetch("actualModels").length == 1
    raise "#{id}: numTurns differs from Grok JSON" unless result["numTurns"] == raw["num_turns"]
    unless result["numTurns"].is_a?(Integer) && result["numTurns"].positive? && result["numTurns"] <= controls.fetch("maxTurnsPerCase")
      raise "#{id}: numTurns must be within the configured Grok turn budget"
    end
    raise "#{id}: stopReason differs from Grok JSON" unless result["stopReason"] == raw["stopReason"]
    raise "#{id}: Grok routing run did not finish with end_turn" unless result["stopReason"] == "end_turn"
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

options = { archive: nil, phase: nil, run_directory: nil }
parser = OptionParser.new do |opts|
  opts.banner = "Usage: ruby scripts/archive-#{HOST_FAMILY}-routing-run.rb --run-dir DIR --archive YYYY-MM-DD-SLUG --phase PHASE"
  opts.on("--run-dir DIR", "Output from run-#{HOST_FAMILY}-routing-evals.rb") { |value| options[:run_directory] = value }
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
unless options[:phase].match?(/\A[a-z0-9][a-z0-9-]*\z/)
  fail_usage("--phase must be kebab-case")
end
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
  candidates_path = regular_source_file(source_snapshot, "candidate-descriptions.txt")
  controls = load_json(source_snapshot, controls_path)
  results = load_json(source_snapshot, results_path)
  raise "controls.json must contain an object" unless controls.is_a?(Hash)
  raise "results.json must contain a non-empty array" unless results.is_a?(Array) && !results.empty?
  raise "results.json entries must be objects" unless results.all? { |entry| entry.is_a?(Hash) }

  result_ids = results.map { |entry| entry["id"] }
  unless result_ids.all? { |id| id.is_a?(String) && id.match?(/\A[a-z0-9][a-z0-9-]*\z/) } && result_ids.uniq.length == result_ids.length
    raise "results.json ids must be unique kebab-case strings"
  end
  validate_controls!(controls, result_ids)
  candidate_entries = load_candidate_entries(source_snapshot, candidates_path)
  candidates = candidate_entries.map(&:first)
  routing_case_entries, routing_manifest_content = load_routing_cases
  routing_cases = routing_case_entries.to_h { |entry| [entry.fetch("id"), entry] }
  routing_case_indexes = routing_case_entries.each_with_index.to_h { |entry, index| [entry.fetch("id"), index] }

  source_files = [controls_path, results_path, candidates_path]
  normalized_results = results.map do |result|
    id = result.fetch("id")
    missing_fields = REQUIRED_RESULT_FIELDS.reject { |field| result.key?(field) }
    unless missing_fields.empty?
      raise "#{id}: result is missing required fields: #{missing_fields.join(", ")}"
    end
    registered = routing_cases[id]
    raise "results.json references unknown routing case: #{id}" unless registered
    unless result["expected"] == registered.fetch("expected_skill")
      raise "#{id}: runner expected value does not match evals/routing.yaml"
    end
    expected_prompt_path = "prompts/#{id}.txt"
    expected_response_path = "responses/#{id}.txt"
    expected_log_path = "logs/#{id}.log"
    unless result["promptPath"] == expected_prompt_path && result["responsePath"] == expected_response_path && result["logPath"] == expected_log_path
      raise "#{id}: runner paths do not match the canonical output layout"
    end
    prompt_path = regular_source_file(source_snapshot, expected_prompt_path)
    response_path = regular_source_file(source_snapshot, expected_response_path)
    log_path = regular_source_file(source_snapshot, expected_log_path)
    source_files.concat([prompt_path, response_path])
    rotation = routing_case_indexes.fetch(id) % candidate_entries.length
    ordered_candidates = candidate_entries.rotate(rotation)
    style = EVAL_ROUTING_PROMPT.wrapper_style(controls.fetch("wrapper"), registered.fetch("prompt"))
    expected_prompt = EVAL_ROUTING_PROMPT.build(
      ordered_candidates,
      registered.fetch("prompt"),
      style,
      controls["descriptionCharacterLimit"]
    )
    unless source_snapshot.read(prompt_path) == expected_prompt.b
      raise "#{id}: prompt differs from the canonical routing wrapper"
    end

    selected, format_valid, format_error = parse_response(source_snapshot, response_path, candidates)
    unless result["selected"] == selected && result["formatValid"] == format_valid && result["formatError"] == format_error
      raise "#{id}: retained response does not match results.json parsing"
    end
    exit_status = result["exitStatus"]
    raise "#{id}: exitStatus must be a non-negative integer" unless exit_status.is_a?(Integer) && exit_status >= 0
    raise "#{id}: executionCompleted must be true for archiving" unless result["executionCompleted"] == true
    raise "#{id}: timedOut must be false for archiving" unless result["timedOut"] == false
    elapsed_seconds = result["elapsedSeconds"]
    unless Zstack::EvalLimits.finite_nonnegative_number?(elapsed_seconds)
      raise "#{id}: elapsedSeconds must be a finite non-negative number"
    end
    unless result.key?("responsePrivacyError") && result["responsePrivacyError"].nil?
      raise "#{id}: responsePrivacyError must be present and null"
    end
    unless result.key?("responseFileError") && result["responseFileError"].nil?
      raise "#{id}: responseFileError must be present and null"
    end
    passed = result.fetch("executionCompleted") && exit_status.zero? && format_valid && selected == result.fetch("expected")
    raise "#{id}: retained response grade does not match results.json" unless result["pass"] == passed

    normalized = {
      "id" => id,
      "expected" => result.fetch("expected"),
      "selected" => selected,
      "pass" => passed,
      "exitStatus" => exit_status,
      "elapsedSeconds" => elapsed_seconds,
      "promptSource" => prompt_path,
      "responseSource" => response_path,
      "logSource" => log_path
    }
    if STRUCTURED_HOSTS.include?(HOST_FAMILY)
      host_result_fields = HOST_FAMILY == "claude" ? EVAL_HOST_CONTRACTS::CLAUDE_RESULT_FIELDS : EVAL_HOST_CONTRACTS::GROK_RESULT_FIELDS
      missing_fields = (%w[rawResultPath invocationPath] + host_result_fields).reject { |field| result.key?(field) }
      unless missing_fields.empty?
        raise "#{id}: structured-host result is missing required fields: #{missing_fields.join(", ")}"
      end
      expected_raw_path = "logs/#{id}.json"
      expected_invocation_path = "logs/#{id}.invocation.json"
      unless result["rawResultPath"] == expected_raw_path && result["invocationPath"] == expected_invocation_path
        raise "#{id}: structured-host private paths do not match the canonical output layout"
      end
      normalized["rawResultSource"] = regular_source_file(source_snapshot, expected_raw_path)
      normalized["invocationSource"] = regular_source_file(source_snapshot, expected_invocation_path)
      host_result_fields.each { |field| normalized[field] = result.fetch(field) }
    end
    raise "#{id}: outputLimited must be false for archiving" unless result["outputLimited"] == false
    raise "#{id}: workspaceLimitError must be null for archiving" unless result["workspaceLimitError"].nil?
    host_output_bytes = result["hostOutputBytes"]
    unless host_output_bytes.is_a?(Integer) && host_output_bytes >= 0
      raise "#{id}: hostOutputBytes must be a non-negative integer"
    end
    host_output_paths = if STRUCTURED_HOSTS.include?(HOST_FAMILY)
                          [normalized.fetch("rawResultSource"), log_path]
                        else
                          [log_path, response_path]
                        end
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
  source_files.each { |path| reject_private_runner_data!(source_snapshot, path) }
  incidents = runner_incidents(source_snapshot, normalized_results, controls)

  FileUtils.mkdir_p(RUNS_ROOT)
  raise "evals/runs must not be a symbolic link" if File.symlink?(RUNS_ROOT)
  publication_lock = Zstack::EvalArchiveLock.acquire(RUNS_ROOT)
  target = File.join(RUNS_ROOT, options[:archive])
  raise "archive target already exists: #{target}" if File.exist?(target) || File.symlink?(target)

  run_checked(RbConfig.ruby, EVIDENCE_VALIDATOR)
  temporary_archive = Dir.mktmpdir(".zstack-routing-archive-", RUNS_ROOT)
  temporary_archive_identity = Zstack::EvalOwnedDirectory.capture(
    temporary_archive,
    label: "routing archive transaction directory"
  )
  archive_output = EVAL_ARCHIVE_OUTPUT.new(temporary_archive)
  raw_directory = File.join(temporary_archive, "raw")
  raw_prompts = File.join(raw_directory, "prompts")
  raw_responses = File.join(raw_directory, "responses")
  FileUtils.mkdir_p(raw_prompts)
  FileUtils.mkdir_p(raw_responses)
  raw_contents = {}
  raw_contents["candidate-descriptions.txt"] = source_snapshot.read(candidates_path)
  source_snapshot.copy(candidates_path, File.join(raw_directory, "candidate-descriptions.txt"))
  normalized_results.each do |result|
    id = result.fetch("id")
    prompt_relative = "prompts/#{id}.txt"
    response_relative = "responses/#{id}.txt"
    raw_contents[prompt_relative] = source_snapshot.read(result.fetch("promptSource"))
    raw_contents[response_relative] = source_snapshot.read(result.fetch("responseSource"))
    source_snapshot.copy(result.fetch("promptSource"), File.join(raw_directory, prompt_relative))
    source_snapshot.copy(result.fetch("responseSource"), File.join(raw_directory, response_relative))
  end

  prompt_index = [
    "# #{controls.fetch("host")} routing prompts",
    "",
    "Exact prompt bytes are retained under `raw/prompts/`; expected selections",
    "and grading were not present in those prompts.",
    ""
  ]
  normalized_results.each do |result|
    id = result.fetch("id")
    prompt_index << "- [#{id}](./raw/prompts/#{id}.txt)"
  end
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
  pass_count = normalized_results.count { |result| result.fetch("pass") }
  summary = [
    "# #{controls.fetch("host")} routing run",
    "",
    "## Outcome",
    "",
    "**#{pass_count}/#{normalized_results.length} passed.**",
    "",
    "| Case | Expected | Selected | Result |",
    "|------|----------|----------|--------|"
  ]
  normalized_results.each do |result|
    summary << "| #{result.fetch("id")} | #{result.fetch("expected")} | #{result["selected"] || "unparsed"} | #{result.fetch("pass") ? "pass" : "fail"} |"
  end
  execution_lines = if HOST_FAMILY == "codex"
                      [
                        "#{controls.fetch("host")} #{host_version} used `#{controls.fetch("model")}` with",
                        "#{controls.fetch("reasoningEffort")} reasoning, one ephemeral turn per case,",
                        "generated prompts through stdin, isolated initialized Git workspaces, a",
                        "minimal per-case `CODEX_HOME`, read-only sandbox, approval policy `never`,",
                        "ignored user config/rules, removed ambient desktop context, and",
                        "disabled tools, apps, skill loading, browser/computer access, and subagents."
                      ]
                    elsif HOST_FAMILY == "claude"
                      actual_models = normalized_results.flat_map { |result| result.fetch("actualModels") }.uniq.sort
                      [
                        "#{controls.fetch("host")} #{host_version} requested `#{controls.fetch("model")}` and used",
                        "`#{actual_models.join("`, `")}` with #{controls.fetch("reasoningEffort")} effort.",
                        "Each case used an ephemeral non-persistent session, a generated stdin prompt,",
                        "and an isolated initialized Git workspace. Safe mode disabled customizations;",
                        "the built-in tool list was empty, permission mode was `dontAsk`, and Chrome and",
                        "MCP were disabled. Host authentication/provider settings could still apply and",
                        "are disclosed by the requested-versus-actual model record."
                      ]
                    else
                      actual_models = normalized_results.flat_map { |result| result.fetch("actualModels") }.uniq.sort
                      [
                        "#{controls.fetch("host")} #{host_version} requested `#{controls.fetch("model")}` and used",
                        "`#{actual_models.join("`, `")}` with #{controls.fetch("reasoningEffort")} reasoning.",
                        "Each case used at most #{controls.fetch("maxTurnsPerCase")} turn, an isolated ephemeral",
                        "`GROK_HOME`, a fixed system prompt, a generated prompt file, and an initialized",
                        "Git workspace. The built-in tool list was empty; web search, memory, plan mode,",
                        "subagents, managed MCP, marketplace auto-registration, and MCP tools were disabled.",
                        "Grok can still discover the standard Agent Skills hub outside its isolated host",
                        "home, so both prompts explicitly prohibited skill loading and file inspection."
                      ]
                    end
  summary.concat([
    "",
    "## Execution controls",
    "",
    *execution_lines,
    "Candidate order followed the recorded deterministic rotation.",
    "",
    "## Runner incidents",
    ""
  ])
  if incidents.empty?
    summary << "No recognized runner incidents were recorded."
  else
    incidents.each { |incident| summary << "- #{incident}" }
  end
  summary.concat([
    "",
    "Private runner records were cross-checked against the published host, model,",
    "approval, sandbox, reasoning, workspace, prompt, response, and stop fields",
    "and inspected for incidents. They were excluded because they contain",
    "ephemeral session identifiers and machine-local workspace paths.",
    "Results apply to these cases, descriptions, controls, model, and host version."
  ])
  archive_output.write("summary.md", summary.join("\n") + "\n")

  metadata_runs = normalized_results.map do |result|
    id = result.fetch("id")
    run = {
      "id" => "#{options[:phase]}-#{id}",
      "case" => id,
      "phase" => options[:phase],
      "grade" => result.fetch("pass") ? "pass" : "fail",
      "exitStatus" => result.fetch("exitStatus"),
      "elapsedSeconds" => result["elapsedSeconds"],
      "stopStatus" => "completed with CLI exit #{result.fetch("exitStatus")}",
      "artifacts" => [
        "candidate-descriptions.txt",
        "prompts/#{id}.txt",
        "responses/#{id}.txt"
      ]
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
    "workspace" => "separate initialized disposable Git repository with no zstack files",
    "permissions" => if HOST_FAMILY == "codex"
                       "read-only sandbox; approval policy never"
                     elsif HOST_FAMILY == "claude"
                       "safe mode; no built-in tools; permission mode dontAsk"
                     else
                       "read-only sandbox; no built-in tools; permission mode dontAsk"
                     end,
    "webSearch" => controls.fetch("webSearch"),
    "subagents" => controls.fetch("subagents"),
    "reasoningEffort" => controls.fetch("reasoningEffort"),
    "ephemeralSession" => true,
    "timeoutSecondsPerCase" => controls.fetch("timeoutSecondsPerCase"),
    "maxCasesPerRun" => controls.fetch("maxCasesPerRun"),
    "maxHostOutputBytesPerCase" => controls.fetch("maxHostOutputBytesPerCase"),
    "maxPromptBytesPerCase" => controls.fetch("maxPromptBytesPerCase"),
    "maxPromptBytesPerRun" => controls.fetch("maxPromptBytesPerRun"),
    "promptBytes" => controls.fetch("promptBytes"),
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
    "maxRuntimeHostHomeBytes" => controls.fetch("maxRuntimeHostHomeBytes"),
    "skillSearch" => false,
    "apps" => false
  }
  if HOST_FAMILY == "codex"
    execution_defaults["model"] = controls.fetch("model")
    execution_defaults["maxTurns"] = 1
    execution_defaults["isolatedHostHome"] = true
    execution_defaults["ambientDesktopContextDisabled"] = controls.fetch("ambientDesktopContextDisabled")
  elsif HOST_FAMILY == "claude"
    execution_defaults["requestedModel"] = controls.fetch("model")
    execution_defaults["sessionPersistence"] = false
    execution_defaults["maxBudgetUsdPerCase"] = controls.fetch("maxBudgetUsdPerCase")
  else
    execution_defaults["requestedModel"] = controls.fetch("model")
    execution_defaults["sessionPersistence"] = false
    execution_defaults["maxTurns"] = controls.fetch("maxTurnsPerCase")
    execution_defaults["ambientAgentSkillsMayBeDiscovered"] = true
  end
  host_metadata = { "name" => controls.fetch("host"), "version" => host_version }
  host_metadata["revision"] = host_revision if host_revision
  metadata = {
    "schemaVersion" => 2,
    "archiveDate" => archive_date,
    "suite" => "routing",
    "host" => host_metadata,
    "provenance" => { "status" => "complete", "gaps" => [] },
    "executionDefaults" => execution_defaults,
    "runs" => metadata_runs,
    "runnerIncidents" => incidents,
    "archiveNote" => "Prompts and final responses are verbatim runner files. Private logs and structured host records corroborated execution controls and retained bytes, then were excluded because they contain ephemeral session identifiers and machine-local paths."
  }
  archive_output.write("run.json", json_content(metadata))
  archive_output.write("runner-controls.json", json_content(controls))
  archive_output.write("runner-results.json", json_content(results))
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
  assert_routing_manifest_unchanged!(routing_manifest_content)
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
  assert_routing_manifest_unchanged!(routing_manifest_content)
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
