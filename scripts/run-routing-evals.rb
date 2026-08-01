#!/usr/bin/env ruby
# Shared description-only routing runner for isolated host-specific adapters.

require "digest"
require "fileutils"
require "json"
require "open3"
require "optparse"
require "tmpdir"
require "yaml"
require_relative "lib/eval_codex_home"
require_relative "lib/eval_host_contracts"
require_relative "lib/eval_private_paths"
require_relative "lib/eval_process_supervisor"

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
EVAL_PRIVATE_PATHS = Zstack::EvalPrivatePaths
EVAL_PROCESS_SUPERVISOR = Zstack::EvalProcessSupervisor
GROK_SYSTEM_PROMPT = EVAL_HOST_CONTRACTS.grok_system_prompt("routing")
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

def load_frontmatter(path)
  content = File.read(path)
  match = content.match(/\A---\r?\n(?<yaml>.*?)\r?\n---(?:\r?\n|\z)/m)
  raise "#{path.delete_prefix("#{ROOT}/")}: missing closed frontmatter" unless match

  data = YAML.safe_load(
    match[:yaml],
    permitted_classes: [],
    permitted_symbols: [],
    aliases: false,
    filename: path
  )
  raise "#{path.delete_prefix("#{ROOT}/")}: frontmatter must be a mapping" unless data.is_a?(Hash)

  data
rescue Errno::ENOENT, Psych::Exception => e
  raise "cannot load #{path.delete_prefix("#{ROOT}/")}: #{e.message}"
end

def active_candidates(description_limit)
  catalog = load_yaml(CATALOG_PATH)
  entries = Array(catalog.fetch("skills")).select { |entry| entry["status"] == "active" }
  raise "catalog.yaml has no active skills" if entries.empty?

  entries.map do |entry|
    id = entry.fetch("id")
    path = File.expand_path(entry.fetch("path"), ROOT)
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
  cases = Array(document.fetch("cases"))
  raise "evals/routing.yaml has no cases" if cases.empty?

  cases.each do |entry|
    %w[id prompt expected_skill].each do |field|
      value = entry[field]
      raise "routing case is missing #{field}" unless value.is_a?(String) && !value.empty?
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
  return Dir.mktmpdir("zstack-#{HOST_FAMILY}-routing-") unless requested_path

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

def wrapper_style(option, user_prompt)
  return option unless option == "auto"

  user_prompt.match?(/\p{Han}/) ? "zh" : "en"
end

def build_prompt(candidates, user_prompt, style, description_limit)
  candidate_text = candidates.map { |id, description| "- #{id}: #{description}" }.join("\n")
  if style == "zh"
    stress = if description_limit
               "这些描述已机械截断为前 #{description_limit} 个 Unicode 字符，用于上下文预算压力测试。\n"
             else
               ""
             end
    <<~PROMPT
      只根据下面候选 skill 的 frontmatter 描述，为一个用户请求选择路由。#{stress}不要使用工具、读取文件或加载已安装的 skill 正文。

      候选 skills：
      #{candidate_text}

      用户请求：
      #{user_prompt}

      严格只回复两行：
      selection: <一个候选 id 或 none>
      reason: <一句简短中文理由>
    PROMPT
  else
    stress = if description_limit
               "These descriptions have been mechanically tail-truncated to #{description_limit} Unicode characters for a context-budget stress test.\n"
             else
               ""
             end
    <<~PROMPT
      Route one user request using only the candidate frontmatter descriptions below. #{stress}Do not use tools, inspect files, or load installed skill bodies.

      Candidate skills:
      #{candidate_text}

      User request:
      #{user_prompt}

      Reply with exactly two lines:
      selection: <one candidate id or none>
      reason: <one concise sentence>
    PROMPT
  end
end

def host_version(executable)
  output, error, status = Open3.capture3(executable, "--version", stdin_data: "")
  raise "cannot execute #{executable}: #{error.strip}" unless status.success?

  version = output.strip.lines.first
  raise "#{executable} --version returned no version" if version.nil? || version.empty?

  version
rescue Errno::ENOENT
  raise "#{HOST_SPEC.fetch(:display_name)} executable not found: #{executable}"
end

def parse_response(path, candidate_ids)
  return [nil, false, "missing final response"] unless File.file?(path)

  raw = File.read(path).strip
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

def response_privacy_error(path, workspace)
  return nil unless File.file?(path)

  content = File.read(path)
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
fail_usage("--jobs must be at least 1") unless options[:jobs].positive?
fail_usage("--timeout-seconds must be at least 1") unless options[:timeout_seconds].positive?
if options[:description_limit] && options[:description_limit] < 80
  fail_usage("--truncate-descriptions must be at least 80")
end
unless HOST_SPEC.fetch(:reasoning_levels).include?(options[:reasoning])
  fail_usage("unknown reasoning level for #{HOST_SPEC.fetch(:display_name)}: #{options[:reasoning]}")
end
fail_usage("unknown wrapper style: #{options[:wrapper]}") unless WRAPPER_STYLES.include?(options[:wrapper])
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
  all_cases = load_routing_cases
  selected_cases = select_cases(all_cases, options[:case_ids].uniq, options[:case_prefix])
  manifest_indexes = all_cases.each_with_index.to_h { |entry, index| [entry.fetch("id"), index] }
  candidates = active_candidates(options[:description_limit])
  candidate_ids = candidates.map(&:first)
  unknown_targets = selected_cases.map { |entry| entry.fetch("expected_skill") }.uniq - candidate_ids - ["none"]
  raise "selected cases reference unknown active skills: #{unknown_targets.join(", ")}" unless unknown_targets.empty?

  output_directory = prepare_output_directory(options[:output])
  prompts_directory = File.join(output_directory, "prompts")
  responses_directory = File.join(output_directory, "responses")
  logs_directory = File.join(output_directory, "logs")
  FileUtils.mkdir_p(prompts_directory)

  File.write(
    File.join(output_directory, "candidate-descriptions.txt"),
    candidates.map { |id, description| "#{id}\t#{description}\n" }.join
  )

  selected_cases.each do |entry|
    id = entry.fetch("id")
    rotation = manifest_indexes.fetch(id) % candidates.length
    ordered_candidates = candidates.rotate(rotation)
    style = wrapper_style(options[:wrapper], entry.fetch("prompt"))
    prompt = build_prompt(ordered_candidates, entry.fetch("prompt"), style, options[:description_limit])
    File.write(File.join(prompts_directory, "#{id}.txt"), prompt)
  end

  version = options[:dry_run] ? nil : host_version(options[:executable])
  controls = {
    "schemaVersion" => 1,
    "host" => HOST_SPEC.fetch(:display_name),
    "hostVersion" => version,
    "model" => options[:model],
    "reasoningEffort" => options[:reasoning],
    "sandbox" => HOST_FAMILY == "claude" ? "no built-in tools" : "read-only",
    "approvalPolicy" => HOST_FAMILY == "codex" ? "never" : "dontAsk",
    "ephemeralSession" => true,
    "promptTransport" => HOST_FAMILY == "grok" ? "generated prompt through file" : "generated prompt through stdin",
    "privateCaseIdentifiers" => EVAL_PRIVATE_PATHS::STRATEGY,
    "jobs" => options[:jobs],
    "timeoutSecondsPerCase" => options[:timeout_seconds],
    "descriptionCharacterLimit" => options[:description_limit],
    "wrapper" => options[:wrapper],
    "candidateRotation" => "full manifest index modulo candidate count",
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
  end
  File.write(File.join(output_directory, "controls.json"), JSON.pretty_generate(controls) + "\n")

  if options[:dry_run]
    puts "RUN_DIR=#{output_directory}"
    puts "DRY_RUN=#{selected_cases.length} cases"
    exit 0
  end

  FileUtils.mkdir_p(responses_directory)
  FileUtils.mkdir_p(logs_directory)
  workspace_root = Dir.mktmpdir("zstack-#{HOST_FAMILY}-routing-workspaces-")
  case_tokens = EVAL_PRIVATE_PATHS.build_tokens(selected_cases.map { |entry| entry.fetch("id") })
  private_prompts_directory = File.join(workspace_root, ".prompt-files")
  FileUtils.mkdir_p(private_prompts_directory) if HOST_FAMILY == "grok"
  results = []

  selected_cases.each_slice(options[:jobs]) do |slice|
    jobs = []
    begin
      slice.each do |entry|
        id = entry.fetch("id")
        private_token = case_tokens.fetch(id)
        workspace = File.join(workspace_root, private_token)
        FileUtils.mkdir_p(workspace)
        unless system("git", "init", "-q", workspace, out: File::NULL, err: File::NULL)
          raise "git init failed for #{id}"
        end

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
        invocation_path = structured_host ? File.join(logs_directory, "#{id}.invocation.json") : nil
        stdout_io = File.open(raw_result_path, "wb")
        stderr_io = structured_host ? File.open(log_path, "wb") : stdout_io
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
        job_stderr = running_job.fetch(:stderr_io)
        job_stderr.close unless job_stderr.equal?(running_job.fetch(:stdout_io)) || job_stderr.closed?
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
      execution_completed = if HOST_FAMILY == "codex"
                              exit_status.zero? && File.file?(response_path) && !File.read(response_path).strip.empty?
                            else
                              exit_status.zero? && host_result.fetch("completed") && File.file?(response_path)
                            end
      privacy_error = response_privacy_error(response_path, job.fetch(:workspace))
      execution_completed = false if privacy_error
      selected, format_valid, format_error = parse_response(response_path, candidate_ids)
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
        "promptPath" => "prompts/#{entry.fetch("id")}.txt",
        "responsePath" => "responses/#{entry.fetch("id")}.txt",
        "logPath" => "logs/#{File.basename(log_path)}",
        "responsePrivacyError" => privacy_error
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
  File.write(File.join(output_directory, "results.json"), JSON.pretty_generate(results) + "\n")
  puts "RUN_DIR=#{output_directory}"
  results.each do |result|
    status = if result.fetch("pass")
               "PASS"
             elsif result["timedOut"]
               "FAIL (timeout #{options[:timeout_seconds]}s)"
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
  puts "PASS=#{results.count { |result| result.fetch("pass") }}/#{results.length}"
  exit 1 unless results.all? { |result| result.fetch("pass") }
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
