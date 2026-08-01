#!/usr/bin/env ruby
# Report which current behavioral or routing cases have archived passing evidence.

require "json"
require "optparse"
require "digest"
require "yaml"
require_relative "lib/evidence_handoff_contract"

ROOT = File.expand_path("..", __dir__)
CATALOG_PATH = File.join(ROOT, "catalog.yaml")
CASES_PATH = File.join(ROOT, "evals", "cases.yaml")
ROUTING_PATH = File.join(ROOT, "evals", "routing.yaml")
RUNS_ROOT = File.join(ROOT, "evals", "runs")
SUPPORTED_HOST_FAMILIES = %w[claude codex grok].freeze
SUPPORTED_SUITES = %w[behavioral routing].freeze
EVIDENCE_HANDOFF_CONTRACT = Zstack::EvidenceHandoffContract
CODEX_AMBIENT_CONTEXT_KEYS = %w[
  CODEX_INTERNAL_ORIGINATOR_OVERRIDE
  CODEX_PERMISSION_PROFILE
  CODEX_THREAD_ID
].freeze

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

def host_family(name)
  case name.to_s.downcase
  when /codex/ then "codex"
  when /claude/ then "claude"
  when /grok/ then "grok"
  else name.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|\-\z/, "")
  end
end

def execution_contract_current?(archive_data)
  return true unless host_family(archive_data.dig("host", "name")) == "codex"

  defaults = archive_data["executionDefaults"]
  return false unless defaults.is_a?(Hash)
  return false unless defaults["isolatedHostHome"] == true
  return false unless defaults["ambientDesktopContextDisabled"] == CODEX_AMBIENT_CONTEXT_KEYS
  return false unless defaults["timeoutSecondsPerCase"].is_a?(Integer) && defaults["timeoutSecondsPerCase"].positive?

  incidents = Array(archive_data["runnerIncidents"])
  incidents.none? { |incident| incident.match?(/MCP OAuth invalid_grant|installed-skill context-budget warning/) }
end

def load_frontmatter(path)
  content = File.read(path)
  match = content.match(/\A---\r?\n(?<yaml>.*?)\r?\n---(?:\r?\n|\z)/m)
  raise "#{path.delete_prefix("#{ROOT}/")}: missing closed frontmatter" unless match

  data = YAML.safe_load(match[:yaml], permitted_classes: [], permitted_symbols: [], aliases: false, filename: path)
  raise "#{path.delete_prefix("#{ROOT}/")}: frontmatter must be a mapping" unless data.is_a?(Hash)

  data
end

def tree_signature(path)
  return nil unless File.directory?(path) && !File.symlink?(path)

  entries = Dir.glob(File.join(path, "**", "*"), File::FNM_DOTMATCH).reject do |entry|
    %w[. ..].include?(File.basename(entry))
  end.sort.map do |entry|
    return nil if File.symlink?(entry) || (!File.file?(entry) && !File.directory?(entry))
    next if File.directory?(entry)

    relative = entry.delete_prefix("#{path}/")
    [relative, File.size(entry), Digest::SHA256.file(entry).hexdigest]
  end.compact
  return nil if entries.empty?

  Digest::SHA256.hexdigest(entries.map { |entry| entry.join("\0") }.join("\n"))
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

def behavioral_source_current?(archive, run, entry, current_skill_signatures)
  id = entry.fetch("id")
  skill = entry.fetch("skill")
  snapshot = File.join(archive, "raw", "skill-snapshots", skill)
  return false unless tree_signature(snapshot) == current_skill_signatures.fetch(skill)

  prompt_path = File.join(archive, "raw", "prompts", "#{id}.txt")
  return false unless File.file?(prompt_path) && File.read(prompt_path).end_with?("User request:\n#{entry.fetch("prompt")}\n")

  review_path = File.join(archive, "runner-review.json")
  return false unless File.file?(review_path)
  review = JSON.parse(File.read(review_path))
  reviewed = Array(review["cases"]).find { |candidate| candidate["id"] == run["case"] }
  return false unless reviewed

  mechanical = run["evidenceHandoffContract"]
  return false unless mechanical.is_a?(Hash) && mechanical["schemaVersion"] == 1 && mechanical["passed"] == true
  mechanical_review = Array(reviewed["criteria"]).find do |criterion|
    criterion["expectation"] == "present" && criterion["criterion"] == EVIDENCE_HANDOFF_CONTRACT::CRITERION
  end
  return false unless mechanical_review && mechanical_review["observed"] == true

  expected = Array(entry["must"]).map { |criterion| ["present", criterion] } +
             Array(entry["must_not"]).map { |criterion| ["absent", criterion] }
  observed = Array(reviewed["criteria"]).map { |criterion| [criterion["expectation"], criterion["criterion"]] }
  observed == expected
rescue Errno::ENOENT, JSON::ParserError, KeyError
  false
end

def routing_source_current?(archive, run, entry, candidate_descriptions)
  candidates_path = File.join(archive, "raw", "candidate-descriptions.txt")
  return false unless File.file?(candidates_path) && File.read(candidates_path) == candidate_descriptions

  results_path = File.join(archive, "runner-results.json")
  return false unless File.file?(results_path)
  archived_result = Array(JSON.parse(File.read(results_path))).find { |candidate| candidate["id"] == run["case"] }
  return false unless archived_result && archived_result["expected"] == entry.fetch("expected_skill")

  prompt_path = File.join(archive, "raw", "prompts", "#{entry.fetch("id")}.txt")
  return false unless File.file?(prompt_path)
  prompt = File.read(prompt_path)
  user_prompt = entry.fetch("prompt")
  prompt.include?("\nUser request:\n#{user_prompt}\n\nReply with exactly two lines:") ||
    prompt.include?("\n用户请求：\n#{user_prompt}\n\n严格只回复两行：")
rescue Errno::ENOENT, JSON::ParserError, KeyError
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
  Dir.glob(File.join(RUNS_ROOT, "*", "run.json")).sort.each do |path|
    data = JSON.parse(File.read(path))
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
                         behavioral_source_current?(archive, run, current_entry, current_skill_signatures)
                       else
                         routing_source_current?(archive, run, current_entry, candidate_descriptions)
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
  rescue JSON::ParserError => e
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
