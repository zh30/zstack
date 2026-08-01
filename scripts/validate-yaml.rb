#!/usr/bin/env ruby
# Strict YAML syntax and duplicate-key validation for repository manifests and skill frontmatter.

require "yaml"

ROOT = File.expand_path("..", __dir__)

class ValidationError < StandardError; end

def check_duplicate_keys(node, source)
  case node
  when Psych::Nodes::Mapping
    seen = {}
    node.children.each_slice(2) do |key_node, value_node|
      if key_node.is_a?(Psych::Nodes::Scalar)
        key = key_node.value
        if seen.key?(key)
          raise ValidationError,
                "#{source}:#{key_node.start_line + 1}: duplicate key #{key.inspect}"
        end
        seen[key] = true
      end
      check_duplicate_keys(key_node, source)
      check_duplicate_keys(value_node, source)
    end
  when Psych::Nodes::Stream, Psych::Nodes::Document, Psych::Nodes::Sequence
    node.children.each { |child| check_duplicate_keys(child, source) }
  end
end

def parse_yaml(text, source)
  syntax_tree = Psych.parse_stream(text, source)
  check_duplicate_keys(syntax_tree, source)
  YAML.safe_load(
    text,
    permitted_classes: [],
    permitted_symbols: [],
    aliases: false,
    filename: source
  )
end

yaml_files = [
  File.join(ROOT, "catalog.yaml"),
  File.join(ROOT, "evals", "cases.yaml"),
  File.join(ROOT, "evals", "routing.yaml"),
  *Dir.glob(File.join(ROOT, "hosts", "*.yaml")).sort,
  *Dir.glob(File.join(ROOT, ".github", "*.{yaml,yml}")).sort,
  *Dir.glob(File.join(ROOT, ".github", "workflows", "*.{yaml,yml}")).sort
].uniq
skill_files = Dir.glob(File.join(ROOT, "skills", "*", "SKILL.md")).sort
errors = []

yaml_files.each do |path|
  source = path.delete_prefix("#{ROOT}/")
  begin
    data = parse_yaml(File.read(path), source)
    raise ValidationError, "#{path}: YAML document must be a mapping" unless data.is_a?(Hash)
  rescue Errno::ENOENT
    errors << "missing #{source}"
  rescue Psych::Exception, ValidationError => e
    errors << e.message
  end
end

skill_files.each do |path|
  begin
    lines = File.readlines(path)
    raise ValidationError, "#{path}: frontmatter must start on line 1" unless lines.first&.chomp == "---"

    closing_index = (1...lines.length).find { |index| lines[index].chomp == "---" }
    raise ValidationError, "#{path}: frontmatter is not closed" unless closing_index

    source = "#{path.delete_prefix("#{ROOT}/")}#frontmatter"
    data = parse_yaml(lines[1...closing_index].join, source)
    raise ValidationError, "#{source}: frontmatter must be a mapping" unless data.is_a?(Hash)
  rescue Psych::Exception, ValidationError => e
    errors << e.message
  end
end

unless errors.empty?
  errors.each { |message| warn "YAML ERROR: #{message}" }
  exit 1
end

puts "strict YAML syntax (#{yaml_files.length} files, #{skill_files.length} frontmatters)"
