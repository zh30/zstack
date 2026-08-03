#!/usr/bin/env ruby
# Report which current behavioral or routing cases have archived passing evidence.

require "json"
require "find"
require "optparse"
require "digest"
require "rbconfig"
require "yaml"
require_relative "lib/eval_behavioral_prompt"
require_relative "lib/eval_bounded_command"
require_relative "lib/eval_evidence_tree"
require_relative "lib/eval_input_file"
require_relative "lib/eval_limits"
require_relative "lib/eval_routing_prompt"
require_relative "lib/eval_strict_json"
require_relative "lib/eval_strict_yaml"
require_relative "lib/evidence_handoff_contract"

ROOT = File.expand_path("..", __dir__)
CATALOG_PATH = File.join(ROOT, "catalog.yaml")
CASES_PATH = File.join(ROOT, "evals", "cases.yaml")
ROUTING_PATH = File.join(ROOT, "evals", "routing.yaml")
RUNS_ROOT = File.join(ROOT, "evals", "runs")
EVIDENCE_VALIDATOR = File.join(ROOT, "scripts", "validate-evidence.rb")
SUPPORTED_HOST_FAMILIES = %w[claude codex grok].freeze
SUPPORTED_SUITES = %w[behavioral routing].freeze
EVIDENCE_HANDOFF_CONTRACT = Zstack::EvidenceHandoffContract
EVAL_BEHAVIORAL_PROMPT = Zstack::EvalBehavioralPrompt
EVAL_ROUTING_PROMPT = Zstack::EvalRoutingPrompt
CODEX_AMBIENT_CONTEXT_KEYS = %w[
  CODEX_INTERNAL_ORIGINATOR_OVERRIDE
  CODEX_PERMISSION_PROFILE
  CODEX_THREAD_ID
].freeze

def load_yaml(path)
  Zstack::EvalStrictYaml.parse(Zstack::EvalInputFile.read(path, label: path, root: ROOT), path)
rescue Errno::ENOENT, Psych::Exception => e
  raise "cannot load #{path.delete_prefix("#{ROOT}/")}: #{e.message}"
end

def validate_archives!
  result = Zstack::EvalBoundedCommand.capture(
    RbConfig.ruby,
    EVIDENCE_VALIDATOR,
    timeout_seconds: Zstack::EvalLimits::EVIDENCE_TOOL_TIMEOUT_SECONDS,
    max_output_bytes: Zstack::EvalLimits::MAX_EVIDENCE_TOOL_OUTPUT_BYTES
  )
  if result.timed_out
    raise "evidence validation timed out after #{Zstack::EvalLimits::EVIDENCE_TOOL_TIMEOUT_SECONDS} seconds"
  end
  if result.output_limited
    raise "evidence validation exceeded #{Zstack::EvalLimits::MAX_EVIDENCE_TOOL_OUTPUT_BYTES} output bytes"
  end
  return if result.status.success?

  diagnostics = [result.stderr, result.stdout].join("\n")
  first_error = diagnostics.each_line.map(&:strip).find { |line| !line.empty? }
  detail = first_error ? ": #{first_error}" : ""
  raise "evidence validation failed#{detail}"
end

def host_family(name)
  case name.to_s.downcase
  when /codex/ then "codex"
  when /claude/ then "claude"
  when /grok/ then "grok"
  else name.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|\-\z/, "")
  end
end

def execution_contract_current?(archive_data)
  family = host_family(archive_data.dig("host", "name"))
  return false unless SUPPORTED_HOST_FAMILIES.include?(family)
  defaults = archive_data["executionDefaults"]
  return false unless defaults.is_a?(Hash)
  return false unless defaults["webSearch"] == false
  return false unless defaults["subagents"] == false
  return false unless defaults["ephemeralSession"] == true
  timeout = defaults["timeoutSecondsPerCase"]
  if !timeout.nil? && (!timeout.is_a?(Integer) || !timeout.between?(1, Zstack::EvalLimits::MAX_RUNNER_TIMEOUT_SECONDS))
    return false
  end

  case family
  when "claude"
    return false unless defaults["sessionPersistence"] == false
    return false unless Zstack::EvalLimits.finite_positive_number?(defaults["maxBudgetUsdPerCase"])
  when "grok"
    return false unless defaults["sessionPersistence"] == false
    return false unless defaults["maxTurns"].is_a?(Integer) && defaults["maxTurns"].between?(1, Zstack::EvalLimits::MAX_GROK_TURNS)
    return false unless defaults["ambientAgentSkillsMayBeDiscovered"] == true
  when "codex"
    return false unless defaults["isolatedHostHome"] == true
    return false unless defaults["ambientDesktopContextDisabled"] == CODEX_AMBIENT_CONTEXT_KEYS
    return false unless timeout.is_a?(Integer) && timeout.between?(1, Zstack::EvalLimits::MAX_RUNNER_TIMEOUT_SECONDS)
    incidents = Array(archive_data["runnerIncidents"])
    return false if incidents.any? { |incident| incident.match?(/MCP OAuth invalid_grant|installed-skill context-budget warning/) }
  end
  true
end

def load_frontmatter(path)
  content = Zstack::EvalInputFile.read(path, label: path, root: ROOT)
  match = content.match(/\A---\r?\n(?<yaml>.*?)\r?\n---(?:\r?\n|\z)/m)
  raise "#{path.delete_prefix("#{ROOT}/")}: missing closed frontmatter" unless match

  data = Zstack::EvalStrictYaml.parse(match[:yaml], path)
  raise "#{path.delete_prefix("#{ROOT}/")}: frontmatter must be a mapping" unless data.is_a?(Hash)

  data
end

def read_evidence_file(snapshot, path, require_utf8: true)
  content = Zstack::EvalInputFile.read(
    path,
    label: path,
    require_utf8: require_utf8,
    root: ROOT
  )
  snapshot.verify_content!(path, content)
  content
end

def tree_signature(path, evidence_snapshot: nil)
  return nil unless File.directory?(path) && !File.symlink?(path)

  paths = []
  Find.find(path) do |entry|
    next if entry == path
    return nil if paths.length >= Zstack::EvalLimits::MAX_SKILL_TREE_ENTRIES

    paths << entry
  end
  paths.sort!
  files = 0
  bytes = 0
  entries = paths.map do |entry|
    stat = File.lstat(entry)
    return nil if stat.symlink? || (!stat.file? && !stat.directory?)
    next if stat.directory?

    files += 1
    return nil if files > Zstack::EvalLimits::MAX_SKILL_FILES

    relative = entry.delete_prefix("#{path}/")
    content = if evidence_snapshot
                read_evidence_file(evidence_snapshot, entry, require_utf8: false)
              else
                Zstack::EvalInputFile.read(
                  entry,
                  label: relative,
                  require_utf8: false,
                  root: ROOT
                )
              end
    bytes += content.bytesize
    return nil if bytes > Zstack::EvalLimits::MAX_SKILL_BYTES
    [relative, content.bytesize, Digest::SHA256.hexdigest(content)]
  end.compact
  return nil if entries.empty?
  observed_paths = []
  Find.find(path) do |entry|
    next if entry == path
    return nil if observed_paths.length >= Zstack::EvalLimits::MAX_SKILL_TREE_ENTRIES

    observed_paths << entry
  end
  observed_paths.sort!
  return nil unless observed_paths == paths

  Digest::SHA256.hexdigest(entries.map { |entry| entry.join("\0") }.join("\n"))
rescue SystemCallError, Zstack::EvalInputFile::ReadError
  nil
end

def current_candidate_descriptions(active_entries)
  active_entries.map do |entry|
    id = entry.fetch("id")
    path = File.expand_path(entry.fetch("path"), ROOT)
    frontmatter = load_frontmatter(File.join(path, "SKILL.md"))
    raise "#{id}: frontmatter name does not match catalog id" unless frontmatter["name"] == id

    description = frontmatter.fetch("description").gsub(/\s+/, " ").strip
    "#{id}\t#{description}\n"
  end.sort.join
end

def behavioral_source_current?(archive, run, entry, current_skill_signatures, evidence_snapshot)
  return false unless run["grade"] == "pass" && run["exitStatus"] == 0

  id = entry.fetch("id")
  skill = entry.fetch("skill")
  snapshot = File.join(archive, "raw", "skill-snapshots", skill)
  return false unless tree_signature(snapshot, evidence_snapshot: evidence_snapshot) == current_skill_signatures.fetch(skill)

  prompt_path = File.join(archive, "raw", "prompts", "#{id}.txt")
  prompt = read_evidence_file(evidence_snapshot, prompt_path)
  return false unless prompt.b == EVAL_BEHAVIORAL_PROMPT.build(entry).b

  review_path = File.join(archive, "runner-review.json")
  review_content = read_evidence_file(evidence_snapshot, review_path)
  review = Zstack::EvalStrictJson.parse(review_content)
  reviewed = Array(review["cases"]).find { |candidate| candidate["id"] == run["case"] }
  return false unless reviewed && reviewed["grade"] == "pass"

  mechanical = run["evidenceHandoffContract"]
  return false unless mechanical.is_a?(Hash) && mechanical["schemaVersion"] == 1 && mechanical["passed"] == true
  criteria = Array(reviewed["criteria"])
  mechanical_review = criteria.find do |criterion|
    criterion["expectation"] == "present" && criterion["criterion"] == EVIDENCE_HANDOFF_CONTRACT::CRITERION
  end
  return false unless mechanical_review && mechanical_review["observed"] == true

  expected = Array(entry["must"]).map { |criterion| ["present", criterion] } +
             Array(entry["must_not"]).map { |criterion| ["absent", criterion] }
  reviewed_criteria = criteria.map { |criterion| [criterion["expectation"], criterion["criterion"]] }
  return false unless reviewed_criteria == expected

  criteria.all? do |criterion|
    criterion["expectation"] == "present" ? criterion["observed"] == true : criterion["observed"] == false
  end
rescue Errno::ENOENT, JSON::ParserError, KeyError, Zstack::EvalInputFile::ReadError
  false
end

def routing_source_current?(archive, run, entry, candidate_descriptions, case_index, evidence_snapshot)
  return false unless run["grade"] == "pass" && run["exitStatus"] == 0

  candidates_path = File.join(archive, "raw", "candidate-descriptions.txt")
  candidates_content = read_evidence_file(evidence_snapshot, candidates_path)
  return false unless candidates_content == candidate_descriptions

  results_path = File.join(archive, "runner-results.json")
  results_content = read_evidence_file(evidence_snapshot, results_path)
  archived_result = Array(Zstack::EvalStrictJson.parse(results_content)).find { |candidate| candidate["id"] == run["case"] }
  expected_skill = entry.fetch("expected_skill")
  return false unless archived_result &&
                      archived_result["expected"] == expected_skill &&
                      archived_result["selected"] == expected_skill &&
                      archived_result["pass"] == true &&
                      archived_result["executionCompleted"] == true &&
                      archived_result["formatValid"] == true &&
                      archived_result["exitStatus"] == 0 &&
                      archived_result["responsePrivacyError"].nil?

  controls_path = File.join(archive, "runner-controls.json")
  controls_content = read_evidence_file(evidence_snapshot, controls_path)
  controls = Zstack::EvalStrictJson.parse(controls_content)
  return false unless controls["descriptionCharacterLimit"].nil? &&
                      controls["candidateRotation"] == "full manifest index modulo candidate count" &&
                      %w[auto en zh].include?(controls["wrapper"])

  candidates = candidate_descriptions.lines(chomp: true).map { |line| line.split("\t", 2) }
  return false if candidates.empty? || candidates.any? { |candidate| candidate.length != 2 || candidate.any?(&:empty?) }
  ordered_candidates = candidates.rotate(case_index % candidates.length)
  style = EVAL_ROUTING_PROMPT.wrapper_style(controls.fetch("wrapper"), entry.fetch("prompt"))
  expected_prompt = EVAL_ROUTING_PROMPT.build(ordered_candidates, entry.fetch("prompt"), style)
  prompt_path = File.join(archive, "raw", "prompts", "#{entry.fetch("id")}.txt")
  prompt = read_evidence_file(evidence_snapshot, prompt_path)
  prompt.b == expected_prompt.b
rescue Errno::ENOENT, JSON::ParserError, KeyError, Zstack::EvalInputFile::ReadError
  false
end

options = {
  json: false,
  require_complete_pass: false,
  require_current_complete_pass: false,
  required_host_families: [],
  required_current_host_families: [],
  suite: "behavioral"
}
parser = OptionParser.new do |opts|
  opts.banner = "Usage: ruby scripts/report-evidence-coverage.rb [options]"
  opts.on("--suite SUITE", "behavioral or routing (default: behavioral)") { |value| options[:suite] = value.downcase }
  opts.on("--json", "Print the report as JSON") { options[:json] = true }
  opts.on("--require-complete-pass", "Require a historical complete pass for every registered case; source freshness ignored") do
    options[:require_complete_pass] = true
  end
  opts.on("--require-current-complete-pass", "Require a current-source complete pass for every registered case") do
    options[:require_current_complete_pass] = true
  end
  opts.on("--require-complete-pass-host HOST", "Require historical passes on one host; source freshness ignored; repeatable") do |value|
    options[:required_host_families] << value.downcase
  end
  opts.on("--require-current-complete-pass-host HOST", "Require current-source passes on one host; repeatable") do |value|
    options[:required_current_host_families] << value.downcase
  end
  opts.on("-h", "--help", "Show help") do
    puts opts
    exit 0
  end
end

begin
  parser.parse!
  raise "unexpected positional arguments: #{ARGV.join(" ")}" unless ARGV.empty?
  unknown_hosts = (options[:required_host_families] + options[:required_current_host_families]).uniq - SUPPORTED_HOST_FAMILIES
  raise "unknown host family: #{unknown_hosts.join(", ")}" unless unknown_hosts.empty?
  raise "unknown evidence suite: #{options[:suite]}" unless SUPPORTED_SUITES.include?(options[:suite])
  evidence_snapshot = Zstack::EvalEvidenceTree.capture(RUNS_ROOT)
  validate_archives!
  unless Zstack::EvalEvidenceTree.capture(RUNS_ROOT) == evidence_snapshot
    raise "evidence archive tree changed during validation"
  end

  catalog = load_yaml(CATALOG_PATH)
  active_entries = Array(catalog.fetch("skills")).select { |entry| entry["status"] == "active" }
  active_skills = active_entries.map { |entry| entry.fetch("id") }
  manifest_path = options[:suite] == "behavioral" ? CASES_PATH : ROUTING_PATH
  manifest = load_yaml(manifest_path)
  cases = Array(manifest.fetch("cases"))
  if options[:suite] == "behavioral"
    contract_must = Array(manifest.fetch("contract_must"))
    raise "evals/cases.yaml has no contract_must criteria" if contract_must.empty?
    cases = cases.map { |entry| entry.merge("must" => contract_must + Array(entry["must"])) }
  end
  current_cases = if options[:suite] == "behavioral"
                    cases.select { |entry| active_skills.include?(entry["skill"]) }
                  else
                    cases.select { |entry| entry["expected_skill"] == "none" || active_skills.include?(entry["expected_skill"]) }
                  end
  case_ids = current_cases.map { |entry| entry.fetch("id") }
  manifest_label = manifest_path.delete_prefix("#{ROOT}/")
  raise "#{manifest_label} has duplicate ids" unless case_ids.uniq.length == case_ids.length
  current_cases_by_id = current_cases.to_h { |entry| [entry.fetch("id"), entry] }
  case_indexes = cases.each_with_index.to_h { |entry, index| [entry.fetch("id"), index] }
  current_skill_signatures = if options[:suite] == "behavioral"
                               active_entries.to_h do |entry|
                                 id = entry.fetch("id")
                                 [id, tree_signature(File.expand_path(entry.fetch("path"), ROOT))]
                               end
                             else
                               {}
                             end
  if current_skill_signatures.value?(nil)
    raise "one or more active skill trees are empty, unsafe, or unreadable"
  end
  candidate_descriptions = options[:suite] == "routing" ? current_candidate_descriptions(active_entries) : nil

  archived_runs = []
  evidence_snapshot.run_json_paths.each do |path|
    content = read_evidence_file(evidence_snapshot, path)
    data = Zstack::EvalStrictJson.parse(content)
    next unless data["suite"] == options[:suite]

    host_name = data.dig("host", "name").to_s
    provenance = data.dig("provenance", "status")
    execution_current = execution_contract_current?(data)
    archive = File.dirname(path)
    Array(data["runs"]).each do |run|
      current_entry = current_cases_by_id[run["case"]]
      source_current = if current_entry.nil? || !execution_current
                         false
                       elsif options[:suite] == "behavioral"
                         behavioral_source_current?(
                           archive, run, current_entry, current_skill_signatures, evidence_snapshot
                         )
                       else
                         routing_source_current?(
                           archive, run, current_entry, candidate_descriptions,
                           case_indexes.fetch(current_entry.fetch("id")),
                           evidence_snapshot
                         )
                       end
      archived_runs << {
        "archive" => File.basename(File.dirname(path)),
        "case" => run["case"],
        "phase" => run["phase"],
        "grade" => run["grade"],
        "host" => host_name,
        "hostFamily" => host_family(host_name),
        "provenance" => provenance,
        "sourceCurrent" => source_current
      }
    end
  rescue Zstack::EvalInputFile::ReadError, JSON::ParserError => e
    raise "cannot parse #{path.delete_prefix("#{ROOT}/")}: #{e.message}"
  end

  case_reports = current_cases.map do |entry|
    runs = archived_runs.select { |run| run["case"] == entry.fetch("id") }
    passes = runs.select { |run| run["grade"] == "pass" }
    complete_passes = passes.select { |run| run["provenance"] == "complete" }
    current_complete_passes = complete_passes.select { |run| run["sourceCurrent"] }
    report = {
      "id" => entry.fetch("id"),
      "archivedRuns" => runs.length,
      "passHostFamilies" => passes.map { |run| run["hostFamily"] }.uniq.sort,
      "completePassHostFamilies" => complete_passes.map { |run| run["hostFamily"] }.uniq.sort,
      "currentCompletePassHostFamilies" => current_complete_passes.map { |run| run["hostFamily"] }.uniq.sort,
      "hasPass" => !passes.empty?,
      "hasCompletePass" => !complete_passes.empty?,
      "hasCurrentCompletePass" => !current_complete_passes.empty?
    }
    if options[:suite] == "behavioral"
      report["skill"] = entry.fetch("skill")
      report["kind"] = entry.fetch("kind")
    else
      report["expectedSkill"] = entry.fetch("expected_skill")
    end
    report
  end

  group_field = options[:suite] == "behavioral" ? "skill" : "expectedSkill"
  group_key = options[:suite] == "behavioral" ? "skill" : "expectedSkill"
  group_values = options[:suite] == "behavioral" ? active_skills : active_skills + ["none"]
  group_reports = group_values.map do |group|
    group_cases = case_reports.select { |entry| entry[group_field] == group }
    complete_host_families = if group_cases.empty?
                               []
                             else
                               group_cases.map { |entry| entry["completePassHostFamilies"] }
                                          .reduce { |common, families| common & families }
                                          .sort
                             end
    current_complete_host_families = if group_cases.empty?
                                       []
                                     else
                                       group_cases.map { |entry| entry["currentCompletePassHostFamilies"] }
                                                  .reduce { |common, families| common & families }
                                                  .sort
                                     end
    {
      group_key => group,
      "cases" => group_cases.length,
      "passingCases" => group_cases.count { |entry| entry["hasPass"] },
      "completePassingCases" => group_cases.count { |entry| entry["hasCompletePass"] },
      "currentCompletePassingCases" => group_cases.count { |entry| entry["hasCurrentCompletePass"] },
      "completePassHostFamilies" => complete_host_families,
      "currentCompletePassHostFamilies" => current_complete_host_families
    }
  end

  observed_host_families = archived_runs.map { |run| run["hostFamily"] }.reject(&:empty?).uniq
  host_reports = (SUPPORTED_HOST_FAMILIES + observed_host_families).uniq.sort.map do |family|
    family_cases = case_reports.map do |entry|
      runs = archived_runs.select { |run| run["case"] == entry.fetch("id") && run["hostFamily"] == family }
      passes = runs.select { |run| run["grade"] == "pass" }
      complete_passes = passes.select { |run| run["provenance"] == "complete" }
      current_complete_passes = complete_passes.select { |run| run["sourceCurrent"] }
      [entry.fetch("id"), !passes.empty?, !complete_passes.empty?, !current_complete_passes.empty?]
    end
    {
      "hostFamily" => family,
      "passingCases" => family_cases.count { |entry| entry[1] },
      "completePassingCases" => family_cases.count { |entry| entry[2] },
      "currentCompletePassingCases" => family_cases.count { |entry| entry[3] },
      "missingCompletePass" => family_cases.reject { |entry| entry[2] }.map { |entry| entry[0] },
      "missingCurrentCompletePass" => family_cases.reject { |entry| entry[3] }.map { |entry| entry[0] }
    }
  end

  summary = {
    "cases" => case_reports.length,
    "passingCases" => case_reports.count { |entry| entry["hasPass"] },
    "completePassingCases" => case_reports.count { |entry| entry["hasCompletePass"] },
    "currentCompletePassingCases" => case_reports.count { |entry| entry["hasCurrentCompletePass"] },
    "missingCompletePass" => case_reports.reject { |entry| entry["hasCompletePass"] }.map { |entry| entry["id"] },
    "missingCurrentCompletePass" => case_reports.reject { |entry| entry["hasCurrentCompletePass"] }.map { |entry| entry["id"] }
  }
  report = {
    "schemaVersion" => 1,
    "suite" => options[:suite],
    "summary" => summary,
    "hosts" => host_reports,
    "cases" => case_reports
  }
  report[options[:suite] == "behavioral" ? "skills" : "targets"] = group_reports

  unless Zstack::EvalEvidenceTree.capture(RUNS_ROOT) == evidence_snapshot
    raise "evidence archive tree changed while coverage was reported"
  end

  if options[:json]
    puts JSON.pretty_generate(report)
  else
    puts "#{options[:suite]} evidence: cases=#{summary.fetch("cases")} " \
         "any-pass=#{summary.fetch("passingCases")} " \
         "complete-pass=#{summary.fetch("completePassingCases")} " \
         "current-complete=#{summary.fetch("currentCompletePassingCases")} " \
         "missing-complete=#{summary.fetch("missingCompletePass").length} " \
         "missing-current=#{summary.fetch("missingCurrentCompletePass").length}"
    group_reports.each do |entry|
      puts format(
        "%-24s any=%d/%d complete=%d/%d current=%d/%d current-hosts=%s",
        entry.fetch(group_key),
        entry.fetch("passingCases"),
        entry.fetch("cases"),
        entry.fetch("completePassingCases"),
        entry.fetch("cases"),
        entry.fetch("currentCompletePassingCases"),
        entry.fetch("cases"),
        entry.fetch("currentCompletePassHostFamilies").empty? ? "none" : entry.fetch("currentCompletePassHostFamilies").join(",")
      )
    end
    host_reports.each do |entry|
      puts format(
        "host:%-19s any=%d/%d complete=%d/%d current=%d/%d",
        entry.fetch("hostFamily"),
        entry.fetch("passingCases"),
        case_reports.length,
        entry.fetch("completePassingCases"),
        case_reports.length,
        entry.fetch("currentCompletePassingCases"),
        case_reports.length
      )
    end
    unless summary.fetch("missingCompletePass").empty?
      puts "missing complete-provenance pass: #{summary.fetch("missingCompletePass").join(", ")}"
    end
    unless summary.fetch("missingCurrentCompletePass").empty?
      puts "missing current-source complete pass: #{summary.fetch("missingCurrentCompletePass").join(", ")}"
    end
  end

  strict_failure = options[:require_complete_pass] && !summary.fetch("missingCompletePass").empty?
  strict_failure ||= options[:require_current_complete_pass] && !summary.fetch("missingCurrentCompletePass").empty?
  options[:required_host_families].uniq.each do |family|
    strict_failure ||= !host_reports.find { |entry| entry.fetch("hostFamily") == family }.fetch("missingCompletePass").empty?
  end
  options[:required_current_host_families].uniq.each do |family|
    strict_failure ||= !host_reports.find { |entry| entry.fetch("hostFamily") == family }.fetch("missingCurrentCompletePass").empty?
  end
  exit 1 if strict_failure
rescue OptionParser::ParseError => e
  warn "ERROR: #{e.message}"
  warn parser
  exit 2
rescue KeyError, StandardError => e
  warn "ERROR: #{e.message}"
  exit 2
end
