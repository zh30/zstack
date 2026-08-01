#!/usr/bin/env ruby
# Validate evaluation provenance, run-to-artifact mapping, and retained bytes.

require "digest"
require "json"
require "pathname"
require "set"
require "yaml"
require_relative "lib/eval_public_text"

ROOT = File.expand_path("..", __dir__)
RUNS_ROOT = File.join(ROOT, "evals", "runs")
SCHEMA_VERSION = 2
ARCHIVE_MANIFEST_NAME = "archive-manifest.txt"
ARCHIVE_MANIFEST_HEADER = "sha256                                                            bytes  path"
EVAL_PUBLIC_TEXT = Zstack::EvalPublicText

def relative_to_root(path)
  Pathname.new(path).relative_path_from(Pathname.new(ROOT)).to_s
end

def safe_relative_path?(path)
  return false unless path.is_a?(String) && !path.empty?

  candidate = Pathname.new(path)
  clean_path = candidate.cleanpath.to_s
  !candidate.absolute? && clean_path == path && path == path.strip &&
    !path.match?(/[[:cntrl:]]/) && clean_path != "." && clean_path != ".." &&
    !clean_path.start_with?("../")
end

def load_case_ids(relative_path, errors)
  path = File.join(ROOT, relative_path)
  document = YAML.safe_load(File.read(path), permitted_classes: [], aliases: false)
  unless document.is_a?(Hash)
    errors << "#{relative_path}: YAML root must be a mapping"
    return Set.new
  end

  Array(document["cases"]).each_with_object(Set.new) do |entry, ids|
    ids << entry["id"] if entry.is_a?(Hash) && entry["id"].is_a?(String)
  end
rescue Errno::ENOENT, Psych::Exception => e
  errors << "#{relative_path}: cannot load case ids: #{e.message}"
  Set.new
end

def archived_candidates(manifest_path, original_path)
  raw_dir = File.dirname(manifest_path)
  basename = File.basename(original_path)
  phase = File.basename(manifest_path)[/\Aartifact-manifest\.(.+)\.txt\z/, 1]
  candidates = [File.join(raw_dir, original_path)]

  if phase
    candidates << File.join(raw_dir, phase, original_path)
    candidates << File.join(raw_dir, phase, basename)
    extension = File.extname(basename)
    stem = File.basename(basename, extension)
    candidates << File.join(raw_dir, "#{stem}.#{phase}#{extension}")
  end

  candidates.uniq
end

def valid_optional_string?(value)
  value.nil? || (value.is_a?(String) && !value.empty?)
end

errors = []
case_ids_by_suite = {
  "behavioral" => load_case_ids("evals/cases.yaml", errors),
  "routing" => load_case_ids("evals/routing.yaml", errors)
}
run_directories = Dir.glob(File.join(RUNS_ROOT, "*")).select { |path| File.directory?(path) }.sort
metadata_count = 0
metadata_run_count = 0
archive_manifest_count = 0
archive_verified_count = 0
manifest_count = 0
verified_count = 0
inventory_only_count = 0
metadata_artifacts = Hash.new { |directories, directory| directories[directory] = Set.new }
manifest_artifacts = Hash.new { |directories, directory| directories[directory] = Set.new }
manifest_counts = Hash.new(0)

errors << "evals/runs: archive root must not be a symbolic link" if File.symlink?(RUNS_ROOT)
run_directories.each do |run_dir|
  relative_run = relative_to_root(run_dir)
  errors << "#{relative_run}: archive directory must not be a symbolic link" if File.symlink?(run_dir)
  Dir.glob(File.join(run_dir, "**", "*"), File::FNM_DOTMATCH).each do |entry|
    next if %w[. ..].include?(File.basename(entry))
    errors << "#{relative_to_root(entry)}: archive content must not be a symbolic link" if File.symlink?(entry)
  end
  %w[prompts.md summary.md run.json archive-manifest.txt].each do |required_file|
    path = File.join(run_dir, required_file)
    errors << "#{relative_run}: missing #{required_file}" unless File.file?(path)
  end
  errors << "#{relative_run}: missing raw/ directory" unless File.directory?(File.join(run_dir, "raw"))
end

run_directories.each do |run_directory|
  manifest_path = File.join(run_directory, ARCHIVE_MANIFEST_NAME)
  next unless File.file?(manifest_path)

  archive_manifest_count += 1
  relative_manifest = relative_to_root(manifest_path)
  lines = File.readlines(manifest_path, chomp: true)
  unless lines.shift == ARCHIVE_MANIFEST_HEADER
    errors << "#{relative_manifest}: first line must be the canonical archive-manifest header"
  end
  listed_paths = Set.new

  lines.each_with_index do |line, index|
    line_number = index + 2
    match = line.match(/\A([0-9a-f]{64})[[:space:]]+(\d+)[[:space:]]+(.+)\z/)
    unless match
      errors << "#{relative_manifest}:#{line_number}: unrecognized archive-manifest line"
      next
    end
    digest, bytes, archive_path = match.captures
    unless safe_relative_path?(archive_path) && archive_path != ARCHIVE_MANIFEST_NAME
      errors << "#{relative_manifest}:#{line_number}: path must be canonical, stay inside the archive, and exclude the manifest itself"
      next
    end
    if listed_paths.include?(archive_path)
      errors << "#{relative_manifest}:#{line_number}: duplicate archive path: #{archive_path}"
      next
    end
    listed_paths << archive_path

    retained_path = File.join(run_directory, archive_path)
    unless File.file?(retained_path)
      errors << "#{relative_manifest}:#{line_number}: archived file is missing: #{archive_path}"
      next
    end
    content = File.binread(retained_path)
    valid = true
    if content.bytesize != bytes.to_i
      errors << "#{relative_manifest}:#{line_number}: byte count mismatch for #{archive_path} (expected #{bytes}, found #{content.bytesize})"
      valid = false
    end
    if Digest::SHA256.hexdigest(content) != digest
      errors << "#{relative_manifest}:#{line_number}: SHA-256 mismatch for #{archive_path}"
      valid = false
    end
    archive_verified_count += 1 if valid
  end

  archive_files = Dir.glob(File.join(run_directory, "**", "*"), File::FNM_DOTMATCH).select do |path|
    next false if %w[. ..].include?(File.basename(path))
    next false if path == manifest_path
    File.file?(path)
  end.map { |path| Pathname.new(path).relative_path_from(Pathname.new(run_directory)).to_s }.to_set
  (archive_files - listed_paths).each do |archive_path|
    errors << "#{relative_manifest}: archive file is not covered: #{archive_path}"
  end
  (listed_paths - archive_files).each do |archive_path|
    errors << "#{relative_manifest}: manifest entry has no regular file: #{archive_path}"
  end
end

Dir.glob([
  File.join(RUNS_ROOT, "*", "runner-review.json"),
  File.join(RUNS_ROOT, "*", "summary.md")
]).sort.each do |path|
  if EVAL_PUBLIC_TEXT.machine_local_path?(File.read(path))
    errors << "#{relative_to_root(path)}: public review text contains a machine-local path"
  end
end

Dir.glob(File.join(RUNS_ROOT, "*", "run.json")).sort.each do |path|
  metadata_count += 1
  run_directory = File.dirname(path)
  raw_directory = File.join(run_directory, "raw")
  relative_path = relative_to_root(path)

  begin
    data = JSON.parse(File.read(path))
    unless data.is_a?(Hash)
      errors << "#{relative_path}: JSON root must be an object"
      next
    end

    unless data["schemaVersion"] == SCHEMA_VERSION
      errors << "#{relative_path}: schemaVersion must equal #{SCHEMA_VERSION}"
    end
    unless data["archiveDate"].is_a?(String) && data["archiveDate"].match?(/\A\d{4}-\d{2}-\d{2}\z/)
      errors << "#{relative_path}: archiveDate must use YYYY-MM-DD"
    end
    run_directory_date = File.basename(run_directory)[/\A\d{4}-\d{2}-\d{2}/]
    if run_directory_date && data["archiveDate"] != run_directory_date
      errors << "#{relative_path}: archiveDate must match the run directory date #{run_directory_date}"
    end

    suite = data["suite"]
    unless case_ids_by_suite.key?(suite)
      errors << "#{relative_path}: suite must be behavioral or routing"
    end

    host = data["host"]
    unless host.is_a?(Hash) && host["name"].is_a?(String) && !host["name"].empty? &&
           valid_optional_string?(host["version"])
      errors << "#{relative_path}: host must contain a non-empty name and a string or null version"
    end

    provenance = data["provenance"]
    provenance_status = provenance.is_a?(Hash) ? provenance["status"] : nil
    provenance_gaps = provenance.is_a?(Hash) ? provenance["gaps"] : nil
    unless %w[complete partial].include?(provenance_status) && provenance_gaps.is_a?(Array) &&
           provenance_gaps.all? { |gap| gap.is_a?(String) && !gap.empty? }
      errors << "#{relative_path}: provenance requires complete/partial status and string gaps"
    end
    if provenance_status == "complete"
      errors << "#{relative_path}: complete provenance cannot declare gaps" unless provenance_gaps.empty?
      unless host.is_a?(Hash) && host["version"].is_a?(String) && !host["version"].empty?
        errors << "#{relative_path}: complete provenance requires a recorded host version"
      end
    elsif provenance_status == "partial" && provenance_gaps&.empty?
      errors << "#{relative_path}: partial provenance must explain at least one recording gap"
    end

    unless data["runnerIncidents"].is_a?(Array) &&
           data["runnerIncidents"].all? { |item| item.is_a?(String) && !item.empty? }
      errors << "#{relative_path}: runnerIncidents must be an array of non-empty strings"
    end

    runs = data["runs"]
    unless runs.is_a?(Array) && !runs.empty?
      errors << "#{relative_path}: runs must be a non-empty array"
      next
    end
    execution_defaults = data.fetch("executionDefaults", {})
    unless execution_defaults.is_a?(Hash)
      errors << "#{relative_path}: executionDefaults must be an object when present"
      execution_defaults = {}
    end

    run_ids = Set.new
    case_phases = Set.new
    runs.each_with_index do |run, index|
      metadata_run_count += 1
      prefix = "#{relative_path}: runs[#{index}]"
      unless run.is_a?(Hash)
        errors << "#{prefix} must be an object"
        next
      end

      run_id = run["id"]
      unless run_id.is_a?(String) && run_id.match?(/\A[a-z0-9][a-z0-9-]*\z/)
        errors << "#{prefix}.id must be a non-empty kebab-case string"
      else
        errors << "#{prefix}.id is duplicated: #{run_id}" if run_ids.include?(run_id)
        run_ids << run_id
      end

      case_id = run["case"]
      unless case_id.is_a?(String) && case_ids_by_suite.fetch(suite, Set.new).include?(case_id)
        errors << "#{prefix}.case must reference an id in the #{suite || 'selected'} suite"
      end
      phase = run["phase"]
      unless phase.is_a?(String) && !phase.empty?
        errors << "#{prefix}.phase must be a non-empty string"
      end
      if case_id.is_a?(String) && phase.is_a?(String) && !phase.empty?
        case_phase = [case_id, phase]
        errors << "#{prefix} duplicates case/phase #{case_id}/#{phase}" if case_phases.include?(case_phase)
        case_phases << case_phase
      end

      errors << "#{prefix}.grade must be pass or fail" unless %w[pass fail].include?(run["grade"])

      %w[model workspace permissions stopStatus].each do |field|
        field_is_present = run.key?(field) || execution_defaults.key?(field)
        value = run.key?(field) ? run[field] : execution_defaults[field]
        unless field_is_present && valid_optional_string?(value)
          errors << "#{prefix}.#{field} must be a non-empty string or null"
        end
        if provenance_status == "complete" && (!value.is_a?(String) || value.empty?)
          errors << "#{prefix}.#{field} must be recorded for complete provenance"
        end
      end
      %w[webSearch subagents].each do |field|
        field_is_present = run.key?(field) || execution_defaults.key?(field)
        value = run.key?(field) ? run[field] : execution_defaults[field]
        unless field_is_present && ([true, false].include?(value) || value.nil?)
          errors << "#{prefix}.#{field} must be true, false, or null"
        end
        if provenance_status == "complete" && ![true, false].include?(value)
          errors << "#{prefix}.#{field} must be recorded for complete provenance"
        end
      end

      turn_values = %w[maxTurns turns].select do |field|
        run.key?(field) || execution_defaults.key?(field)
      end.map { |field| run.key?(field) ? run[field] : execution_defaults[field] }
      if turn_values.empty? || turn_values.any? { |value| !value.nil? && (!value.is_a?(Integer) || !value.positive?) }
        errors << "#{prefix} must contain maxTurns or turns as a positive integer or null"
      end
      if provenance_status == "complete" && turn_values.none? { |value| value.is_a?(Integer) && value.positive? }
        errors << "#{prefix} must record maxTurns or turns for complete provenance"
      end

      artifacts = run["artifacts"]
      unless artifacts.is_a?(Array) && !artifacts.empty?
        errors << "#{prefix}.artifacts must be a non-empty array"
        next
      end
      seen_artifacts = Set.new
      artifacts.each do |artifact_path|
        unless artifact_path.is_a?(String) && safe_relative_path?(artifact_path) &&
               !File.basename(artifact_path).start_with?("artifact-manifest")
          errors << "#{prefix}.artifacts contains an unsafe or invalid path"
          next
        end
        if seen_artifacts.include?(artifact_path)
          errors << "#{prefix}.artifacts duplicates #{artifact_path}"
          next
        end
        seen_artifacts << artifact_path
        metadata_artifacts[run_directory] << artifact_path
        unless File.file?(File.join(raw_directory, artifact_path))
          errors << "#{prefix}.artifacts references a missing raw file: #{artifact_path}"
        end
      end
    end
  rescue JSON::ParserError => e
    errors << "#{relative_path}: invalid JSON: #{e.message}"
  end
end

Dir.glob(File.join(RUNS_ROOT, "*", "raw", "artifact-manifest*.txt")).sort.each do |manifest_path|
  manifest_count += 1
  run_directory = File.dirname(File.dirname(manifest_path))
  raw_directory = File.dirname(manifest_path)
  manifest_counts[run_directory] += 1
  relative_manifest = relative_to_root(manifest_path)
  lines = File.readlines(manifest_path, chomp: true)
  inventory_only_paths = lines.each_with_object([]) do |line, paths|
    next unless line.start_with?("Unarchived entries are inventory-only:")

    paths.concat(line.split(":", 2).last.split(",").map(&:strip))
  end.reject(&:empty?).to_set
  inventory_only_seen = Set.new
  entry_count = 0

  lines.each_with_index do |line, index|
    next if line.strip.empty?
    next if line.start_with?("sha256 ", "Hash is ", "Hashes are ", "Unarchived entries are inventory-only:")
    next if line.match?(/\A\d+ files?, /)

    digest = nil
    bytes = nil
    artifact_path = nil
    if (match = line.match(/\A([0-9a-f]{64})[[:space:]]+(\d+)[[:space:]]+(.+)\z/))
      digest, bytes, artifact_path = match.captures
    elsif (match = line.match(/\A(\d+)[[:space:]]+([0-9a-f]{64})[[:space:]]+(.+)\z/))
      bytes, digest, artifact_path = match.captures
    else
      errors << "#{relative_manifest}:#{index + 1}: unrecognized manifest line"
      next
    end

    entry_count += 1
    unless safe_relative_path?(artifact_path)
      errors << "#{relative_manifest}:#{index + 1}: artifact path must be canonical, relative, and stay inside raw/: #{artifact_path}"
      next
    end

    archived_path = archived_candidates(manifest_path, artifact_path).find { |candidate| File.file?(candidate) }
    unless archived_path
      if inventory_only_paths.include?(artifact_path)
        inventory_only_count += 1
        inventory_only_seen << artifact_path
      else
        errors << "#{relative_manifest}:#{index + 1}: archived artifact is missing: #{artifact_path}"
      end
      next
    end

    archived_relative = Pathname.new(archived_path).relative_path_from(Pathname.new(raw_directory)).to_s
    if manifest_artifacts[run_directory].include?(archived_relative)
      errors << "#{relative_manifest}:#{index + 1}: retained artifact is listed more than once: #{archived_relative}"
    end
    manifest_artifacts[run_directory] << archived_relative

    content = File.binread(archived_path)
    relative_artifact = relative_to_root(archived_path)
    valid = true
    if content.bytesize != bytes.to_i
      errors << "#{relative_manifest}:#{index + 1}: byte count mismatch for #{relative_artifact} (expected #{bytes}, found #{content.bytesize})"
      valid = false
    end
    actual_digest = Digest::SHA256.hexdigest(content)
    if actual_digest != digest
      errors << "#{relative_manifest}:#{index + 1}: SHA-256 mismatch for #{relative_artifact}"
      valid = false
    end
    verified_count += 1 if valid
  end

  errors << "#{relative_manifest}: manifest has no artifact entries" if entry_count.zero?
  (inventory_only_paths - inventory_only_seen).each do |unused_path|
    errors << "#{relative_manifest}: inventory-only path is not a missing manifest entry: #{unused_path}"
  end
end

run_directories.each do |run_directory|
  relative_run = relative_to_root(run_directory)
  raw_directory = File.join(run_directory, "raw")
  errors << "#{relative_run}: missing artifact manifest" if manifest_counts[run_directory].zero?
  next unless File.directory?(raw_directory)

  raw_artifacts = Dir.glob(File.join(raw_directory, "**", "*")).select do |path|
    File.file?(path) && !File.basename(path).start_with?("artifact-manifest")
  end.map { |path| Pathname.new(path).relative_path_from(Pathname.new(raw_directory)).to_s }.to_set

  (raw_artifacts - manifest_artifacts[run_directory]).each do |artifact_path|
    errors << "#{relative_run}: raw artifact is not covered by a manifest: #{artifact_path}"
  end
  (raw_artifacts - metadata_artifacts[run_directory]).each do |artifact_path|
    errors << "#{relative_run}: raw artifact is not referenced by any metadata run: #{artifact_path}"
  end
  (metadata_artifacts[run_directory] - manifest_artifacts[run_directory]).each do |artifact_path|
    errors << "#{relative_run}: metadata artifact is not covered by a manifest: #{artifact_path}"
  end
end

unless errors.empty?
  errors.each { |message| warn "EVIDENCE ERROR: #{message}" }
  exit 1
end

puts "evidence archives (#{run_directories.length} archives, schema v#{SCHEMA_VERSION}, #{metadata_run_count} runs, #{archive_manifest_count} archive manifests / #{archive_verified_count} files, #{manifest_count} raw manifests / #{verified_count} artifacts, #{inventory_only_count} inventory-only entries)"
