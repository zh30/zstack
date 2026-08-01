#!/usr/bin/env ruby
# Shared post-selection behavioral runner for isolated host-specific adapters.

require "digest"
require "fileutils"
require "find"
require "json"
require "open3"
require "optparse"
require "pathname"
require "tmpdir"
require "yaml"
require_relative "lib/eval_codex_home"
require_relative "lib/eval_behavioral_prompt"
require_relative "lib/evidence_handoff_contract"
require_relative "lib/eval_host_contracts"
require_relative "lib/eval_private_paths"
require_relative "lib/eval_process_supervisor"

ROOT = File.expand_path("..", __dir__)
CATALOG_PATH = File.join(ROOT, "catalog.yaml")
CASES_PATH = File.join(ROOT, "evals", "cases.yaml")
HOST_FAMILY = ENV.fetch("ZSTACK_BEHAVIORAL_HOST", "")
HOST_SPECS = {
  "codex" => {
    display_name: "Codex CLI",
    executable: "codex",
    model: "gpt-5.6-sol",
    jobs: 2,
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
raise "set ZSTACK_BEHAVIORAL_HOST to codex, claude, or grok" unless HOST_SPEC
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
SNAPSHOT_MANIFEST_HEADER = "sha256                                                            bytes  path"
EXECUTION_MODES = %w[response artifact].freeze
STRUCTURED_HOSTS = %w[claude grok].freeze
EVAL_HOST_CONTRACTS = Zstack::EvalHostContracts
EVAL_CODEX_HOME = Zstack::EvalCodexHome
EVAL_BEHAVIORAL_PROMPT = Zstack::EvalBehavioralPrompt
EVAL_PRIVATE_PATHS = Zstack::EvalPrivatePaths
EVIDENCE_HANDOFF_CONTRACT = Zstack::EvidenceHandoffContract
EVAL_PROCESS_SUPERVISOR = Zstack::EvalProcessSupervisor
GROK_SYSTEM_PROMPT = EVAL_HOST_CONTRACTS.grok_system_prompt("behavioral")
GROK_FINAL_MARKER = EVAL_HOST_CONTRACTS::GROK_FINAL_MARKER
GROK_ISOLATED_CONFIG = EVAL_HOST_CONTRACTS::GROK_ISOLATED_CONFIG

def fail_usage(message, parser = nil)
  warn "ERROR: #{message}"
  warn parser if parser
  exit 2
end

def load_yaml(path)
  YAML.safe_load(
    File.read(path),
    permitted_classes: [],
    permitted_symbols: [],
    aliases: false,
    filename: path
  )
rescue Errno::ENOENT, Psych::Exception => e
  raise "cannot load #{path.delete_prefix("#{ROOT}/")}: #{e.message}"
end

def active_skill_paths
  entries = Array(load_yaml(CATALOG_PATH).fetch("skills")).select { |entry| entry["status"] == "active" }
  raise "catalog.yaml has no active skills" if entries.empty?

  entries.each_with_object({}) do |entry, paths|
    id = entry.fetch("id")
    path = File.expand_path(entry.fetch("path"), ROOT)
    raise "#{id}: skill path must stay inside skills/" unless path.start_with?(File.join(ROOT, "skills") + "/")
    raise "#{id}: skill directory is missing" unless File.directory?(path)
    raise "#{id}: skill directory must not be a symbolic link" if File.symlink?(path)

    paths[id] = path
  end
end

def load_behavioral_cases
  document = load_yaml(CASES_PATH)
  contract_must = Array(document.fetch("contract_must"))
  raise "evals/cases.yaml has no contract_must criteria" if contract_must.empty?
  unless contract_must.include?(EVIDENCE_HANDOFF_CONTRACT::CRITERION)
    raise "evals/cases.yaml is missing the mechanical Evidence handoff criterion"
  end
  cases = Array(document.fetch("cases")).map do |entry|
    entry.merge("must" => contract_must + Array(entry["must"]))
  end
  raise "evals/cases.yaml has no cases" if cases.empty?

  cases.each do |entry|
    %w[id skill kind prompt].each do |field|
      value = entry[field]
      raise "behavioral case is missing #{field}" unless value.is_a?(String) && !value.empty?
    end
    mode = entry.fetch("execution", "response")
    raise "#{entry.fetch("id")}: execution must be response or artifact" unless EXECUTION_MODES.include?(mode)
  end
  cases
end

def execution_mode(entry)
  entry.fetch("execution", "response")
end

def select_cases(cases, ids, prefix)
  known_ids = cases.map { |entry| entry.fetch("id") }
  missing_ids = ids - known_ids
  raise "unknown behavioral case(s): #{missing_ids.join(", ")}" unless missing_ids.empty?

  selected = if ids.empty? && prefix.nil?
               cases
             else
               cases.select do |entry|
                 ids.include?(entry.fetch("id")) || (prefix && entry.fetch("id").start_with?(prefix))
               end
             end
  raise "no behavioral cases matched the selectors" if selected.empty?

  selected
end

def prepare_output_directory(requested_path)
  return Dir.mktmpdir("zstack-#{HOST_FAMILY}-behavioral-") unless requested_path

  path = File.expand_path(requested_path)
  if File.symlink?(path)
    raise "output directory must not be a symbolic link: #{path}"
  elsif File.exist?(path)
    raise "output path is not a directory: #{path}" unless File.directory?(path)
    raise "output directory must be empty: #{path}" unless Dir.empty?(path)
  else
    FileUtils.mkdir_p(path)
  end
  path
end

def copy_skill_snapshot(source, destination)
  source_root = File.realpath(source)
  Find.find(source) do |path|
    relative = Pathname.new(path).relative_path_from(Pathname.new(source)).to_s
    next if relative == "."

    raise "skill snapshots cannot contain symbolic links: #{path.delete_prefix("#{ROOT}/")}" if File.symlink?(path)
    resolved = File.realpath(path)
    unless resolved == source_root || resolved.start_with?("#{source_root}/")
      raise "skill snapshot path resolves outside its source: #{path.delete_prefix("#{ROOT}/")}"
    end

    target = File.join(destination, relative)
    if File.directory?(path)
      FileUtils.mkdir_p(target)
    elsif File.file?(path)
      FileUtils.mkdir_p(File.dirname(target))
      FileUtils.copy_file(path, target, true)
    else
      raise "skill snapshots support only regular files and directories: #{path.delete_prefix("#{ROOT}/")}"
    end
  end
end

def write_snapshot_manifest(output_directory)
  snapshot_root = File.join(output_directory, "skill-snapshots")
  paths = Dir.glob(File.join(snapshot_root, "**", "*"), File::FNM_DOTMATCH).select do |path|
    next false if %w[. ..].include?(File.basename(path))
    File.file?(path)
  end.sort
  raise "skill snapshot contains no files" if paths.empty?

  lines = [SNAPSHOT_MANIFEST_HEADER]
  paths.each do |path|
    relative = Pathname.new(path).relative_path_from(Pathname.new(output_directory)).to_s
    content = File.binread(path)
    lines << format("%s  %7d  %s", Digest::SHA256.hexdigest(content), content.bytesize, relative)
  end
  File.write(File.join(output_directory, "skill-snapshot-manifest.txt"), lines.join("\n") + "\n")
end

def build_prompt(entry)
  EVAL_BEHAVIORAL_PROMPT.build(entry)
end

def regular_tree_files(root)
  return [] unless File.directory?(root)
  raise "workspace output root must not be a symbolic link: #{root}" if File.symlink?(root)

  files = []
  Find.find(root) do |path|
    next if path == root
    raise "workspace output contains a symbolic link: #{path}" if File.symlink?(path)
    if File.file?(path)
      files << path
    elsif !File.directory?(path)
      raise "workspace output contains a non-regular entry: #{path}"
    end
  end
  files.sort
end

def trees_match?(left, right)
  left_files = regular_tree_files(left)
  right_files = regular_tree_files(right)
  left_relative = left_files.map { |path| Pathname.new(path).relative_path_from(Pathname.new(left)).to_s }
  right_relative = right_files.map { |path| Pathname.new(path).relative_path_from(Pathname.new(right)).to_s }
  return false unless left_relative == right_relative

  left_relative.all? do |relative|
    File.binread(File.join(left, relative)) == File.binread(File.join(right, relative))
  end
end

def capture_artifacts(workspace, copied_skill, snapshot, destination)
  unexpected = Dir.children(workspace).reject { |name| %w[.git .zstack-skill artifacts].include?(name) }
  raise "artifact case wrote outside artifacts/: #{unexpected.sort.join(", ")}" unless unexpected.empty?
  raise "artifact case changed its copied skill snapshot" unless trees_match?(copied_skill, snapshot)

  artifact_root = File.join(workspace, "artifacts")
  files = regular_tree_files(artifact_root)
  raise "artifact case produced no files under artifacts/" if files.empty?
  FileUtils.mkdir_p(destination)
  files.map do |path|
    relative = Pathname.new(path).relative_path_from(Pathname.new(artifact_root)).to_s
    target = File.join(destination, relative)
    FileUtils.mkdir_p(File.dirname(target))
    FileUtils.copy_file(path, target, true)
    relative
  end
end

def write_artifact_manifest(output_directory, results)
  paths = results.flat_map { |result| Array(result["artifactPaths"]) }.sort
  return if paths.empty?

  lines = [SNAPSHOT_MANIFEST_HEADER]
  paths.each do |relative|
    path = File.join(output_directory, relative)
    content = File.binread(path)
    lines << format("%s  %7d  %s", Digest::SHA256.hexdigest(content), content.bytesize, relative)
  end
  File.write(File.join(output_directory, "artifact-manifest.txt"), lines.join("\n") + "\n")
end

def host_version(executable_path)
  output, error, status = Open3.capture3(executable_path, "--version", stdin_data: "")
  raise "cannot execute #{executable_path}: #{error.strip}" unless status.success?

  version = output.strip.lines.first
  raise "#{executable_path} --version returned no version" if version.nil? || version.empty?

  version
rescue Errno::ENOENT
  raise "#{HOST_SPEC.fetch(:display_name)} executable not found: #{executable_path}"
end

def usable_response?(path)
  File.file?(path) && !File.read(path).strip.empty?
end

def response_privacy_error(path, workspace)
  return nil unless File.file?(path)

  content = File.read(path)
  private_token = File.basename(workspace)
  if content.include?(workspace) || content.include?(private_token) ||
     content.match?(/zstack-(?:codex|claude|grok)-behavioral-workspaces-/)
    "final response contains a private workspace path"
  end
end

options = {
  case_ids: [],
  case_prefix: nil,
  execution_filter: nil,
  codex_auth_path: File.expand_path("~/.codex/auth.json"),
  executable: HOST_SPEC.fetch(:executable),
  dry_run: false,
  grok_auth_path: File.expand_path("~/.grok/auth.json"),
  jobs: HOST_SPEC.fetch(:jobs),
  max_budget_usd: 1.0,
  max_turns: 8,
  model: HOST_SPEC.fetch(:model),
  output: nil,
  reasoning: "medium",
  timeout_seconds: nil
}

parser = OptionParser.new do |opts|
  opts.banner = "Usage: ruby scripts/run-#{HOST_FAMILY}-behavioral-evals.rb [options]"
  opts.on("--case ID", "Run one case; repeat to select more") { |value| options[:case_ids] << value }
  opts.on("--case-prefix PREFIX", "Run case ids beginning with PREFIX") { |value| options[:case_prefix] = value }
  opts.on("--execution MODE", EXECUTION_MODES, "Select response or artifact cases") { |value| options[:execution_filter] = value }
  opts.on("--output DIR", "Write the run to DIR (must be new or empty)") { |value| options[:output] = value }
  opts.on("--jobs N", Integer, "Concurrent #{HOST_SPEC.fetch(:display_name)} processes (default: #{HOST_SPEC.fetch(:jobs)})") { |value| options[:jobs] = value }
  opts.on("--model MODEL", "#{HOST_SPEC.fetch(:display_name)} model (default: #{HOST_SPEC.fetch(:model)})") { |value| options[:model] = value }
  opts.on("--reasoning LEVEL", "#{HOST_SPEC.fetch(:reasoning_levels).join(", ")}") { |value| options[:reasoning] = value }
  opts.on("--timeout-seconds N", Integer, "Per-case wall-clock timeout (default: response 600, artifact 1200)") { |value| options[:timeout_seconds] = value }
  if HOST_FAMILY == "codex"
    opts.on("--codex PATH", "Codex executable (default: codex)") { |value| options[:executable] = value }
    opts.on("--auth-path PATH", "Optional Codex auth file copied into the isolated host home (default: ~/.codex/auth.json)") { |value| options[:codex_auth_path] = File.expand_path(value) }
  elsif HOST_FAMILY == "claude"
    opts.on("--claude PATH", "Claude executable (default: claude)") { |value| options[:executable] = value }
    opts.on("--max-budget-usd AMOUNT", Float, "Per-case Claude API budget (default: 1.0)") { |value| options[:max_budget_usd] = value }
  else
    opts.on("--grok PATH", "Grok executable (default: grok)") { |value| options[:executable] = value }
    opts.on("--auth-path PATH", "Grok auth file used with an isolated GROK_HOME (default: ~/.grok/auth.json)") { |value| options[:grok_auth_path] = File.expand_path(value) }
    opts.on("--max-turns N", Integer, "Maximum Grok agent turns per case (default: 8)") { |value| options[:max_turns] = value }
  end
  opts.on("--dry-run", "Write snapshots and prompts without invoking #{HOST_SPEC.fetch(:display_name)}") { options[:dry_run] = true }
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
fail_usage("--jobs must be at least 1") unless options[:jobs].positive?
if options[:timeout_seconds] && !options[:timeout_seconds].positive?
  fail_usage("--timeout-seconds must be at least 1")
end
unless HOST_SPEC.fetch(:reasoning_levels).include?(options[:reasoning])
  fail_usage("unknown reasoning level for #{HOST_SPEC.fetch(:display_name)}: #{options[:reasoning]}")
end
if HOST_FAMILY == "claude" && !options[:max_budget_usd].positive?
  fail_usage("--max-budget-usd must be greater than zero")
end
if HOST_FAMILY == "grok" && !options[:max_turns].positive?
  fail_usage("--max-turns must be greater than zero")
end

workspace_root = nil
running_pids = []
Signal.trap("TERM") { raise Interrupt }
begin
  skills = active_skill_paths
  all_cases = load_behavioral_cases
  selected_cases = select_cases(all_cases, options[:case_ids].uniq, options[:case_prefix])
  if options[:execution_filter]
    selected_cases = selected_cases.select { |entry| execution_mode(entry) == options[:execution_filter] }
    raise "no behavioral cases matched --execution #{options[:execution_filter]}" if selected_cases.empty?
  end
  selected_execution_modes = selected_cases.map { |entry| execution_mode(entry) }.uniq
  if selected_execution_modes.length != 1
    raise "select response and artifact cases in separate runner invocations"
  end
  run_execution_mode = selected_execution_modes.fetch(0)
  options[:timeout_seconds] ||= run_execution_mode == "artifact" ? 1200 : 600
  unknown_skills = selected_cases.map { |entry| entry.fetch("skill") }.uniq - skills.keys
  raise "selected cases reference unknown active skills: #{unknown_skills.join(", ")}" unless unknown_skills.empty?

  output_directory = prepare_output_directory(options[:output])
  prompts_directory = File.join(output_directory, "prompts")
  snapshots_directory = File.join(output_directory, "skill-snapshots")
  FileUtils.mkdir_p(prompts_directory)
  FileUtils.mkdir_p(snapshots_directory)

  selected_cases.map { |entry| entry.fetch("skill") }.uniq.sort.each do |skill|
    copy_skill_snapshot(skills.fetch(skill), File.join(snapshots_directory, skill))
  end
  write_snapshot_manifest(output_directory)
  selected_cases.each do |entry|
    File.write(File.join(prompts_directory, "#{entry.fetch("id")}.txt"), build_prompt(entry))
  end

  version = options[:dry_run] ? nil : host_version(options[:executable])
  controls = {
    "schemaVersion" => 1,
    "host" => HOST_SPEC.fetch(:display_name),
    "hostVersion" => version,
    "model" => options[:model],
    "reasoningEffort" => options[:reasoning],
    "sandbox" => if run_execution_mode == "artifact"
                   HOST_FAMILY == "grok" ? "workspace" : "workspace-write"
                 elsif HOST_FAMILY == "claude"
                   "Read tool only"
                 else
                   "read-only"
                 end,
    "approvalPolicy" => if HOST_FAMILY == "codex"
                          "never"
                        elsif HOST_FAMILY == "grok" && run_execution_mode == "artifact"
                          "bypassPermissions"
                        else
                          "dontAsk"
                        end,
    "ephemeralSession" => true,
    "promptTransport" => HOST_FAMILY == "grok" ? "generated prompt through file" : "generated prompt through stdin",
    "privateCaseIdentifiers" => EVAL_PRIVATE_PATHS::STRATEGY,
    "skillSource" => "exact copied source snapshots",
    "executionMode" => run_execution_mode,
    "artifactCapture" => run_execution_mode == "artifact",
    "webSearch" => false,
    "subagents" => false,
    "jobs" => options[:jobs],
    "timeoutSecondsPerCase" => options[:timeout_seconds],
    "cases" => selected_cases.map { |entry| entry.fetch("id") },
    "dryRun" => options[:dry_run],
    "grading" => "not performed by runner"
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
    claude_tools = run_execution_mode == "artifact" ? %w[Read Write Edit] : ["Read"]
    controls.merge!(
      "safeMode" => true,
      "customizationsDisabled" => true,
      "hostProviderConfigMayApply" => true,
      "allowedTools" => claude_tools,
      "chrome" => false,
      "mcpServers" => false,
      "sessionPersistence" => false,
      "maxBudgetUsdPerCase" => options[:max_budget_usd],
      "resultFormat" => "json"
    )
  else
    grok_tools = run_execution_mode == "artifact" ? %w[Read Write Edit] : ["Read"]
    controls.merge!(
      "allowedTools" => grok_tools,
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
  end
  if run_execution_mode == "artifact"
    controls["writeBoundary"] = "artifacts/ only; audited after execution"
  end
  File.write(File.join(output_directory, "controls.json"), JSON.pretty_generate(controls) + "\n")

  if options[:dry_run]
    puts "RUN_DIR=#{output_directory}"
    puts "DRY_RUN=#{selected_cases.length} cases"
    exit 0
  end

  responses_directory = File.join(output_directory, "responses")
  logs_directory = File.join(output_directory, "logs")
  artifacts_directory = File.join(output_directory, "artifacts")
  FileUtils.mkdir_p(responses_directory)
  FileUtils.mkdir_p(logs_directory)
  FileUtils.mkdir_p(artifacts_directory) if run_execution_mode == "artifact"
  workspace_root = Dir.mktmpdir("zstack-#{HOST_FAMILY}-behavioral-workspaces-")
  case_tokens = EVAL_PRIVATE_PATHS.build_tokens(selected_cases.map { |entry| entry.fetch("id") })
  private_prompts_directory = File.join(workspace_root, ".prompt-files")
  FileUtils.mkdir_p(private_prompts_directory) if HOST_FAMILY == "grok"
  results = []

  selected_cases.each_slice(options[:jobs]) do |slice|
    jobs = []
    begin
      slice.each do |entry|
        id = entry.fetch("id")
        skill = entry.fetch("skill")
        private_token = case_tokens.fetch(id)
        workspace = File.join(workspace_root, private_token)
        FileUtils.mkdir_p(workspace)
        unless system("git", "init", "-q", workspace, out: File::NULL, err: File::NULL)
          raise "git init failed for #{id}"
        end
        copied_skill = File.join(workspace, ".zstack-skill", skill)
        FileUtils.mkdir_p(File.dirname(copied_skill))
        FileUtils.cp_r(File.join(snapshots_directory, skill), copied_skill)
        FileUtils.mkdir_p(File.join(workspace, "artifacts")) if run_execution_mode == "artifact"

        prompt_path = File.join(prompts_directory, "#{id}.txt")
        host_prompt_path = prompt_path
        if HOST_FAMILY == "grok"
          host_prompt_path = File.join(private_prompts_directory, "#{private_token}.txt")
          FileUtils.copy_file(prompt_path, host_prompt_path)
        end
        response_path = File.join(responses_directory, "#{id}.txt")
        log_path = File.join(logs_directory, "#{id}.log")
        structured_host = STRUCTURED_HOSTS.include?(HOST_FAMILY)
        raw_result_path = structured_host ? File.join(logs_directory, "#{id}.json") : log_path
        stderr_path = structured_host ? log_path : nil
        invocation_path = structured_host ? File.join(logs_directory, "#{id}.invocation.json") : nil
        stdout_io = File.open(raw_result_path, "wb")
        stderr_io = structured_host ? File.open(stderr_path, "wb") : stdout_io
        prompt_io = HOST_FAMILY == "grok" ? nil : File.open(prompt_path, "rb")
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
                   "-C", workspace, "-s", run_execution_mode == "artifact" ? "workspace-write" : "read-only", "-m", options[:model],
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
                   "--permission-mode", "dontAsk", "--tools", controls.fetch("allowedTools").join(","), "--no-chrome",
                   "--strict-mcp-config", "--mcp-config", '{"mcpServers":{}}',
                   "--input-format", "text", "--output-format", "json",
                   "--model", options[:model], "--effort", options[:reasoning],
                   "--max-budget-usd", options[:max_budget_usd].to_s
                 ]
               else
                 grok_home = File.join(workspace_root, ".grok-homes", private_token)
                 FileUtils.mkdir_p(grok_home)
                 File.write(File.join(grok_home, "config.toml"), GROK_ISOLATED_CONFIG)
                 host_environment = {
                   "GROK_HOME" => grok_home,
                   "GROK_AUTH_PATH" => options[:grok_auth_path],
                   "GROK_MANAGED_MCPS_ENABLED" => "0",
                   "GROK_OFFICIAL_MARKETPLACE_AUTO_REGISTER" => "0"
                 }
                 [
                   options[:executable], "--prompt-file", host_prompt_path, "--output-format", "json",
                   "--model", options[:model], "--reasoning-effort", options[:reasoning],
                   "--disable-web-search", "--no-subagents", "--no-memory", "--no-plan", "--verbatim",
                   "--tools", controls.fetch("allowedTools").join(","), "--permission-mode", controls.fetch("approvalPolicy"),
                   "--max-turns", options[:max_turns].to_s, "--cwd", workspace,
                   "--sandbox", controls.fetch("sandbox"), "--system-prompt-override", GROK_SYSTEM_PROMPT
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
            "promptSha256" => Digest::SHA256.file(prompt_path).hexdigest,
            "promptBytes" => File.size(prompt_path)
          }
          if HOST_FAMILY == "grok"
            invocation["environment"] = host_environment
            invocation["isolatedConfigSha256"] = Digest::SHA256.hexdigest(GROK_ISOLATED_CONFIG)
            invocation["isolatedConfigBytes"] = GROK_ISOLATED_CONFIG.bytesize
          end
          File.write(invocation_path, JSON.pretty_generate(invocation) + "\n")
        end
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        spawn_options = { in: prompt_io || File::NULL, out: stdout_io, err: stderr_io, pgroup: true }
        spawn_options[:chdir] = workspace if HOST_FAMILY == "claude"
        pid = host_environment.empty? ? Process.spawn(*argv, **spawn_options) : Process.spawn(host_environment, *argv, **spawn_options)
        prompt_io&.close
        running_pids << pid
        jobs << {
          pid: pid,
          stdout_io: stdout_io,
          stderr_io: stderr_io,
          entry: entry,
          response_path: response_path,
          log_path: log_path,
          raw_result_path: raw_result_path,
          invocation_path: invocation_path,
          codex_home: codex_home,
          codex_auth_copied: codex_auth_copied,
          grok_home: grok_home,
          workspace: workspace,
          copied_skill: copied_skill,
          snapshot: File.join(snapshots_directory, skill),
          started_at: started_at
        }
      rescue StandardError
        prompt_io&.close unless prompt_io&.closed?
        stdout_io&.close unless stdout_io&.closed?
        stderr_io&.close unless stderr_io&.equal?(stdout_io) || stderr_io&.closed?
        raise
      end
    rescue StandardError
      jobs.each do |running_job|
        EVAL_PROCESS_SUPERVISOR.terminate_and_reap(running_job.fetch(:pid))
        running_job.fetch(:stdout_io).close unless running_job.fetch(:stdout_io).closed?
        stderr_io = running_job.fetch(:stderr_io)
        stderr_io.close unless stderr_io.equal?(running_job.fetch(:stdout_io)) || stderr_io.closed?
      end
      raise
    end

    jobs.each do |job|
      pid = job.fetch(:pid)
      entry = job.fetch(:entry)
      response_path = job.fetch(:response_path)
      log_path = job.fetch(:log_path)
      process_status, timed_out = EVAL_PROCESS_SUPERVISOR.wait(
        pid,
        started_at: job.fetch(:started_at),
        timeout_seconds: options[:timeout_seconds]
      )
      running_pids.delete(pid)
      exit_status = EVAL_PROCESS_SUPERVISOR.exit_status(process_status)
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - job.fetch(:started_at)
      job.fetch(:stdout_io).close
      stderr_io = job.fetch(:stderr_io)
      stderr_io.close unless stderr_io.equal?(job.fetch(:stdout_io))

      host_result = {}
      if STRUCTURED_HOSTS.include?(HOST_FAMILY) && !timed_out
        host_result = if HOST_FAMILY == "claude"
                        EVAL_HOST_CONTRACTS.claude_result(job.fetch(:raw_result_path))
                      else
                        EVAL_HOST_CONTRACTS.grok_result(job.fetch(:raw_result_path))
                      end
        response = host_result.delete("response")
        if host_result.fetch("completed") && response.is_a?(String) && !response.strip.empty?
          File.write(response_path, response)
        end
      end
      host_result = { "completed" => false, "errorCategory" => "timeout" } if STRUCTURED_HOSTS.include?(HOST_FAMILY) && timed_out
      completed = if HOST_FAMILY == "codex"
                    exit_status == 0 && usable_response?(response_path)
                  else
                    exit_status == 0 && host_result.fetch("completed") && usable_response?(response_path)
                  end
      privacy_error = response_privacy_error(response_path, job.fetch(:workspace))
      completed = false if privacy_error
      artifact_paths = []
      artifact_error = nil
      if run_execution_mode == "artifact" && completed
        begin
          captured = capture_artifacts(
            job.fetch(:workspace),
            job.fetch(:copied_skill),
            job.fetch(:snapshot),
            File.join(artifacts_directory, entry.fetch("id"))
          )
          artifact_paths = captured.map { |relative| "artifacts/#{entry.fetch("id")}/#{relative}" }
        rescue StandardError => e
          artifact_error = e.message
          completed = false
        end
      end
      contract_sources = [{ name: "responses/#{entry.fetch("id")}.txt", path: response_path }]
      artifact_paths.each do |relative|
        next unless EVIDENCE_HANDOFF_CONTRACT.markdown_source?(relative)

        contract_sources << { name: relative, path: File.join(output_directory, relative) }
      end
      evidence_handoff_contract = EVIDENCE_HANDOFF_CONTRACT.evaluate(contract_sources)
      result = {
        "id" => entry.fetch("id"),
        "skill" => entry.fetch("skill"),
        "completed" => completed,
        "exitStatus" => exit_status,
        "elapsedSeconds" => elapsed.round(3),
        "timedOut" => timed_out,
        "promptPath" => "prompts/#{entry.fetch("id")}.txt",
        "responsePath" => "responses/#{entry.fetch("id")}.txt",
        "logPath" => "logs/#{File.basename(log_path)}",
        "executionMode" => run_execution_mode,
        "artifactPaths" => artifact_paths,
        "artifactError" => artifact_error,
        "responsePrivacyError" => privacy_error,
        "evidenceHandoffContract" => evidence_handoff_contract,
        "grade" => nil
      }
      if STRUCTURED_HOSTS.include?(HOST_FAMILY)
        result["rawResultPath"] = "logs/#{File.basename(job.fetch(:raw_result_path))}"
        result["invocationPath"] = "logs/#{File.basename(job.fetch(:invocation_path))}"
        result.merge!(host_result.reject { |field, _value| field == "completed" })
      end
      results << result
    end
  end

  order = selected_cases.map { |entry| entry.fetch("id") }
  results.sort_by! { |result| order.index(result.fetch("id")) }
  write_artifact_manifest(output_directory, results)
  File.write(File.join(output_directory, "results.json"), JSON.pretty_generate(results) + "\n")
  review = {
    "schemaVersion" => 1,
    "reviewer" => nil,
    "cases" => selected_cases.map do |entry|
      criteria = entry.fetch("must").map do |criterion|
        if criterion == EVIDENCE_HANDOFF_CONTRACT::CRITERION
          contract = results.find { |result| result.fetch("id") == entry.fetch("id") }.fetch("evidenceHandoffContract")
          {
            "expectation" => "present",
            "criterion" => criterion,
            "observed" => contract.fetch("passed"),
            "evidence" => EVIDENCE_HANDOFF_CONTRACT.review_evidence(contract)
          }
        else
          { "expectation" => "present", "criterion" => criterion, "observed" => nil, "evidence" => nil }
        end
      end
      criteria.concat(entry.fetch("must_not").map do |criterion|
        { "expectation" => "absent", "criterion" => criterion, "observed" => nil, "evidence" => nil }
      end)
      {
        "id" => entry.fetch("id"),
        "skill" => entry.fetch("skill"),
        "grade" => nil,
        "criteria" => criteria
      }
    end
  }
  File.write(File.join(output_directory, "review.json"), JSON.pretty_generate(review) + "\n")
  puts "RUN_DIR=#{output_directory}"
  results.each do |result|
    execution_status = if result.fetch("completed")
                         "COMPLETED (ungraded)"
                       else
                         details = []
                         details << "timeout #{options[:timeout_seconds]}s" if result["timedOut"]
                         details << result["errorCategory"] if result["errorCategory"] && result["errorCategory"] != "timeout"
                         details << "HTTP #{result["apiErrorStatus"]}" if result["apiErrorStatus"]
                         details.empty? ? "EXECUTION-FAILED" : "EXECUTION-FAILED (#{details.join("; ")})"
                       end
    puts format(
      "%-34s skill=%-24s %s",
      result.fetch("id"),
      result.fetch("skill"),
      execution_status
    )
  end
  puts "COMPLETED=#{results.count { |result| result.fetch("completed") }}/#{results.length}; GRADED=0"
  exit 1 unless results.all? { |result| result.fetch("completed") }
rescue Interrupt
  warn "ERROR: interrupted"
  exit 130
rescue StandardError => e
  warn "ERROR: #{e.message}"
  exit 2
ensure
  running_pids.each { |pid| EVAL_PROCESS_SUPERVISOR.terminate_and_reap(pid) }
  FileUtils.remove_entry(workspace_root) if workspace_root && File.exist?(workspace_root)
end
