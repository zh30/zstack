# frozen_string_literal: true

require_relative "eval_limits"

module Zstack
  module EvalIdentifier
    PATTERN = /\A[a-z0-9][a-z0-9-]*\z/

    module_function

    def validate!(value, label:)
      valid = value.is_a?(String) && value.length.between?(1, EvalLimits::MAX_IDENTIFIER_CHARACTERS) &&
              value.match?(PATTERN)
      unless valid
        raise "#{label} must be a kebab-case string of at most #{EvalLimits::MAX_IDENTIFIER_CHARACTERS} characters"
      end

      value
    end

    def validate_unique_entries!(entries, label:)
      raise "#{label} must be an array" unless entries.is_a?(Array)
      raise "#{label} entries must be mappings" unless entries.all? { |entry| entry.is_a?(Hash) }

      ids = entries.map { |entry| validate!(entry["id"], label: "#{label} id") }
      duplicate = ids.group_by(&:itself).find { |_id, matches| matches.length > 1 }&.first
      raise "#{label} contains duplicate id: #{duplicate}" if duplicate

      ids
    end
  end
end
