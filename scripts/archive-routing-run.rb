#!/usr/bin/env ruby
# Shared atomic archiver for isolated host-specific routing runs.

require "date"
require "digest"
require "fileutils"
require "json"
require "open3"
require "optparse"
require "pathname"
require "rbconfig"
require "set"
require "tmpdir"
require "yaml"
require_relative "lib/eval_codex_home"
require_relative "lib/eval_host_contracts"
require_relative "lib/eval_private_paths"

ROOT = File.expand_path("..", __dir__)
RUNS_ROOT = File.join(ROOT, "evals", "runs")
ROUTING_PATH = File.join(ROOT, "evals", "routing.yaml")
ARCHIVE_MANIFEST_SCRIPT = File.join(ROOT, "scripts", "generate-evidence-manifests.rb")
EVIDENCE_VALIDATOR = File.join(ROOT, "scripts", "validate-evidence.rb")
RAW_MANIFEST_HEADER = "sha256                                                            bytes  path"
HOST_FAMILY = ENV.fetch("ZSTACK_ROUTING_HOST", "")
HOST_NAMES = { "codex" => "Codex CLI", "claude" => "Claude Code", "grok" => "Grok Build" }.freeze
HOST_NAME = HOST_NAMES[HOST_FAMILY]
raise "set ZSTACK_ROUTING_HOST to codex, claude, or grok" unless HOST_NAME
STRUCTURED_HOSTS = %w[claude grok].freeze
EVAL_HOST_CONTRACTS = Zstack::EvalHostContracts
EVAL_CODEX_HOME = Zstack::EvalCodexHome
EVAL_PRIVATE_PATHS = Zstack::EvalPrivatePaths
GROK_SYSTEM_PROMPT = EVAL_HOST_CONTRACTS.grok_system_prompt("routing")
GROK_ISOLATED_CONFIG = EVAL_HOST_CONTRACTS::GROK_ISOLATED_CONFIG
GROK_FINAL_MARKER = EVAL_HOST_CONTRACTS::GROK_FINAL_MARKER
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

def fail_usage(message, parser = nil)
  warn "ERROR: #{message}"
  warn parser if parser
  exit 2
end

def load_json(path)
  data = JSON.parse(File.read(path))
  raise "#{path}: JSON root must be an object or array" unless data.is_a?(Hash) || data.is_a?(Array)

  data
rescue Errno::ENOENT, JSON::ParserError => e
  raise "cannot load #{path}: #{e.message}"
end

def load_routing_cases
  document = YAML.safe_load(
    File.read(ROUTING_PATH),
    permitted_classes: [],
    permitted_symbols: [],
    aliases: false,
    filename: ROUTING_PATH
  )
  Array(document.fetch("cases")).to_h { |entry| [entry.fetch("id"), entry] }
rescue Errno::ENOENT, KeyError, Psych::Exception => e
  raise "cannot load evals/routing.yaml: #{e.message}"
end

def regular_source_file(run_directory, relative_path)
  unless relative_path.is_a?(String) && !relative_path.empty?
    raise "runner path must be a non-empty relative string"
  end
  candidate = Pathname.new(relative_path)
  clean = candidate.cleanpath.to_s
  unless !candidate.absolute? && clean == relative_path && !clean.start_with?("../") && clean != "."
    raise "runner path must be canonical and stay inside the run directory: #{relative_path}"
  end

  path = File.join(run_directory, relative_path)
  raise "runner file must not be a symbolic link: #{relative_path}" if File.symlink?(path)
  raise "runner file is missing: #{relative_path}" unless File.file?(path)
  unless File.realpath(path).start_with?("#{File.realpath(run_directory)}/")
    raise "runner file resolves outside the run directory: #{relative_path}"
  end

  path
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
  unless controls["timeoutSecondsPerCase"].is_a?(Integer) && controls["timeoutSecondsPerCase"].positive?
    raise "controls.json: timeoutSecondsPerCase must be a positive integer"
  end
  unless controls.fetch("cases") == result_ids
    raise "controls.json: cases must exactly match results.json order"
  end
  unless controls["privateCaseIdentifiers"] == EVAL_PRIVATE_PATHS::STRATEGY
    raise "controls.json: private case-identifier strategy changed"
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
    unless controls["maxBudgetUsdPerCase"].is_a?(Numeric) && controls["maxBudgetUsdPerCase"].positive?
      raise "controls.json: Claude maxBudgetUsdPerCase must be positive"
    end
    raise "controls.json: Claude resultFormat must be json" unless controls["resultFormat"] == "json"
  else
    raise "controls.json: Grok sandbox must be read-only" unless controls["sandbox"] == "read-only"
    raise "controls.json: Grok approval policy must be dontAsk" unless controls["approvalPolicy"] == "dontAsk"
    raise "controls.json: Grok prompt transport must be file" unless controls["promptTransport"] == "generated prompt through file"
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
    unless controls["maxTurnsPerCase"].is_a?(Integer) && controls["maxTurnsPerCase"].positive?
      raise "controls.json: Grok maxTurnsPerCase must be positive"
    end
    raise "controls.json: Grok resultFormat must be json" unless controls["resultFormat"] == "json"
  end
end

def parse_response(path, candidate_ids)
  raw = File.read(path).strip
  lines = raw.lines.map(&:strip).reject(&:empty?)
  selection_match = lines.first&.match(/\Aselection:\s*(z-[a-z0-9-]+|none)\s*\z/i)
  reason_match = lines[1]&.match?(/\Areason:\s*\S.+\z/i)
  selected = selection_match && selection_match[1].downcase
  allowed = selected == "none" || candidate_ids.include?(selected)
  format_valid = lines.length == 2 && selection_match && reason_match && allowed
  [selected, !!format_valid]
end

def candidate_ids(path)
  ids = File.readlines(path, chomp: true).map do |line|
    id, description = line.split("\t", 2)
    unless id&.match?(/\Az-[a-z0-9-]+\z/) && description.is_a?(String) && !description.empty?
      raise "candidate-descriptions.txt has an invalid line"
    end
    id
  end
  raise "candidate-descriptions.txt has duplicate ids" unless ids.uniq.length == ids.length
  raise "candidate-descriptions.txt has no candidates" if ids.empty?

  ids
end

def reject_private_runner_data!(path)
  content = File.read(path)
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

def codex_runner_incidents(results, controls)
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
    content = File.read(log_path)
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
    prompt = File.read(result.fetch("promptSource")).rstrip
    response = File.read(result.fetch("responseSource")).strip
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

def claude_runner_incidents(results, controls)
  seen_tokens = Set.new
  results.each_with_object([]) do |result, incidents|
    id = result.fetch("id")
    invocation = load_json(result.fetch("invocationSource"))
    raw = load_json(result.fetch("rawResultSource"))
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
    prompt = File.binread(result.fetch("promptSource"))
    unless invocation["promptSha256"] == Digest::SHA256.hexdigest(prompt) && invocation["promptBytes"] == prompt.bytesize
      raise "#{id}: invocation prompt digest or byte count changed"
    end
    raise "#{id}: Claude result type must be result" unless raw["type"] == "result"
    raise "#{id}: Claude result subtype must be success" unless raw["subtype"] == "success"
    raise "#{id}: Claude result is marked as an API error" unless raw["is_error"] == false
    response = File.read(result.fetch("responseSource"))
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
    denials = raw.fetch("permission_denials", [])
    raise "#{id}: Claude permission_denials must be an array" unless denials.is_a?(Array)
    raise "#{id}: permissionDenials differs from Claude JSON" unless result["permissionDenials"] == denials.length
    raise "#{id}: Claude routing run recorded a permission denial" unless denials.empty?
    raise "#{id}: Claude API status must be null for a complete run" unless result["apiErrorStatus"].nil?
    raise "#{id}: Claude error category must be null for a complete run" unless result["errorCategory"].nil?
    raise "#{id}: parseError must be null" unless result["parseError"].nil?

    stderr = File.read(result.fetch("logSource"))
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

def grok_runner_incidents(results, controls)
  seen_tokens = Set.new
  results.each_with_object([]) do |result, incidents|
    id = result.fetch("id")
    invocation = load_json(result.fetch("invocationSource"))
    raw = load_json(result.fetch("rawResultSource"))
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
    unless private_prompt_path.is_a?(String) && File.basename(private_prompt_path) == "#{private_token}.txt" &&
           File.basename(File.dirname(private_prompt_path)) == ".prompt-files" &&
           File.dirname(File.dirname(private_prompt_path)) == File.dirname(workspace)
      raise "#{id}: Grok prompt transport path is not opaque and isolated"
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
    unless auth_path.is_a?(String) && Pathname.new(auth_path).absolute? && !auth_path.empty?
      raise "#{id}: Grok auth path must be an absolute private path"
    end
    unless environment["GROK_MANAGED_MCPS_ENABLED"] == "0" && environment["GROK_OFFICIAL_MARKETPLACE_AUTO_REGISTER"] == "0"
      raise "#{id}: Grok environment isolation flags changed"
    end
    unless invocation["isolatedConfigSha256"] == Digest::SHA256.hexdigest(GROK_ISOLATED_CONFIG) &&
           invocation["isolatedConfigBytes"] == GROK_ISOLATED_CONFIG.bytesize
      raise "#{id}: Grok isolated config digest or byte count changed"
    end
    prompt = File.binread(result.fetch("promptSource"))
    unless invocation["promptSha256"] == Digest::SHA256.hexdigest(prompt) && invocation["promptBytes"] == prompt.bytesize
      raise "#{id}: invocation prompt digest or byte count changed"
    end
    raise "#{id}: Grok result is marked as an API error" if raw["type"] == "error"
    response = File.read(result.fetch("responseSource"))
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
    raise "#{id}: tokenUsage differs from Grok JSON" unless result["tokenUsage"] == raw["usage"]
    raise "#{id}: Grok token usage must be an object" unless result["tokenUsage"].is_a?(Hash)
    raise "#{id}: parseError must be null" unless result["parseError"].nil?

    incidents << "#{id}: discarded #{prefinal_bytes} pre-final narration bytes from private Grok output." if prefinal_bytes.positive?
    stderr = File.read(result.fetch("logSource"))
    incidents << "#{id}: Grok wrote #{stderr.bytesize} private stderr bytes." unless stderr.empty?
    incidents << "#{id}: Grok attempted MCP startup despite the MCP tool exclusion." if stderr.match?(/MCP server/i)
  end
end

def runner_incidents(results, controls)
  case HOST_FAMILY
  when "codex" then codex_runner_incidents(results, controls)
  when "claude" then claude_runner_incidents(results, controls)
  else grok_runner_incidents(results, controls)
  end
end

def write_json(path, data)
  content = JSON.pretty_generate(data)
  content = content.gsub(/\[\n[[:space:]]*\]/, "[]").gsub(/\{\n[[:space:]]*\}/, "{}")
  File.write(path, content + "\n")
end

def write_raw_manifest(raw_directory)
  paths = Dir.glob(File.join(raw_directory, "**", "*")).select do |path|
    File.file?(path) && !File.basename(path).start_with?("artifact-manifest")
  end.sort
  lines = [RAW_MANIFEST_HEADER]
  paths.each do |path|
    relative = Pathname.new(path).relative_path_from(Pathname.new(raw_directory)).to_s
    lines << "#{Digest::SHA256.file(path).hexdigest}  #{File.size(path)}  #{relative}"
  end
  File.write(File.join(raw_directory, "artifact-manifest.txt"), lines.join("\n") + "\n")
end

def run_checked(*command)
  output, error, status = Open3.capture3(*command, stdin_data: "")
  return output.strip if status.success?

  detail = [output, error].reject(&:empty?).join("\n").strip
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
unless options[:archive].match?(/\A\d{4}-\d{2}-\d{2}-[a-z0-9][a-z0-9-]*\z/)
  fail_usage("--archive must use YYYY-MM-DD-kebab-slug")
end
unless options[:phase].match?(/\A[a-z0-9][a-z0-9-]*\z/)
  fail_usage("--phase must be kebab-case")
end
archive_date = options[:archive][0, 10]
begin
  Date.iso8601(archive_date)
rescue Date::Error
  fail_usage("--archive begins with an invalid calendar date")
end

run_directory = File.expand_path(options[:run_directory])
fail_usage("--run-dir must be a real directory") unless File.directory?(run_directory) && !File.symlink?(run_directory)

temporary_archive = nil
published_archive = nil
begin
  controls_path = regular_source_file(run_directory, "controls.json")
  results_path = regular_source_file(run_directory, "results.json")
  candidates_path = regular_source_file(run_directory, "candidate-descriptions.txt")
  controls = load_json(controls_path)
  results = load_json(results_path)
  raise "controls.json must contain an object" unless controls.is_a?(Hash)
  raise "results.json must contain a non-empty array" unless results.is_a?(Array) && !results.empty?
  raise "results.json entries must be objects" unless results.all? { |entry| entry.is_a?(Hash) }

  result_ids = results.map { |entry| entry["id"] }
  unless result_ids.all? { |id| id.is_a?(String) && id.match?(/\A[a-z0-9][a-z0-9-]*\z/) } && result_ids.uniq.length == result_ids.length
    raise "results.json ids must be unique kebab-case strings"
  end
  validate_controls!(controls, result_ids)
  candidates = candidate_ids(candidates_path)
  routing_cases = load_routing_cases

  source_files = [controls_path, results_path, candidates_path]
  normalized_results = results.map do |result|
    id = result.fetch("id")
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
    prompt_path = regular_source_file(run_directory, expected_prompt_path)
    response_path = regular_source_file(run_directory, expected_response_path)
    log_path = regular_source_file(run_directory, expected_log_path)
    source_files.concat([prompt_path, response_path])
    prompt = File.read(prompt_path)
    raise "#{id}: prompt leaked expected_skill" if prompt.include?("expected_skill")
    unless prompt.include?(registered.fetch("prompt"))
      raise "#{id}: prompt does not contain the registered user request"
    end

    selected, format_valid = parse_response(response_path, candidates)
    unless result["selected"] == selected && result["formatValid"] == format_valid
      raise "#{id}: retained response does not match results.json parsing"
    end
    exit_status = result["exitStatus"]
    raise "#{id}: exitStatus must be a non-negative integer" unless exit_status.is_a?(Integer) && exit_status >= 0
    raise "#{id}: executionCompleted must be true for archiving" unless result["executionCompleted"] == true
    raise "#{id}: timedOut must be false for archiving" unless result["timedOut"] == false
    raise "#{id}: responsePrivacyError must be null" unless result["responsePrivacyError"].nil?
    passed = result.fetch("executionCompleted") && exit_status.zero? && format_valid && selected == result.fetch("expected")
    raise "#{id}: retained response grade does not match results.json" unless result["pass"] == passed

    normalized = {
      "id" => id,
      "expected" => result.fetch("expected"),
      "selected" => selected,
      "pass" => passed,
      "exitStatus" => exit_status,
      "elapsedSeconds" => result["elapsedSeconds"],
      "promptSource" => prompt_path,
      "responseSource" => response_path,
      "logSource" => log_path
    }
    if STRUCTURED_HOSTS.include?(HOST_FAMILY)
      expected_raw_path = "logs/#{id}.json"
      expected_invocation_path = "logs/#{id}.invocation.json"
      unless result["rawResultPath"] == expected_raw_path && result["invocationPath"] == expected_invocation_path
        raise "#{id}: structured-host private paths do not match the canonical output layout"
      end
      normalized["rawResultSource"] = regular_source_file(run_directory, expected_raw_path)
      normalized["invocationSource"] = regular_source_file(run_directory, expected_invocation_path)
      fields = if HOST_FAMILY == "claude"
                 %w[actualModels numTurns stopReason terminalReason totalCostUsd permissionDenials apiErrorStatus errorCategory parseError]
               else
                 %w[actualModels numTurns stopReason totalCostUsd tokenUsage prefinalNarrationBytes finalBoundaryError apiErrorStatus errorCategory parseError]
               end
      fields.each { |field| normalized[field] = result[field] }
    end
    normalized
  end
  source_files.each { |path| reject_private_runner_data!(path) }
  incidents = runner_incidents(normalized_results, controls)

  FileUtils.mkdir_p(RUNS_ROOT)
  raise "evals/runs must not be a symbolic link" if File.symlink?(RUNS_ROOT)
  target = File.join(RUNS_ROOT, options[:archive])
  raise "archive target already exists: #{target}" if File.exist?(target) || File.symlink?(target)

  run_checked(RbConfig.ruby, EVIDENCE_VALIDATOR)
  temporary_archive = Dir.mktmpdir(".zstack-routing-archive-", RUNS_ROOT)
  raw_directory = File.join(temporary_archive, "raw")
  raw_prompts = File.join(raw_directory, "prompts")
  raw_responses = File.join(raw_directory, "responses")
  FileUtils.mkdir_p(raw_prompts)
  FileUtils.mkdir_p(raw_responses)
  FileUtils.cp(candidates_path, File.join(raw_directory, "candidate-descriptions.txt"))
  normalized_results.each do |result|
    FileUtils.cp(result.fetch("promptSource"), File.join(raw_prompts, "#{result.fetch("id")}.txt"))
    FileUtils.cp(result.fetch("responseSource"), File.join(raw_responses, "#{result.fetch("id")}.txt"))
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
  File.write(File.join(temporary_archive, "prompts.md"), prompt_index.join("\n") + "\n")

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
  File.write(File.join(temporary_archive, "summary.md"), summary.join("\n") + "\n")

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
    "webSearch" => false,
    "subagents" => false,
    "reasoningEffort" => controls.fetch("reasoningEffort"),
    "ephemeralSession" => true,
    "timeoutSecondsPerCase" => controls.fetch("timeoutSecondsPerCase"),
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
  write_json(File.join(temporary_archive, "run.json"), metadata)
  write_json(File.join(temporary_archive, "runner-controls.json"), controls)
  write_json(File.join(temporary_archive, "runner-results.json"), results)
  write_raw_manifest(raw_directory)

  run_checked(RbConfig.ruby, ARCHIVE_MANIFEST_SCRIPT, temporary_archive)
  File.rename(temporary_archive, target)
  temporary_archive = nil
  published_archive = target
  validation_output = run_checked(RbConfig.ruby, EVIDENCE_VALIDATOR)
  puts "ARCHIVE=#{Pathname.new(target).relative_path_from(Pathname.new(ROOT))}"
  puts validation_output
rescue Interrupt
  warn "ERROR: interrupted"
  exit 130
rescue StandardError => e
  if published_archive && File.directory?(published_archive)
    FileUtils.remove_entry(published_archive)
    published_archive = nil
  end
  warn "ERROR: #{e.message}"
  exit 2
ensure
  FileUtils.remove_entry(temporary_archive) if temporary_archive && File.exist?(temporary_archive)
end
