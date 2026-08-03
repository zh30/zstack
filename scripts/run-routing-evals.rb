#!/usr/bin/env ruby
# Shared description-only routing runner for isolated host-specific adapters.

require "digest"
require "fileutils"
require "json"
require "optparse"
require "tmpdir"
require "yaml"
require_relative "lib/eval_codex_home"
require_relative "lib/eval_executable"
require_relative "lib/eval_grok_home"
require_relative "lib/eval_git_workspace"
require_relative "lib/eval_host_contracts"
require_relative "lib/eval_host_version"
require_relative "lib/eval_identifier"
require_relative "lib/eval_input_file"
require_relative "lib/eval_limits"
require_relative "lib/eval_output_directory"
require_relative "lib/eval_output_file"
require_relative "lib/eval_output_tree"
require_relative "lib/eval_owned_directory"
require_relative "lib/eval_private_paths"
require_relative "lib/eval_prompt_writer"
require_relative "lib/eval_process_supervisor"
require_relative "lib/eval_resource_monitor"
require_relative "lib/eval_routing_prompt"
require_relative "lib/eval_skill_source"
require_relative "lib/eval_strict_yaml"
require_relative "lib/eval_workspace_watchdog"

ROOT = File.expand_path("..", __dir__)
CATALOG_PATH = File.join(ROOT, "catalog.yaml")
ROUTING_PATH = File.join(ROOT, "evals", "routing.yaml")
HOST_FAMILY = ENV.fetch("ZSTACK_ROUTING_HOST", "")
HOST_SPECS = {
  "codex" => {
    display_name: "Codex CLI",
    executable: "codex",
    model: "gpt-5.6-sol",
    jobs: 4,
    reasoning_levels: %w[low medium high xhigh max ultra]
  },
  "claude" => {
    display_name: "Claude Code",
    executable: "claude",
    model: "sonnet",
    jobs: 1,
    reasoning_levels: %w[low medium high xhigh max]
  },
  "grok" => {
    display_name: "Grok Build",
    executable: "grok",
    model: "grok-4.5",
    jobs: 1,
    reasoning_levels: %w[low medium high]
  }
}.freeze
HOST_SPEC = HOST_SPECS[HOST_FAMILY]
raise "set ZSTACK_ROUTING_HOST to codex, claude, or grok" unless HOST_SPEC
EVAL_ROUTING_PROMPT = Zstack::EvalRoutingPrompt
DISABLED_FEATURES = %w[
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
STRUCTURED_HOSTS = %w[claude grok].freeze
WRAPPER_STYLES = %w[auto en zh].freeze
EVAL_HOST_CONTRACTS = Zstack::EvalHostContracts
EVAL_CODEX_HOME = Zstack::EvalCodexHome
EVAL_EXECUTABLE = Zstack::EvalExecutable
EVAL_GROK_HOME = Zstack::EvalGrokHome
EVAL_PRIVATE_PATHS = Zstack::EvalPrivatePaths
EVAL_PROCESS_SUPERVISOR = Zstack::EvalProcessSupervisor
EVAL_OUTPUT_DIRECTORY = Zstack::EvalOutputDirectory
EVAL_OUTPUT_FILE = Zstack::EvalOutputFile
GROK_SYSTEM_PROMPT = EVAL_HOST_CONTRACTS.grok_system_prompt("routing")
GROK_FINAL_MARKER = EVAL_HOST_CONTRACTS::GROK_FINAL_MARKER
GROK_ISOLATED_CONFIG = EVAL_HOST_CONTRACTS::GROK_ISOLATED_CONFIG
GROK_PROMPT_DESCRIPTOR = EVAL_HOST_CONTRACTS::GROK_PROMPT_DESCRIPTOR
GROK_PROMPT_PATH = EVAL_HOST_CONTRACTS::GROK_PROMPT_PATH

def fail_usage(message, parser = nil)
  warn "ERROR: #{message}"
  warn parser if parser
  exit 2
end

def load_yaml(path)
  Zstack::EvalStrictYaml.parse(Zstack::EvalInputFile.read(path, label: path, root: ROOT), path)
rescue Errno::ENOENT, Psych::Exception => e
  raise "cannot load #{path.delete_prefix("#{ROOT}/")}: #{e.message}"
end

def load_frontmatter(path)
  content = Zstack::EvalInputFile.read(path, label: path, root: ROOT)
  match = content.match(/\A---\r?\n(?<yaml>.*?)\r?\n---(?:\r?\n|\z)/m)
  raise "#{path.delete_prefix("#{ROOT}/")}: missing closed frontmatter" unless match

  data = Zstack::EvalStrictYaml.parse(match[:yaml], path)
  raise "#{path.delete_prefix("#{ROOT}/")}: frontmatter must be a mapping" unless data.is_a?(Hash)

  data
rescue Errno::ENOENT, Psych::Exception => e
  raise "cannot load #{path.delete_prefix("#{ROOT}/")}: #{e.message}"
end

def active_candidates(description_limit)
  catalog = load_yaml(CATALOG_PATH)
  all_entries = catalog.fetch("skills")
  Zstack::EvalIdentifier.validate_unique_entries!(all_entries, label: "catalog skills")
  entries = all_entries.select { |entry| entry["status"] == "active" }
  raise "catalog.yaml has no active skills" if entries.empty?

  entries.map do |entry|
    id = entry.fetch("id")
    path = Zstack::EvalSkillSource.resolve(
      repository_root: ROOT,
      relative_path: entry.fetch("path"),
      skill_id: id
    )
    frontmatter = load_frontmatter(File.join(path, "SKILL.md"))
    raise "#{id}: frontmatter name does not match catalog id" unless frontmatter["name"] == id

    description = frontmatter.fetch("description").gsub(/\s+/, " ").strip
    if description_limit && description.length > description_limit
      description = "#{description[0, description_limit]}…"
    end
    [id, description]
  end.sort_by(&:first)
end

def load_routing_cases
  document = load_yaml(ROUTING_PATH)
  cases = document.fetch("cases")
  raise "evals/routing.yaml has no cases" if cases.empty?
  Zstack::EvalIdentifier.validate_unique_entries!(cases, label: "routing cases")

  cases.each do |entry|
    %w[prompt expected_skill].each do |field|
      value = entry[field]
      raise "routing case is missing #{field}" unless value.is_a?(String) && !value.empty?
    end
    unless entry["expected_skill"] == "none"
      Zstack::EvalIdentifier.validate!(entry.fetch("expected_skill"), label: "#{entry.fetch("id")} expected skill")
    end
  end
  cases
end

def select_cases(cases, ids, prefix)
  known_ids = cases.map { |entry| entry.fetch("id") }
  missing_ids = ids - known_ids
  raise "unknown routing case(s): #{missing_ids.join(", ")}" unless missing_ids.empty?

  selected = if ids.empty? && prefix.nil?
               cases
             else
               cases.select do |entry|
                 ids.include?(entry.fetch("id")) || (prefix && entry.fetch("id").start_with?(prefix))
               end
             end
  raise "no routing cases matched the selectors" if selected.empty?

  selected
end


def prepare_output_directory(requested_path)
  EVAL_OUTPUT_DIRECTORY.prepare(requested_path, prefix: "zstack-#{HOST_FAMILY}-routing-")
end

def host_version(executable)
  Zstack::EvalHostVersion.probe(executable, display_name: HOST_SPEC.fetch(:display_name))
end

def parse_response(content, candidate_ids)
  raw = content.strip
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

def response_privacy_error(content, workspace)
  private_token = File.basename(workspace)
  if content.include?(workspace) || content.include?(private_token) ||
     content.match?(/zstack-(?:codex|claude|grok)-routing-workspaces-/)
    "final response contains a private workspace path"
  end
end

options = {
  case_ids: [],
  case_prefix: nil,
  codex_auth_path: File.expand_path("~/.codex/auth.json"),
  description_limit: nil,
  dry_run: false,
  executable: HOST_SPEC.fetch(:executable),
  grok_auth_path: File.expand_path("~/.grok/auth.json"),
  jobs: HOST_SPEC.fetch(:jobs),
  max_budget_usd: 1.0,
  max_turns: 2,
  model: HOST_SPEC.fetch(:model),
  output: nil,
  reasoning: "low",
  timeout_seconds: 600,
  wrapper: "auto"
}

parser = OptionParser.new do |opts|
  opts.banner = "Usage: ruby scripts/run-#{HOST_FAMILY}-routing-evals.rb [options]"
  opts.on("--case ID", "Run one case; repeat to select more") { |value| options[:case_ids] << value }
  opts.on("--case-prefix PREFIX", "Run case ids beginning with PREFIX") { |value| options[:case_prefix] = value }
  opts.on("--output DIR", "Write the run to DIR (must be new or empty)") { |value| options[:output] = value }
  opts.on("--jobs N", Integer, "Concurrent #{HOST_SPEC.fetch(:display_name)} processes (default: #{HOST_SPEC.fetch(:jobs)})") { |value| options[:jobs] = value }
  opts.on("--model MODEL", "#{HOST_SPEC.fetch(:display_name)} model (default: #{HOST_SPEC.fetch(:model)})") { |value| options[:model] = value }
  opts.on("--reasoning LEVEL", "#{HOST_SPEC.fetch(:reasoning_levels).join(", ")}") { |value| options[:reasoning] = value }
  opts.on("--timeout-seconds N", Integer, "Per-case wall-clock timeout (default: 600)") { |value| options[:timeout_seconds] = value }
  opts.on("--truncate-descriptions N", Integer, "Keep the first N Unicode characters") do |value|
    options[:description_limit] = value
  end
  opts.on("--wrapper STYLE", "#{WRAPPER_STYLES.join(", ")}; auto follows each prompt") { |value| options[:wrapper] = value }
  if HOST_FAMILY == "codex"
    opts.on("--codex PATH", "Codex executable (default: codex)") { |value| options[:executable] = value }
    opts.on("--auth-path PATH", "Optional Codex auth file copied into the isolated host home (default: ~/.codex/auth.json)") { |value| options[:codex_auth_path] = File.expand_path(value) }
  elsif HOST_FAMILY == "claude"
    opts.on("--claude PATH", "Claude executable (default: claude)") { |value| options[:executable] = value }
    opts.on("--max-budget-usd AMOUNT", Float, "Per-case Claude API budget (default: 1.0)") { |value| options[:max_budget_usd] = value }
  else
    opts.on("--grok PATH", "Grok executable (default: grok)") { |value| options[:executable] = value }
    opts.on("--auth-path PATH", "Grok auth file used with an isolated GROK_HOME (default: ~/.grok/auth.json)") { |value| options[:grok_auth_path] = File.expand_path(value) }
    opts.on("--max-turns N", Integer, "Maximum Grok agent turns per case (default: 2)") { |value| options[:max_turns] = value }
  end
  opts.on("--dry-run", "Write candidates and prompts without invoking #{HOST_SPEC.fetch(:display_name)}") { options[:dry_run] = true }
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
unless options[:jobs].between?(1, Zstack::EvalLimits::MAX_RUNNER_JOBS)
  fail_usage("--jobs must be between 1 and #{Zstack::EvalLimits::MAX_RUNNER_JOBS}")
end
unless options[:timeout_seconds].between?(1, Zstack::EvalLimits::MAX_RUNNER_TIMEOUT_SECONDS)
  fail_usage("--timeout-seconds must be between 1 and #{Zstack::EvalLimits::MAX_RUNNER_TIMEOUT_SECONDS}")
end
if options[:description_limit] && !options[:description_limit].between?(80, Zstack::EvalLimits::MAX_DESCRIPTION_CHARACTERS)
  fail_usage("--truncate-descriptions must be between 80 and #{Zstack::EvalLimits::MAX_DESCRIPTION_CHARACTERS}")
end
unless HOST_SPEC.fetch(:reasoning_levels).include?(options[:reasoning])
  fail_usage("unknown reasoning level for #{HOST_SPEC.fetch(:display_name)}: #{options[:reasoning]}")
end
fail_usage("unknown wrapper style: #{options[:wrapper]}") unless WRAPPER_STYLES.include?(options[:wrapper])
if HOST_FAMILY == "claude" && (!options[:max_budget_usd].finite? || !options[:max_budget_usd].positive?)
  fail_usage("--max-budget-usd must be finite and greater than zero")
end
if HOST_FAMILY == "grok" && !options[:max_turns].between?(1, Zstack::EvalLimits::MAX_GROK_TURNS)
  fail_usage("--max-turns must be between 1 and #{Zstack::EvalLimits::MAX_GROK_TURNS}")
end

workspace_root = nil
workspace_root_identity = nil
output_reservation = nil
running_pids = []
Signal.trap("TERM") { raise Interrupt }
begin
  all_cases = load_routing_cases
  selected_cases = select_cases(all_cases, options[:case_ids].uniq, options[:case_prefix])
  if selected_cases.length > Zstack::EvalLimits::MAX_RUNNER_CASES
    raise "selected run has #{selected_cases.length} cases; maximum is #{Zstack::EvalLimits::MAX_RUNNER_CASES}"
  end
  manifest_indexes = all_cases.each_with_index.to_h { |entry, index| [entry.fetch("id"), index] }
  candidates = active_candidates(options[:description_limit])
  candidate_ids = candidates.map(&:first)
  unknown_targets = selected_cases.map { |entry| entry.fetch("expected_skill") }.uniq - candidate_ids - ["none"]
  raise "selected cases reference unknown active skills: #{unknown_targets.join(", ")}" unless unknown_targets.empty?

  output_reservation = prepare_output_directory(options[:output])
  output_directory = output_reservation.path
  prompts_directory = File.join(output_directory, "prompts")
  responses_directory = File.join(output_directory, "responses")
  logs_directory = File.join(output_directory, "logs")
  FileUtils.mkdir_p(prompts_directory)

  EVAL_OUTPUT_FILE.write_exclusive(
    File.join(output_directory, "candidate-descriptions.txt"),
    candidates.map { |id, description| "#{id}\t#{description}\n" }.join,
    max_bytes: Zstack::EvalLimits::MAX_RUN_PROMPT_BYTES,
    label: "candidate descriptions"
  )

  prompt_budget = Zstack::EvalPromptWriter::Budget.new
  generated_prompts = {}
  selected_cases.each do |entry|
    id = entry.fetch("id")
    rotation = manifest_indexes.fetch(id) % candidates.length
    ordered_candidates = candidates.rotate(rotation)
    style = EVAL_ROUTING_PROMPT.wrapper_style(options[:wrapper], entry.fetch("prompt"))
    prompt = EVAL_ROUTING_PROMPT.build(ordered_candidates, entry.fetch("prompt"), style, options[:description_limit])
    generated_prompts[id] = prompt.dup.freeze
    prompt_budget.write(File.join(prompts_directory, "#{id}.txt"), prompt)
  end

  host_executable = nil
  unless options[:dry_run]
    host_executable = EVAL_EXECUTABLE.resolve(
      options[:executable],
      display_name: HOST_SPEC.fetch(:display_name)
    )
    options[:executable] = host_executable.path
  end
  version = options[:dry_run] ? nil : host_version(options[:executable])
  EVAL_EXECUTABLE.verify!(host_executable, display_name: HOST_SPEC.fetch(:display_name)) if host_executable
  controls = {
    "schemaVersion" => 1,
    "host" => HOST_SPEC.fetch(:display_name),
    "hostVersion" => version,
    "model" => options[:model],
    "reasoningEffort" => options[:reasoning],
    "sandbox" => HOST_FAMILY == "claude" ? "no built-in tools" : "read-only",
    "approvalPolicy" => HOST_FAMILY == "codex" ? "never" : "dontAsk",
    "ephemeralSession" => true,
    "promptTransport" => HOST_FAMILY == "grok" ? "generated prompt through anonymous descriptor" : "generated prompt through stdin",
    "privateCaseIdentifiers" => EVAL_PRIVATE_PATHS::STRATEGY,
    "webSearch" => false,
    "subagents" => false,
    "jobs" => options[:jobs],
    "maxCasesPerRun" => Zstack::EvalLimits::MAX_RUNNER_CASES,
    "maxPromptBytesPerCase" => Zstack::EvalLimits::MAX_PROMPT_BYTES,
    "maxPromptBytesPerRun" => Zstack::EvalLimits::MAX_RUN_PROMPT_BYTES,
    "promptBytes" => prompt_budget.total_bytes,
    "timeoutSecondsPerCase" => options[:timeout_seconds],
    "maxHostOutputBytesPerCase" => EVAL_PROCESS_SUPERVISOR::MAX_HOST_OUTPUT_BYTES,
    "descriptionCharacterLimit" => options[:description_limit],
    "wrapper" => options[:wrapper],
    "candidateRotation" => "full manifest index modulo candidate count",
    "runtimeTreeMonitoring" => true,
    "concurrentRuntimeMonitoring" => true,
    "pidMonitoringStartsAtSpawn" => true,
    "sharedRootMonitoring" => true,
    "privatePromptIntegrityMonitoring" => HOST_FAMILY == "grok",
    "outputDirectoryIdentityMonitoring" => true,
    "outputTreeMonitoring" => true,
    "exclusiveRunnerOutputs" => true,
    "workspaceViolationStopsRun" => true,
    "anonymousPromptDescriptor" => true,
    "singleLinkInputFiles" => true,
    "singleLinkRuntimeFiles" => true,
    "maxRuntimeOutputFiles" => Zstack::EvalLimits::MAX_RUNTIME_OUTPUT_FILES,
    "maxRuntimeOutputTreeEntries" => Zstack::EvalLimits::MAX_RUNTIME_OUTPUT_TREE_ENTRIES,
    "maxRuntimeOutputBytes" => Zstack::EvalLimits::MAX_RUNTIME_OUTPUT_BYTES,
    "maxRuntimeGitFiles" => Zstack::EvalLimits::MAX_RUNTIME_GIT_FILES,
    "maxRuntimeGitTreeEntries" => Zstack::EvalLimits::MAX_RUNTIME_GIT_TREE_ENTRIES,
    "maxRuntimeGitBytes" => Zstack::EvalLimits::MAX_RUNTIME_GIT_BYTES,
    "maxRuntimeHostHomeFiles" => Zstack::EvalLimits::MAX_RUNTIME_HOST_HOME_FILES,
    "maxRuntimeHostHomeTreeEntries" => Zstack::EvalLimits::MAX_RUNTIME_HOST_HOME_TREE_ENTRIES,
    "maxRuntimeHostHomeBytes" => Zstack::EvalLimits::MAX_RUNTIME_HOST_HOME_BYTES,
    "cases" => selected_cases.map { |entry| entry.fetch("id") },
    "dryRun" => options[:dry_run]
  }
  if HOST_FAMILY == "codex"
    controls.merge!(
      "ignoreUserConfig" => true,
      "ignoreRules" => true,
      "isolatedHostHome" => true,
      "analyticsEnabled" => false,
      "ambientDesktopContextDisabled" => EVAL_CODEX_HOME::AMBIENT_CONTEXT_KEYS,
      "disabledFeatures" => DISABLED_FEATURES
    )
  elsif HOST_FAMILY == "claude"
    controls.merge!(
      "safeMode" => true,
      "customizationsDisabled" => true,
      "hostProviderConfigMayApply" => true,
      "allowedTools" => [],
      "chrome" => false,
      "mcpServers" => false,
      "sessionPersistence" => false,
      "maxBudgetUsdPerCase" => options[:max_budget_usd],
      "resultFormat" => "json"
    )
  else
    controls.merge!(
      "allowedTools" => [],
      "systemPromptOverride" => GROK_SYSTEM_PROMPT,
      "finalResponseBoundary" => GROK_FINAL_MARKER,
      "isolatedHostHome" => true,
      "isolatedHostConfigSha256" => Digest::SHA256.hexdigest(GROK_ISOLATED_CONFIG),
      "foreignCompatibilityDisabled" => %w[claude cursor codex-sessions],
      "ambientAgentSkillsMayBeDiscovered" => true,
      "hostProviderConfigMayApply" => true,
      "mcpToolsAllowed" => false,
      "managedMcpDisabled" => true,
      "officialMarketplaceAutoRegister" => false,
      "memory" => false,
      "planMode" => false,
      "verbatimPrompt" => true,
      "sessionPersistence" => false,
      "maxTurnsPerCase" => options[:max_turns],
      "resultFormat" => "json"
    )
    controls["promptDescriptorPath"] = GROK_PROMPT_PATH
  end
  EVAL_OUTPUT_FILE.write_exclusive(
    File.join(output_directory, "controls.json"),
    JSON.pretty_generate(controls) + "\n",
    max_bytes: Zstack::EvalLimits::MAX_RUN_PROMPT_BYTES,
    label: "routing controls"
  )
  output_reservation.verify!

  if options[:dry_run]
    puts "RUN_DIR=#{output_directory}"
    puts "DRY_RUN=#{selected_cases.length} cases"
    exit 0
  end

  FileUtils.mkdir_p(responses_directory)
  FileUtils.mkdir_p(logs_directory)
  workspace_root = Dir.mktmpdir("zstack-#{HOST_FAMILY}-routing-workspaces-")
  workspace_root_identity = Zstack::EvalOwnedDirectory.capture(
    workspace_root,
    label: "routing workspace root"
  )
  case_tokens = EVAL_PRIVATE_PATHS.build_tokens(selected_cases.map { |entry| entry.fetch("id") })
  results = []
  workspace_specs = []

  selected_cases.each_slice(options[:jobs]) do |slice|
    mutable_output_paths = slice.flat_map do |entry|
      id = entry.fetch("id")
      paths = [
        File.join(responses_directory, "#{id}.txt"),
        File.join(logs_directory, "#{id}.log")
      ]
      if STRUCTURED_HOSTS.include?(HOST_FAMILY)
        paths.concat([
          File.join(logs_directory, "#{id}.json"),
          File.join(logs_directory, "#{id}.invocation.json")
        ])
      end
      paths
    end.uniq
    output_tree_state = Zstack::EvalOutputTree.capture(
      output_directory,
      mutable_paths: mutable_output_paths
    )
    jobs = []
    begin
      slice.each do |entry|
        stdout_io = nil
        stderr_io = nil
        prompt_io = nil
        id = entry.fetch("id")
        private_token = case_tokens.fetch(id)
        workspace = File.join(workspace_root, private_token)
        FileUtils.mkdir_p(workspace)
        Zstack::EvalGitWorkspace.prepare(workspace)

        prompt_path = File.join(prompts_directory, "#{id}.txt")
        prompt_content = generated_prompts.fetch(id)
        retained_prompt = Zstack::EvalInputFile.read(
          prompt_path,
          max_bytes: Zstack::EvalLimits::MAX_PROMPT_BYTES,
          label: "retained routing prompt",
          root: output_directory
        )
        unless retained_prompt == prompt_content
          raise "#{id}: retained routing prompt changed after generation"
        end
        host_prompt_path = HOST_FAMILY == "grok" ? GROK_PROMPT_PATH : prompt_path
        response_path = File.join(responses_directory, "#{id}.txt")
        log_path = File.join(logs_directory, "#{id}.log")
        structured_host = STRUCTURED_HOSTS.include?(HOST_FAMILY)
        raw_result_path = structured_host ? File.join(logs_directory, "#{id}.json") : log_path
        invocation_path = structured_host ? File.join(logs_directory, "#{id}.invocation.json") : nil
        host_output_paths = [raw_result_path, log_path]
        host_output_paths << response_path unless structured_host
        stdout_io = EVAL_OUTPUT_FILE.open_exclusive(raw_result_path, label: "host stdout")
        stderr_io = structured_host ? EVAL_OUTPUT_FILE.open_exclusive(log_path, label: "host stderr") : stdout_io
        prompt_io = Zstack::EvalPromptWriter.anonymous_input(
          prompt_content,
          label: "routing prompt input"
        )
        host_environment = {}
        codex_home = nil
        codex_auth_copied = false
        grok_home = nil
        argv = if HOST_FAMILY == "codex"
                 codex_home, codex_auth_copied = EVAL_CODEX_HOME.prepare(
                   root: workspace_root,
                   case_id: private_token,
                   auth_path: options[:codex_auth_path]
                 )
                 host_environment = EVAL_CODEX_HOME.environment(codex_home)
                 command = [
                   options[:executable], "exec", "--ephemeral", "--ignore-user-config", "--ignore-rules",
                   "-C", workspace, "-s", "read-only", "-m", options[:model],
                   "-c", "model_reasoning_effort=\"#{options[:reasoning]}\"",
                   "-c", "approval_policy=\"never\"",
                   "-c", EVAL_CODEX_HOME::ANALYTICS_OVERRIDE,
                   "--color", "never"
                 ]
                 DISABLED_FEATURES.each { |feature| command.concat(["--disable", feature]) }
                 command.concat(["-o", response_path, "-"])
               elsif HOST_FAMILY == "claude"
                 [
                   options[:executable], "-p", "--safe-mode", "--no-session-persistence",
                   "--permission-mode", "dontAsk", "--tools", "", "--no-chrome",
                   "--strict-mcp-config", "--mcp-config", '{"mcpServers":{}}',
                   "--input-format", "text", "--output-format", "json",
                   "--model", options[:model], "--effort", options[:reasoning],
                   "--max-budget-usd", options[:max_budget_usd].to_s
                 ]
               else
                 grok_home, grok_auth_path, = EVAL_GROK_HOME.prepare(
                   root: workspace_root,
                   case_id: private_token,
                   auth_path: options[:grok_auth_path],
                   config: GROK_ISOLATED_CONFIG
                 )
                 host_environment = EVAL_GROK_HOME.environment(home: grok_home, auth_path: grok_auth_path)
                 [
                   options[:executable], "--prompt-file", host_prompt_path, "--output-format", "json",
                   "--model", options[:model], "--reasoning-effort", options[:reasoning],
                   "--disable-web-search", "--no-subagents", "--no-memory", "--no-plan", "--verbatim",
                   "--tools", "", "--permission-mode", "dontAsk", "--max-turns", options[:max_turns].to_s,
                   "--cwd", workspace, "--sandbox", "read-only", "--system-prompt-override", GROK_SYSTEM_PROMPT
                 ]
               end
        if structured_host
          invocation = {
            "schemaVersion" => 2,
            "host" => HOST_SPEC.fetch(:display_name),
            "executable" => options[:executable],
            "arguments" => argv.drop(1),
            "workspace" => workspace,
            "privateCaseToken" => private_token,
            "promptSha256" => Digest::SHA256.hexdigest(prompt_content),
            "promptBytes" => prompt_content.bytesize
          }
          if HOST_FAMILY == "grok"
            invocation["environment"] = host_environment
            invocation["isolatedConfigSha256"] = Digest::SHA256.hexdigest(GROK_ISOLATED_CONFIG)
            invocation["isolatedConfigBytes"] = GROK_ISOLATED_CONFIG.bytesize
          end
          EVAL_OUTPUT_FILE.write_exclusive(
            invocation_path,
            JSON.pretty_generate(invocation) + "\n",
            label: "private host invocation"
          )
        end
        spawn_options = {
          in: HOST_FAMILY == "grok" ? File::NULL : prompt_io,
          out: stdout_io,
          err: stderr_io,
          pgroup: true,
          rlimit_fsize: EVAL_PROCESS_SUPERVISOR::MAX_HOST_OUTPUT_BYTES + 1
        }
        spawn_options[GROK_PROMPT_DESCRIPTOR] = prompt_io if HOST_FAMILY == "grok"
        spawn_options[:chdir] = workspace if HOST_FAMILY == "claude"
        jobs << {
          stdout_io: stdout_io,
          stderr_io: stderr_io,
          prompt_io: prompt_io,
          host_environment: host_environment,
          argv: argv,
          spawn_options: spawn_options,
          entry: entry,
          response_path: response_path,
          log_path: log_path,
          raw_result_path: raw_result_path,
          invocation_path: invocation_path,
          host_output_paths: host_output_paths,
          codex_home: codex_home,
          codex_auth_copied: codex_auth_copied,
          grok_home: grok_home,
          workspace: workspace
        }
      rescue StandardError
        prompt_io&.close unless prompt_io&.closed?
        stdout_io&.close unless stdout_io&.closed?
        stderr_io&.close unless stderr_io&.equal?(stdout_io) || stderr_io&.closed?
        raise
      end
    rescue StandardError
      jobs.each do |prepared_job|
        prepared_job.fetch(:prompt_io).close unless prepared_job.fetch(:prompt_io).closed?
        prepared_job.fetch(:stdout_io).close unless prepared_job.fetch(:stdout_io).closed?
        job_stderr = prepared_job.fetch(:stderr_io)
        job_stderr.close unless job_stderr.equal?(prepared_job.fetch(:stdout_io)) || job_stderr.closed?
      end
      raise
    end

    jobs.each do |job|
      workspace_specs << {
        workspace: job.fetch(:workspace),
        allowed_top_level: [".git"],
        host_home: job[:codex_home] || job[:grok_home]
      }.freeze
    end
    shared_check = lambda do
      output_reservation.verification_error || output_tree_state.validation_error || Zstack::EvalWorkspaceWatchdog.shared_root_error(
        workspace_root,
        workspace_specs: workspace_specs,
        prompt_states: {}
      )
    end
    batch_monitor = Zstack::EvalResourceMonitor::Batch.new(
      {},
      poll_seconds: EVAL_PROCESS_SUPERVISOR::RESOURCE_POLL_SECONDS,
      shared_check: shared_check
    ) { |pid| EVAL_PROCESS_SUPERVISOR.terminate_without_reap(pid) }.start
    begin
      jobs.each do |job|
        EVAL_EXECUTABLE.verify!(host_executable, display_name: HOST_SPEC.fetch(:display_name))
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        host_environment = job.fetch(:host_environment)
        pid = if host_environment.empty?
                Process.spawn(*job.fetch(:argv), job.fetch(:spawn_options))
              else
                Process.spawn(host_environment, *job.fetch(:argv), job.fetch(:spawn_options))
              end
        job[:pid] = pid
        job[:started_at] = started_at
        running_pids << pid
        batch_monitor.add(pid, lambda do
        Zstack::EvalWorkspaceWatchdog.baseline_error(
          job.fetch(:workspace),
          allowed_top_level: [".git"],
          host_home: job[:codex_home] || job[:grok_home]
        )
        end)
        job.fetch(:prompt_io).close
      end
    rescue StandardError
      batch_monitor.stop
      jobs.each do |job|
        pid = job[:pid]
        EVAL_PROCESS_SUPERVISOR.terminate_and_reap(pid) if pid
        running_pids.delete(pid) if pid
        job.fetch(:prompt_io).close unless job.fetch(:prompt_io).closed?
        job.fetch(:stdout_io).close unless job.fetch(:stdout_io).closed?
        stderr_io = job.fetch(:stderr_io)
        stderr_io.close unless stderr_io.equal?(job.fetch(:stdout_io)) || stderr_io.closed?
      end
      raise
    end
    begin
      jobs.each do |job|
        pid = job.fetch(:pid)
        entry = job.fetch(:entry)
        response_path = job.fetch(:response_path)
        log_path = job.fetch(:log_path)
        process_status, timed_out, output_limited, workspace_limit_error = EVAL_PROCESS_SUPERVISOR.wait(
          pid,
          started_at: job.fetch(:started_at),
          timeout_seconds: options[:timeout_seconds],
          output_paths: job.fetch(:host_output_paths),
          resource_check: -> { batch_monitor.check_now(pid) }
        )
        workspace_limit_error ||= batch_monitor.finish(pid)
        running_pids.delete(pid)
        exit_status = EVAL_PROCESS_SUPERVISOR.exit_status(process_status)
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - job.fetch(:started_at)
        job.fetch(:stdout_io).close
        stderr_io = job.fetch(:stderr_io)
        stderr_io.close unless stderr_io.equal?(job.fetch(:stdout_io))
        EVAL_EXECUTABLE.verify!(host_executable, display_name: HOST_SPEC.fetch(:display_name))

        host_result = {}
        if STRUCTURED_HOSTS.include?(HOST_FAMILY) && !timed_out && !output_limited && workspace_limit_error.nil?
          host_result = if HOST_FAMILY == "claude"
                          EVAL_HOST_CONTRACTS.claude_result(job.fetch(:raw_result_path))
                        else
                          EVAL_HOST_CONTRACTS.grok_result(job.fetch(:raw_result_path))
                        end
          response = host_result.delete("response")
          if host_result.fetch("completed") && response.is_a?(String) && !response.strip.empty?
            EVAL_OUTPUT_FILE.write_exclusive(response_path, response)
          end
        end
        host_result = { "completed" => false, "errorCategory" => "timeout" } if STRUCTURED_HOSTS.include?(HOST_FAMILY) && timed_out
        if STRUCTURED_HOSTS.include?(HOST_FAMILY) && output_limited
          host_result = { "completed" => false, "errorCategory" => "output-limit" }
        end
        if STRUCTURED_HOSTS.include?(HOST_FAMILY) && workspace_limit_error
          host_result = { "completed" => false, "errorCategory" => "workspace-limit" }
        end
        response_content, response_file_error = if output_limited
                                                  [nil, nil]
                                                else
                                                  EVAL_OUTPUT_FILE.read_optional(response_path)
                                                end
        execution_completed = if HOST_FAMILY == "codex"
                                !output_limited && workspace_limit_error.nil? && exit_status.zero? && response_file_error.nil? && !response_content.strip.empty?
                              else
                                !output_limited && workspace_limit_error.nil? && exit_status.zero? && host_result.fetch("completed") && response_file_error.nil?
                              end
        privacy_error = response_content && response_privacy_error(response_content, job.fetch(:workspace))
        execution_completed = false if privacy_error
        selected, format_valid, format_error = if output_limited
                                                 [nil, false, "host output exceeded the per-case byte limit"]
                                               elsif response_file_error
                                                 [nil, false, response_file_error]
                                               else
                                                 parse_response(response_content, candidate_ids)
                                               end
        expected = entry.fetch("expected_skill")
        passed = execution_completed && format_valid && selected == expected
        result = {
          "id" => entry.fetch("id"),
          "expected" => expected,
          "selected" => selected,
          "pass" => passed,
          "executionCompleted" => execution_completed,
          "formatValid" => format_valid,
          "formatError" => format_error,
          "exitStatus" => exit_status,
          "elapsedSeconds" => elapsed.round(3),
          "timedOut" => timed_out,
          "outputLimited" => output_limited,
          "workspaceLimitError" => workspace_limit_error,
          "hostOutputBytes" => EVAL_PROCESS_SUPERVISOR.output_bytes(job.fetch(:host_output_paths)),
          "promptPath" => "prompts/#{entry.fetch("id")}.txt",
          "responsePath" => "responses/#{entry.fetch("id")}.txt",
          "logPath" => "logs/#{File.basename(log_path)}",
          "responsePrivacyError" => privacy_error,
          "responseFileError" => response_file_error
        }
        if STRUCTURED_HOSTS.include?(HOST_FAMILY)
          result["rawResultPath"] = "logs/#{File.basename(job.fetch(:raw_result_path))}"
          result["invocationPath"] = "logs/#{File.basename(job.fetch(:invocation_path))}"
          result.merge!(host_result.reject { |field, _value| field == "completed" })
        end
        result["errorCategory"] = "output-limit" if output_limited
        result["errorCategory"] = "workspace-limit" if workspace_limit_error
        results << result
      end
    ensure
      batch_monitor.stop
    end
    break if results.any? { |result| result["workspaceLimitError"] }
  end

  order = selected_cases.map { |entry| entry.fetch("id") }
  results.sort_by! { |result| order.index(result.fetch("id")) }
  output_reservation.verify!
  EVAL_OUTPUT_FILE.write_exclusive(
    File.join(output_directory, "results.json"),
    JSON.pretty_generate(results) + "\n",
    max_bytes: Zstack::EvalLimits::MAX_RUN_PROMPT_BYTES,
    label: "routing results"
  )
  output_reservation.verify!
  puts "RUN_DIR=#{output_directory}"
  results.each do |result|
    status = if result.fetch("pass")
               "PASS"
             elsif result["outputLimited"]
               "FAIL (output limit #{EVAL_PROCESS_SUPERVISOR::MAX_HOST_OUTPUT_BYTES} bytes)"
             elsif result["timedOut"]
               "FAIL (timeout #{options[:timeout_seconds]}s)"
             elsif result["workspaceLimitError"]
               "FAIL (#{result["workspaceLimitError"]})"
             elsif result["errorCategory"] || result["apiErrorStatus"]
               details = [result["errorCategory"], ("HTTP #{result["apiErrorStatus"]}" if result["apiErrorStatus"])].compact
               "FAIL (#{details.join("; ")})"
             else
               "FAIL"
             end
    puts format(
      "%-34s expected=%-21s selected=%-21s %s",
      result.fetch("id"),
      result.fetch("expected"),
      result["selected"] || "UNPARSED",
      status
    )
  end
  puts "PASS=#{results.count { |result| result.fetch("pass") }}/#{selected_cases.length}"
  exit 1 unless results.length == selected_cases.length && results.all? { |result| result.fetch("pass") }
rescue Interrupt
  warn "ERROR: interrupted"
  exit 130
rescue StandardError => e
  warn "ERROR: #{e.message}"
  exit 2
ensure
  running_pids.each { |pid| EVAL_PROCESS_SUPERVISOR.terminate_and_reap(pid) }
  Zstack::EvalOwnedDirectory.remove_if_same(workspace_root, workspace_root_identity)
  output_reservation&.close
end
