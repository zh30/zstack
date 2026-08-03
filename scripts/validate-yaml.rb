#!/usr/bin/env ruby
# Strict YAML syntax and duplicate-key validation for repository manifests and skill frontmatter.

require "yaml"
require_relative "lib/eval_input_file"
require_relative "lib/eval_strict_yaml"

ROOT = File.expand_path("..", __dir__)

ValidationError = Zstack::EvalStrictYaml::ValidationError

captured_document_mode = ARGV.first == "--documents"
if captured_document_mode
  ARGV.shift
  if ARGV.empty? || ARGV.length.odd?
    warn "Usage: ruby scripts/validate-yaml.rb [--documents LABEL PATH ...]"
    exit 2
  end
  yaml_files = ARGV.each_slice(2).map do |source, path|
    if source.empty? || source.match?(/[\0\r\n]/) || path.empty?
      warn "ERROR: captured YAML labels must be non-empty single-line strings and paths must be non-empty"
      exit 2
    end
    [source, path]
  end
  skill_files = []
else
  unless ARGV.empty?
    warn "Usage: ruby scripts/validate-yaml.rb [--documents LABEL PATH ...]"
    exit 2
  end
  yaml_files = [
    File.join(ROOT, "catalog.yaml"),
    File.join(ROOT, "evals", "cases.yaml"),
    File.join(ROOT, "evals", "routing.yaml"),
    *Dir.glob(File.join(ROOT, "hosts", "*.yaml")).sort,
    *Dir.glob(File.join(ROOT, ".github", "*.{yaml,yml}")).sort,
    *Dir.glob(File.join(ROOT, ".github", "workflows", "*.{yaml,yml}")).sort
  ].uniq.map { |path| [path.delete_prefix("#{ROOT}/"), path] }
  skill_files = Dir.glob(File.join(ROOT, "skills", "*", "SKILL.md")).sort
end
errors = []

yaml_files.each do |source, path|
  begin
    data = Zstack::EvalStrictYaml.parse(
      Zstack::EvalInputFile.read(
        path,
        label: source,
        root: captured_document_mode ? nil : ROOT
      ),
      source
    )
    raise ValidationError, "#{path}: YAML document must be a mapping" unless data.is_a?(Hash)
  rescue Errno::ENOENT
    errors << "missing #{source}"
  rescue Psych::Exception, ValidationError, Zstack::EvalInputFile::ReadError => e
    errors << e.message
  end
end

skill_files.each do |path|
  begin
    lines = Zstack::EvalInputFile.read(
      path,
      label: path.delete_prefix("#{ROOT}/"),
      root: ROOT
    ).lines
    raise ValidationError, "#{path}: frontmatter must start on line 1" unless lines.first&.chomp == "---"

    closing_index = (1...lines.length).find { |index| lines[index].chomp == "---" }
    raise ValidationError, "#{path}: frontmatter is not closed" unless closing_index

    source = "#{path.delete_prefix("#{ROOT}/")}#frontmatter"
    data = Zstack::EvalStrictYaml.parse(lines[1...closing_index].join, source)
    raise ValidationError, "#{source}: frontmatter must be a mapping" unless data.is_a?(Hash)
  rescue Psych::Exception, ValidationError, Zstack::EvalInputFile::ReadError => e
    errors << e.message
  end
end

unless errors.empty?
  errors.each { |message| warn "YAML ERROR: #{message}" }
  exit 1
end

if captured_document_mode
  noun = yaml_files.length == 1 ? "file" : "files"
  puts "strict YAML syntax (#{yaml_files.length} captured #{noun})"
else
  puts "strict YAML syntax (#{yaml_files.length} files, #{skill_files.length} frontmatters)"
end
