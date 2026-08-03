#!/usr/bin/env ruby
# Shared post-selection behavioral runner for isolated host-specific adapters.

require "digest"
require "fileutils"
require "find"
require "json"
require "optparse"
require "pathname"
require "tmpdir"
require "yaml"
require_relative "lib/eval_codex_home"
require_relative "lib/eval_executable"
require_relative "lib/eval_grok_home"
require_relative "lib/eval_git_workspace"
require_relative "lib/eval_behavioral_prompt"
require_relative "lib/evidence_handoff_contract"
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
require_relative "lib/eval_skill_snapshot"
require_relative "lib/eval_skill_source"
require_relative "lib/eval_strict_yaml"
require_relative "lib/eval_workspace_watchdog"

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
EVAL_EXECUTABLE = Zstack::EvalExecutable
EVAL_GROK_HOME = Zstack::EvalGrokHome
EVAL_BEHAVIORAL_PROMPT = Zstack::EvalBehavioralPrompt
EVAL_PRIVATE_PATHS = Zstack::EvalPrivatePaths
EVIDENCE_HANDOFF_CONTRACT = Zstack::EvidenceHandoffContract
EVAL_PROCESS_SUPERVISOR = Zstack::EvalProcessSupervisor
EVAL_OUTPUT_DIRECTORY = Zstack::EvalOutputDirectory
EVAL_OUTPUT_FILE = Zstack::EvalOutputFile
EVAL_SKILL_SNAPSHOT = Zstack::EvalSkillSnapshot
GROK_SYSTEM_PROMPT = EVAL_HOST_CONTRACTS.grok_system_prompt("behavioral")
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

def active_skill_paths
  all_entries = load_yaml(CATALOG_PATH).fetch("skills")
  Zstack::EvalIdentifier.validate_unique_entries!(all_entries, label: "catalog skills")
  entries = all_entries.select { |entry| entry["status"] == "active" }
  raise "catalog.yaml has no active skills" if entries.empty?

  entries.each_with_object({}) do |entry, paths|
    id = entry.fetch("id")
    path = Zstack::EvalSkillSource.resolve(
      repository_root: ROOT,
      relative_path: entry.fetch("path"),
      skill_id: id
    )

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
  raw_cases = document.fetch("cases")
  Zstack::EvalIdentifier.validate_unique_entries!(raw_cases, label: "behavioral cases")
  cases = raw_cases.map do |entry|
    entry.merge("must" => contract_must + Array(entry["must"]))
  end
  raise "evals/cases.yaml has no cases" if cases.empty?

  cases.each do |entry|
    %w[skill kind prompt].each do |field|
      value = entry[field]
      raise "behavioral case is missing #{field}" unless value.is_a?(String) && !value.empty?
    end
    Zstack::EvalIdentifier.validate!(entry.fetch("skill"), label: "#{entry.fetch("id")} skill")
    unless %w[happy-path edge adversarial].include?(entry.fetch("kind"))
      raise "#{entry.fetch("id")}: kind must be happy-path, edge, or adversarial"
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
  EVAL_OUTPUT_DIRECTORY.prepare(requested_path, prefix: "zstack-#{HOST_FAMILY}-behavioral-")
end

def portable_tree_relative_path!(path, root, label:)
  path_bytes = path.b
  prefix = "#{root}#{File::SEPARATOR}".b
  unless path_bytes.start_with?(prefix) && path_bytes.bytesize > prefix.bytesize
    raise "#{label} path escaped its root"
  end

  relative = path_bytes.byteslice(prefix.bytesize..).dup.force_encoding(Encoding::UTF_8)
  unless Zstack::EvalLimits.portable_relative_path?(relative)
    raise "#{label} path must be canonical portable UTF-8: #{relative.dump}"
  end
  relative
end

def skill_snapshot_inventory!(source)
  source_stat = File.lstat(source)
  unless source_stat.directory? && !source_stat.symlink?
    raise "skill snapshot source must be a real directory: #{source.delete_prefix("#{ROOT}/")}"
  end

  entries = 0
  files = []
  Find.find(source) do |path|
    next if path == source

    entries += 1
    if entries > Zstack::EvalLimits::MAX_SKILL_TREE_ENTRIES
      raise "skill snapshot source exceeds #{Zstack::EvalLimits::MAX_SKILL_TREE_ENTRIES} tree entries"
    end
    stat = File.lstat(path)
    relative = portable_tree_relative_path!(path, source, label: "skill snapshot source")
    raise "skill snapshots cannot contain symbolic links: #{path.delete_prefix("#{ROOT}/")}" if stat.symlink?
    next if stat.directory?
    unless stat.file?
      raise "skill snapshots support only regular files and directories: #{path.delete_prefix("#{ROOT}/")}"
    end

    files << relative
  end
  files.sort
rescue SystemCallError => e
  raise "skill snapshot source could not be enumerated safely: #{e.class}"
end

def capture_skill_snapshot_state!(source)
  package_errors = Zstack::EvalLimits.skill_package_errors(source)
  unless package_errors.empty?
    raise "skill snapshot source is outside its safety bounds: #{package_errors.join("; ")}"
  end

  inventory = skill_snapshot_inventory!(source)
  state = inventory.to_h do |relative|
    path = File.join(source, relative)
    content = Zstack::EvalInputFile.read(
      path,
      label: "skill snapshot source #{path.delete_prefix("#{ROOT}/")}",
      require_utf8: false,
      root: ROOT
    )
    [relative.freeze, content.freeze]
  end
  unless skill_snapshot_inventory!(source) == inventory
    raise "skill snapshot source inventory changed while it was captured: #{source.delete_prefix("#{ROOT}/")}"
  end

  state.freeze
end


def capture_selected_skill_states!(skill_paths)
  total_files = 0
  total_bytes = 0
  skill_paths.to_h do |skill, source|
    state = capture_skill_snapshot_state!(source)
    total_files += state.length
    total_bytes += state.values.sum(&:bytesize)
    if total_files > Zstack::EvalLimits::MAX_ARCHIVER_SOURCE_FILES
      raise "selected skill snapshots exceed #{Zstack::EvalLimits::MAX_ARCHIVER_SOURCE_FILES} files"
    end
    if total_bytes > Zstack::EvalLimits::MAX_ARCHIVER_SOURCE_BYTES
      raise "selected skill snapshots exceed #{Zstack::EvalLimits::MAX_ARCHIVER_SOURCE_BYTES} bytes"
    end
    [skill, state]
  end
end

def write_binary_file_exclusive!(target, content, label:)
  FileUtils.mkdir_p(File.dirname(target))
  flags = File::WRONLY | File::CREAT | File::EXCL
  File.open(target, flags, 0o600) do |file|
    file.write(content)
    file.flush
    file.fsync
  end
rescue SystemCallError, IOError => e
  raise "#{label} could not be written safely: #{e.class}"
end

def write_skill_snapshot_state!(destination, state)
  FileUtils.mkdir_p(destination)
  state.each do |relative, content|
    target = File.join(destination, relative)
    write_binary_file_exclusive!(target, content, label: "skill snapshot")
  end
end

def write_snapshot_manifest(output_directory, states)
  lines = [SNAPSHOT_MANIFEST_HEADER]
  states.keys.sort.each do |skill|
    states.fetch(skill).keys.sort.each do |relative|
      content = states.fetch(skill).fetch(relative)
      retained_path = File.join("skill-snapshots", skill, relative)
      lines << format("%s  %7d  %s", Digest::SHA256.hexdigest(content), content.bytesize, retained_path)
    end
  end
  raise "skill snapshot contains no files" if lines.length == 1
  EVAL_OUTPUT_FILE.write_exclusive(
    File.join(output_directory, "skill-snapshot-manifest.txt"),
    lines.join("\n") + "\n",
    label: "skill snapshot manifest"
  )
end

def verify_retained_skill_snapshots!(snapshots_directory, states)
  states.each do |skill, state|
    error = EVAL_SKILL_SNAPSHOT.validation_error(
      File.join(snapshots_directory, skill),
      state,
      label: "retained skill snapshot"
    )
    raise "#{skill}: #{error}" if error
  end
end

def build_prompt(entry)
  EVAL_BEHAVIORAL_PROMPT.build(entry)
end

def regular_tree_files(root, max_files: nil, max_entries: nil)
  return [] unless File.exist?(root) || File.symlink?(root)
  root_stat = File.lstat(root)
  unless root_stat.directory? && !root_stat.symlink? && root_stat.uid == Process.uid
    raise "workspace output root must be a real directory owned by the current user: #{root}"
  end

  files = []
  entries = 0
  Find.find(root) do |path|
    next if path == root

    entries += 1
    if max_entries && entries > max_entries
      raise "workspace output has more than #{max_entries} tree entries"
    end
    stat = File.lstat(path)
    raise "workspace output contains a symbolic link: #{path}" if stat.symlink?
    if stat.file?
      raise "workspace output contains a file not owned by the current user: #{path}" unless stat.uid == Process.uid
      raise "workspace output contains a multiply linked file: #{path}" unless stat.nlink == 1
      files << path
      if max_files && files.length > max_files
        raise "workspace output has more than #{max_files} regular files"
      end
    elsif stat.directory?
      raise "workspace output contains a directory not owned by the current user: #{path}" unless stat.uid == Process.uid
    else
      raise "workspace output contains a non-regular entry: #{path}"
    end
  end
  files.sort
end

def capture_artifacts(workspace, copied_skill, copied_skill_state, destination, remaining_files:, remaining_bytes:)
  unexpected = Dir.children(workspace).reject { |name| %w[.git .zstack-skill artifacts].include?(name) }
  raise "artifact case wrote outside artifacts/: #{unexpected.sort.join(", ")}" unless unexpected.empty?
  skill_error = EVAL_SKILL_SNAPSHOT.validation_error(copied_skill, copied_skill_state)
  raise "artifact case changed its copied skill snapshot: #{skill_error}" if skill_error

  artifact_root = File.join(workspace, "artifacts")
  tree_options = {
    max_files: Zstack::EvalLimits::MAX_ARTIFACT_FILES,
    max_entries: Zstack::EvalLimits::MAX_ARTIFACT_TREE_ENTRIES
  }
  files = regular_tree_files(artifact_root, **tree_options)
  raise "artifact case produced no files under artifacts/" if files.empty?
  contents = files.to_h do |path|
    relative = portable_tree_relative_path!(path, artifact_root, label: "artifact")
    content = Zstack::EvalInputFile.read(
      path,
      max_bytes: Zstack::EvalLimits::MAX_RETAINED_FILE_BYTES,
      label: "artifact file",
      require_utf8: false,
      root: workspace
    )
    [relative, content]
  end
  artifact_bytes = contents.values.sum(&:bytesize)
  if artifact_bytes > Zstack::EvalLimits::MAX_ARTIFACT_BYTES
    raise "artifact case exceeds #{Zstack::EvalLimits::MAX_ARTIFACT_BYTES} total bytes"
  end
  if contents.length > remaining_files
    raise "artifact run exceeds #{Zstack::EvalLimits::MAX_RUN_ARTIFACT_FILES} retained files"
  end
  if artifact_bytes > remaining_bytes
    raise "artifact run exceeds #{Zstack::EvalLimits::MAX_RUN_ARTIFACT_BYTES} retained bytes"
  end
  current_files = regular_tree_files(artifact_root, **tree_options)
  current_relatives = current_files.map do |path|
    portable_tree_relative_path!(path, artifact_root, label: "artifact")
  end
  unless current_relatives == contents.keys
    raise "artifact file inventory changed while it was captured"
  end
  current_contents = current_files.to_h do |path|
    relative = portable_tree_relative_path!(path, artifact_root, label: "artifact")
    content = Zstack::EvalInputFile.read(
      path,
      max_bytes: Zstack::EvalLimits::MAX_RETAINED_FILE_BYTES,
      label: "artifact file",
      require_utf8: false,
      root: workspace
    )
    [relative, content]
  end
  raise "artifact file content changed while it was captured" unless current_contents == contents

  FileUtils.mkdir_p(destination)
  retained_paths = contents.map do |relative, content|
    target = File.join(destination, relative)
    write_binary_file_exclusive!(target, content, label: "retained artifact")
    retained = Zstack::EvalInputFile.read(
      target,
      max_bytes: Zstack::EvalLimits::MAX_RETAINED_FILE_BYTES,
      label: "retained artifact",
      require_utf8: false,
      root: destination
    )
    raise "retained artifact differs from captured bytes" unless retained == content
    relative
  end
  [retained_paths, artifact_bytes, contents.transform_values { |content| content.freeze }.freeze]
end

def verify_retained_artifacts!(output_directory, states)
  states.each do |relative, expected_content|
    content = Zstack::EvalInputFile.read(
      File.join(output_directory, relative),
      max_bytes: Zstack::EvalLimits::MAX_RETAINED_FILE_BYTES,
      label: "retained artifact",
      require_utf8: false,
      root: output_directory
    )
    raise "retained artifact changed after capture: #{relative}" unless content == expected_content
  end
end

def write_artifact_manifest(output_directory, states)
  return if states.empty?

  verify_retained_artifacts!(output_directory, states)

  lines = [SNAPSHOT_MANIFEST_HEADER]
  states.keys.sort.each do |relative|
    content = states.fetch(relative)
    lines << format("%s  %7d  %s", Digest::SHA256.hexdigest(content), content.bytesize, relative)
  end
  EVAL_OUTPUT_FILE.write_exclusive(
    File.join(output_directory, "artifact-manifest.txt"),
    lines.join("\n") + "\n",
    label: "artifact manifest"
  )
end

def host_version(executable_path)
  Zstack::EvalHostVersion.probe(executable_path, display_name: HOST_SPEC.fetch(:display_name))
end

def response_privacy_error(content, workspace)
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
unless options[:jobs].between?(1, Zstack::EvalLimits::MAX_RUNNER_JOBS)
  fail_usage("--jobs must be between 1 and #{Zstack::EvalLimits::MAX_RUNNER_JOBS}")
end
if options[:timeout_seconds] && !options[:timeout_seconds].between?(1, Zstack::EvalLimits::MAX_RUNNER_TIMEOUT_SECONDS)
  fail_usage("--timeout-seconds must be between 1 and #{Zstack::EvalLimits::MAX_RUNNER_TIMEOUT_SECONDS}")
end
unless HOST_SPEC.fetch(:reasoning_levels).include?(options[:reasoning])
  fail_usage("unknown reasoning level for #{HOST_SPEC.fetch(:display_name)}: #{options[:reasoning]}")
end
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
  skills = active_skill_paths
  all_cases = load_behavioral_cases
  selected_cases = select_cases(all_cases, options[:case_ids].uniq, options[:case_prefix])
  if options[:execution_filter]
    selected_cases = selected_cases.select { |entry| execution_mode(entry) == options[:execution_filter] }
    raise "no behavioral cases matched --execution #{options[:execution_filter]}" if selected_cases.empty?
  end
  if selected_cases.length > Zstack::EvalLimits::MAX_RUNNER_CASES
    raise "selected run has #{selected_cases.length} cases; maximum is #{Zstack::EvalLimits::MAX_RUNNER_CASES}"
  end
  selected_execution_modes = selected_cases.map { |entry| execution_mode(entry) }.uniq
  if selected_execution_modes.length != 1
    raise "select response and artifact cases in separate runner invocations"
  end
  run_execution_mode = selected_execution_modes.fetch(0)
  if run_execution_mode == "artifact" && options[:jobs] != Zstack::EvalLimits::MAX_ARTIFACT_RUNNER_JOBS
    warn "artifact execution forces --jobs #{Zstack::EvalLimits::MAX_ARTIFACT_RUNNER_JOBS} for whole-run resource monitoring"
    options[:jobs] = Zstack::EvalLimits::MAX_ARTIFACT_RUNNER_JOBS
  end
  options[:timeout_seconds] ||= run_execution_mode == "artifact" ? 1200 : 600
  unknown_skills = selected_cases.map { |entry| entry.fetch("skill") }.uniq - skills.keys
  raise "selected cases reference unknown active skills: #{unknown_skills.join(", ")}" unless unknown_skills.empty?

  output_reservation = prepare_output_directory(options[:output])
  output_directory = output_reservation.path
  prompts_directory = File.join(output_directory, "prompts")
  snapshots_directory = File.join(output_directory, "skill-snapshots")
  FileUtils.mkdir_p(prompts_directory)
  FileUtils.mkdir_p(snapshots_directory)

  selected_skill_paths = selected_cases.map { |entry| entry.fetch("skill") }.uniq.sort.to_h do |skill|
    [skill, skills.fetch(skill)]
  end
  skill_snapshot_states = capture_selected_skill_states!(selected_skill_paths)
  skill_snapshot_states.each do |skill, state|
    write_skill_snapshot_state!(File.join(snapshots_directory, skill), state)
  end
  verify_retained_skill_snapshots!(snapshots_directory, skill_snapshot_states)
  current_skill_states = capture_selected_skill_states!(selected_skill_paths)
  changed_skill = skill_snapshot_states.keys.find do |skill|
    current_skill_states.fetch(skill) != skill_snapshot_states.fetch(skill)
  end
  if changed_skill
    raise "skill snapshot source changed while it was captured: #{changed_skill}"
  end
  write_snapshot_manifest(output_directory, skill_snapshot_states)
  prompt_budget = Zstack::EvalPromptWriter::Budget.new
  generated_prompts = {}
  selected_cases.each do |entry|
    id = entry.fetch("id")
    prompt = build_prompt(entry)
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
  verify_retained_skill_snapshots!(snapshots_directory, skill_snapshot_states)
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
    "promptTransport" => HOST_FAMILY == "grok" ? "generated prompt through anonymous descriptor" : "generated prompt through stdin",
    "privateCaseIdentifiers" => EVAL_PRIVATE_PATHS::STRATEGY,
    "skillSource" => "exact copied source snapshots",
    "executionMode" => run_execution_mode,
    "artifactCapture" => run_execution_mode == "artifact",
    "webSearch" => false,
    "subagents" => false,
    "jobs" => options[:jobs],
    "maxCasesPerRun" => Zstack::EvalLimits::MAX_RUNNER_CASES,
    "maxPromptBytesPerCase" => Zstack::EvalLimits::MAX_PROMPT_BYTES,
    "maxPromptBytesPerRun" => Zstack::EvalLimits::MAX_RUN_PROMPT_BYTES,
    "promptBytes" => prompt_budget.total_bytes,
    "timeoutSecondsPerCase" => options[:timeout_seconds],
    "maxHostOutputBytesPerCase" => EVAL_PROCESS_SUPERVISOR::MAX_HOST_OUTPUT_BYTES,
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
  controls["runtimeTreeMonitoring"] = true
  controls["concurrentRuntimeMonitoring"] = true
  controls["pidMonitoringStartsAtSpawn"] = true
  controls["sharedRootMonitoring"] = true
  controls["privatePromptIntegrityMonitoring"] = HOST_FAMILY == "grok"
  controls["outputDirectoryIdentityMonitoring"] = true
  controls["outputTreeMonitoring"] = true
  controls["exclusiveRunnerOutputs"] = true
  controls["workspaceViolationStopsRun"] = true
  controls["copiedSkillIntegrityMonitoring"] = true
  controls["anonymousPromptDescriptor"] = true
  controls["singleLinkInputFiles"] = true
  controls["singleLinkRuntimeFiles"] = true
  controls["maxRuntimeOutputFiles"] = Zstack::EvalLimits::MAX_RUNTIME_OUTPUT_FILES
  controls["maxRuntimeOutputTreeEntries"] = Zstack::EvalLimits::MAX_RUNTIME_OUTPUT_TREE_ENTRIES
  controls["maxRuntimeOutputBytes"] = Zstack::EvalLimits::MAX_RUNTIME_OUTPUT_BYTES
  controls["maxRuntimeGitFiles"] = Zstack::EvalLimits::MAX_RUNTIME_GIT_FILES
  controls["maxRuntimeGitTreeEntries"] = Zstack::EvalLimits::MAX_RUNTIME_GIT_TREE_ENTRIES
  controls["maxRuntimeGitBytes"] = Zstack::EvalLimits::MAX_RUNTIME_GIT_BYTES
  controls["maxRuntimeHostHomeFiles"] = Zstack::EvalLimits::MAX_RUNTIME_HOST_HOME_FILES
  controls["maxRuntimeHostHomeTreeEntries"] = Zstack::EvalLimits::MAX_RUNTIME_HOST_HOME_TREE_ENTRIES
  controls["maxRuntimeHostHomeBytes"] = Zstack::EvalLimits::MAX_RUNTIME_HOST_HOME_BYTES
  if run_execution_mode == "artifact"
    controls["writeBoundary"] = "artifacts/ only; audited after execution"
    controls["maxArtifactFilesPerCase"] = Zstack::EvalLimits::MAX_ARTIFACT_FILES
    controls["maxArtifactFileBytes"] = Zstack::EvalLimits::MAX_RETAINED_FILE_BYTES
    controls["maxArtifactBytesPerCase"] = Zstack::EvalLimits::MAX_ARTIFACT_BYTES
    controls["maxArtifactTreeEntriesPerCase"] = Zstack::EvalLimits::MAX_ARTIFACT_TREE_ENTRIES
    controls["maxArtifactFilesPerRun"] = Zstack::EvalLimits::MAX_RUN_ARTIFACT_FILES
    controls["maxArtifactBytesPerRun"] = Zstack::EvalLimits::MAX_RUN_ARTIFACT_BYTES
    controls["maxArtifactJobs"] = Zstack::EvalLimits::MAX_ARTIFACT_RUNNER_JOBS
    controls["artifactRuntimeMonitoring"] = true
    controls["artifactManifestFromCapturedBytes"] = true
  end
  controls["promptDescriptorPath"] = GROK_PROMPT_PATH if HOST_FAMILY == "grok"
  EVAL_OUTPUT_FILE.write_exclusive(
    File.join(output_directory, "controls.json"),
    JSON.pretty_generate(controls) + "\n",
    max_bytes: Zstack::EvalLimits::MAX_RUN_PROMPT_BYTES,
    label: "behavioral controls"
  )
  output_reservation.verify!

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
  workspace_root_identity = Zstack::EvalOwnedDirectory.capture(
    workspace_root,
    label: "behavioral workspace root"
  )
  case_tokens = EVAL_PRIVATE_PATHS.build_tokens(selected_cases.map { |entry| entry.fetch("id") })
  results = []
  workspace_specs = []
  retained_artifact_files = 0
  retained_artifact_bytes = 0
  retained_artifact_states = {}

  selected_cases.each_slice(options[:jobs]) do |slice|
    verify_retained_skill_snapshots!(snapshots_directory, skill_snapshot_states)
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
        skill = entry.fetch("skill")
        private_token = case_tokens.fetch(id)
        workspace = File.join(workspace_root, private_token)
        FileUtils.mkdir_p(workspace)
        Zstack::EvalGitWorkspace.prepare(workspace)
        copied_skill = File.join(workspace, ".zstack-skill", skill)
        copied_skill_state = skill_snapshot_states.fetch(skill)
        EVAL_SKILL_SNAPSHOT.materialize!(copied_skill, copied_skill_state)
        FileUtils.mkdir_p(File.join(workspace, "artifacts")) if run_execution_mode == "artifact"

        prompt_path = File.join(prompts_directory, "#{id}.txt")
        prompt_content = generated_prompts.fetch(id)
        retained_prompt = Zstack::EvalInputFile.read(
          prompt_path,
          max_bytes: Zstack::EvalLimits::MAX_PROMPT_BYTES,
          label: "retained behavioral prompt",
          root: output_directory
        )
        unless retained_prompt == prompt_content
          raise "#{id}: retained behavioral prompt changed after generation"
        end
        host_prompt_path = HOST_FAMILY == "grok" ? GROK_PROMPT_PATH : prompt_path
        response_path = File.join(responses_directory, "#{id}.txt")
        log_path = File.join(logs_directory, "#{id}.log")
        structured_host = STRUCTURED_HOSTS.include?(HOST_FAMILY)
        raw_result_path = structured_host ? File.join(logs_directory, "#{id}.json") : log_path
        stderr_path = structured_host ? log_path : nil
        invocation_path = structured_host ? File.join(logs_directory, "#{id}.invocation.json") : nil
        host_output_paths = [raw_result_path, log_path]
        host_output_paths << response_path unless structured_host
        stdout_io = EVAL_OUTPUT_FILE.open_exclusive(raw_result_path, label: "host stdout")
        stderr_io = structured_host ? EVAL_OUTPUT_FILE.open_exclusive(stderr_path, label: "host stderr") : stdout_io
        prompt_io = Zstack::EvalPromptWriter.anonymous_input(
          prompt_content,
          label: "behavioral prompt input"
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
          workspace: workspace,
          copied_skill: copied_skill,
          copied_skill_state: copied_skill_state
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
        stderr_io = prepared_job.fetch(:stderr_io)
        stderr_io.close unless stderr_io.equal?(prepared_job.fetch(:stdout_io)) || stderr_io.closed?
      end
      raise
    end

    jobs.each do |job|
      workspace_specs << {
        workspace: job.fetch(:workspace),
        allowed_top_level: run_execution_mode == "artifact" ? Zstack::EvalWorkspaceWatchdog::ALLOWED_TOP_LEVEL : %w[.git .zstack-skill],
        copied_skill: job.fetch(:copied_skill),
        copied_skill_state: job.fetch(:copied_skill_state),
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
        copied_skill_error = EVAL_SKILL_SNAPSHOT.validation_error(
          job.fetch(:copied_skill),
          job.fetch(:copied_skill_state)
        )
        raise "#{job.fetch(:entry).fetch("id")}: #{copied_skill_error}" if copied_skill_error

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
          if run_execution_mode == "artifact"
            Zstack::EvalWorkspaceWatchdog.artifact_error(
              job.fetch(:workspace),
              retained_files: retained_artifact_files,
              retained_bytes: retained_artifact_bytes,
              copied_skill: job.fetch(:copied_skill),
              copied_skill_state: job.fetch(:copied_skill_state),
              host_home: job[:codex_home] || job[:grok_home]
            )
          else
            Zstack::EvalWorkspaceWatchdog.baseline_error(
              job.fetch(:workspace),
              allowed_top_level: %w[.git .zstack-skill],
              copied_skill: job.fetch(:copied_skill),
              copied_skill_state: job.fetch(:copied_skill_state),
              host_home: job[:codex_home] || job[:grok_home]
            )
          end
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
        completed = if HOST_FAMILY == "codex"
                      !output_limited && workspace_limit_error.nil? && exit_status == 0 && response_file_error.nil? && !response_content.strip.empty?
                    else
                      !output_limited && workspace_limit_error.nil? && exit_status == 0 && host_result.fetch("completed") && response_file_error.nil? && !response_content.strip.empty?
                    end
        privacy_error = response_content && response_privacy_error(response_content, job.fetch(:workspace))
        completed = false if privacy_error
        artifact_paths = []
        artifact_error = nil
        if run_execution_mode == "artifact" && completed
          begin
            captured, captured_bytes, captured_contents = capture_artifacts(
              job.fetch(:workspace),
              job.fetch(:copied_skill),
              job.fetch(:copied_skill_state),
              File.join(artifacts_directory, entry.fetch("id")),
              remaining_files: Zstack::EvalLimits::MAX_RUN_ARTIFACT_FILES - retained_artifact_files,
              remaining_bytes: Zstack::EvalLimits::MAX_RUN_ARTIFACT_BYTES - retained_artifact_bytes
            )
            artifact_paths = captured.map { |relative| "artifacts/#{entry.fetch("id")}/#{relative}" }
            captured_contents.each do |relative, content|
              retained_artifact_states["artifacts/#{entry.fetch("id")}/#{relative}"] = content
            end
            retained_artifact_files += captured.length
            retained_artifact_bytes += captured_bytes
          rescue StandardError => e
            artifact_error = e.message
            completed = false
          end
        end
        contract_sources = []
        unless response_content.nil?
          contract_sources << { name: "responses/#{entry.fetch("id")}.txt", content: response_content }
        end
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
          "outputLimited" => output_limited,
          "workspaceLimitError" => workspace_limit_error,
          "hostOutputBytes" => EVAL_PROCESS_SUPERVISOR.output_bytes(job.fetch(:host_output_paths)),
          "promptPath" => "prompts/#{entry.fetch("id")}.txt",
          "responsePath" => "responses/#{entry.fetch("id")}.txt",
          "logPath" => "logs/#{File.basename(log_path)}",
          "executionMode" => run_execution_mode,
          "artifactPaths" => artifact_paths,
          "artifactError" => artifact_error,
          "responsePrivacyError" => privacy_error,
          "responseFileError" => response_file_error,
          "evidenceHandoffContract" => evidence_handoff_contract,
          "grade" => nil
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
  verify_retained_skill_snapshots!(snapshots_directory, skill_snapshot_states)
  verify_retained_artifacts!(output_directory, retained_artifact_states)
  output_reservation.verify!
  write_artifact_manifest(output_directory, retained_artifact_states)
  EVAL_OUTPUT_FILE.write_exclusive(
    File.join(output_directory, "results.json"),
    JSON.pretty_generate(results) + "\n",
    max_bytes: Zstack::EvalLimits::MAX_RUN_PROMPT_BYTES,
    label: "behavioral results"
  )
  verify_retained_skill_snapshots!(snapshots_directory, skill_snapshot_states)
  verify_retained_artifacts!(output_directory, retained_artifact_states)
  output_reservation.verify!
  review = {
    "schemaVersion" => 1,
    "reviewer" => nil,
    "cases" => selected_cases.map do |entry|
      criteria = entry.fetch("must").map do |criterion|
        if criterion == EVIDENCE_HANDOFF_CONTRACT::CRITERION
          result = results.find { |candidate| candidate.fetch("id") == entry.fetch("id") }
          if result
            contract = result.fetch("evidenceHandoffContract")
            {
              "expectation" => "present",
              "criterion" => criterion,
              "observed" => contract.fetch("passed"),
              "evidence" => EVIDENCE_HANDOFF_CONTRACT.review_evidence(contract)
            }
          else
            { "expectation" => "present", "criterion" => criterion, "observed" => nil, "evidence" => nil }
          end
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
  EVAL_OUTPUT_FILE.write_exclusive(
    File.join(output_directory, "review.json"),
    JSON.pretty_generate(review) + "\n",
    max_bytes: Zstack::EvalLimits::MAX_RUN_PROMPT_BYTES,
    label: "behavioral review scaffold"
  )
  verify_retained_skill_snapshots!(snapshots_directory, skill_snapshot_states)
  verify_retained_artifacts!(output_directory, retained_artifact_states)
  output_reservation.verify!
  puts "RUN_DIR=#{output_directory}"
  results.each do |result|
    execution_status = if result.fetch("completed")
                         "COMPLETED (ungraded)"
                       else
                         details = []
                         details << "timeout #{options[:timeout_seconds]}s" if result["timedOut"]
                         if result["outputLimited"]
                           details << "output limit #{EVAL_PROCESS_SUPERVISOR::MAX_HOST_OUTPUT_BYTES} bytes"
                         elsif result["workspaceLimitError"]
                           details << result["workspaceLimitError"]
                         elsif result["errorCategory"] && result["errorCategory"] != "timeout"
                           details << result["errorCategory"]
                         end
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
  puts "COMPLETED=#{results.count { |result| result.fetch("completed") }}/#{selected_cases.length}; GRADED=0"
  exit 1 unless results.length == selected_cases.length && results.all? { |result| result.fetch("completed") }
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
