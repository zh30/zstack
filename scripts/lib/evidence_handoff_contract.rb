# frozen_string_literal: true

# Deterministically validates the Markdown Evidence handoff emitted by a skill.
module Zstack
  module EvidenceHandoffContract
    CRITERION = "Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names."
    FIELD_LABELS = [
      "Current decision",
      "Evidence classes",
      "Supported claims",
      "Still unproven",
      "Contradictions / exclusions",
      "Source anchors",
      "Next validation"
    ].freeze
    EVIDENCE_CLASSES = [
      "primary behavior",
      "observed experiment",
      "secondary public",
      "search signal",
      "assumption"
    ].freeze
    MARKDOWN_EXTENSIONS = %w[.md .markdown .txt].freeze

    module_function

    def evaluate(sources)
      tables = Array(sources).flat_map do |source|
        name = source.fetch(:name)
        path = source.fetch(:path)
        next [] unless File.file?(path)

        markdown_tables(File.binread(path).force_encoding(Encoding::UTF_8)).each_with_object([]) do |table, matches|
          matches << table.merge("sourcePath" => name) if handoff_candidate?(table)
        end
      end

      errors = []
      errors << "expected exactly one Evidence handoff table; found #{tables.length}" unless tables.length == 1
      errors.concat(validate_table(tables.first)) if tables.length == 1

      {
        "schemaVersion" => 1,
        "passed" => errors.empty?,
        "candidateTables" => tables.length,
        "sourcePaths" => tables.map { |table| table.fetch("sourcePath") }.uniq.sort,
        "errors" => errors
      }
    rescue ArgumentError => e
      {
        "schemaVersion" => 1,
        "passed" => false,
        "candidateTables" => 0,
        "sourcePaths" => [],
        "errors" => [e.message]
      }
    end

    def review_evidence(result)
      if result.fetch("passed")
        "Mechanical check found one valid Evidence handoff table in #{result.fetch("sourcePaths").join(", ")}."
      else
        "Mechanical check failed: #{result.fetch("errors").join("; ")}"
      end
    end

    def markdown_source?(name)
      MARKDOWN_EXTENSIONS.include?(File.extname(name.to_s).downcase)
    end

    def markdown_tables(content)
      raise ArgumentError, "Evidence handoff source is not valid UTF-8" unless content.valid_encoding?

      lines = content.lines(chomp: true)
      tables = []
      index = 0
      while index < lines.length - 1
        header = parse_row(lines[index])
        separator = parse_row(lines[index + 1])
        unless header && separator && separator.all? { |cell| delimiter_cell?(cell) }
          index += 1
          next
        end

        rows = []
        cursor = index + 2
        while cursor < lines.length
          row = parse_row(lines[cursor])
          break unless row

          rows << row
          cursor += 1
        end
        tables << { "header" => header, "separator" => separator, "rows" => rows }
        index = cursor
      end
      tables
    end

    def parse_row(line)
      stripped = line.strip
      return nil unless stripped.start_with?("|") && stripped.end_with?("|")

      body = stripped[1...-1]
      cells = []
      current = +""
      escaped = false
      body.each_char do |character|
        if escaped
          current << character
          escaped = false
        elsif character == "\\"
          current << character
          escaped = true
        elsif character == "|"
          cells << current.strip
          current = +""
        else
          current << character
        end
      end
      current << "\\" if escaped
      cells << current.strip
      cells
    end

    def delimiter_cell?(cell)
      cell.match?(/\A:?-{3,}:?\z/)
    end

    def handoff_candidate?(table)
      table.fetch("rows").count do |row|
        FIELD_LABELS.include?(plain_label(row.first.to_s))
      end >= 2
    end

    def plain_label(value)
      value.strip
           .gsub(/\A(?:\*\*|__|\*|_|`)+|(?:\*\*|__|\*|_|`)+\z/, "")
           .sub(/\A\[([^\]]+)\]\([^)]*\)\z/, '\\1')
           .sub(/:\z/, "")
           .strip
    end

    def validate_table(table)
      errors = []
      rows = table.fetch("rows")
      all_rows = [table.fetch("header"), table.fetch("separator")] + rows
      column_counts = all_rows.map(&:length).uniq
      errors << "Evidence handoff table must contain exactly two columns" unless column_counts == [2]
      errors << "Evidence handoff header must be exactly Field | Value" unless table.fetch("header") == %w[Field Value]
      errors << "Evidence handoff table must contain exactly seven data rows; found #{rows.length}" unless rows.length == FIELD_LABELS.length

      actual_labels = rows.map { |row| row.first.to_s }
      unless actual_labels == FIELD_LABELS
        errors << "Evidence handoff first-column labels must be the seven exact plain-text tokens in contract order"
      end

      class_rows = rows.select { |row| row.first == "Evidence classes" }
      if class_rows.length == 1 && class_rows.first.length >= 2
        classes = split_evidence_classes(class_rows.first[1])
        if classes.empty? || classes.uniq.length != classes.length || !classes.all? { |name| EVIDENCE_CLASSES.include?(name) }
          errors << "Evidence classes must contain one or more unique canonical class names only"
        end
      end
      errors
    end

    def split_evidence_classes(value)
      value.to_s
           .gsub(/<br\s*\/?\s*>/i, "/")
           .split(/\s*(?:\/|,|;|\band\b)\s*/)
           .map(&:strip)
           .reject(&:empty?)
    end
  end
end
