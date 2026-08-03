# frozen_string_literal: true

require "date"

module Zstack
  module EvalArchiveName
    DATE_PATTERN = /\A\d{4}-\d{2}-\d{2}\z/
    PUBLISHED_PATTERN = /\A\d{4}-\d{2}-\d{2}(?:-[a-z0-9][a-z0-9-]*)?\z/
    CANDIDATE_PATTERN = /\A\d{4}-\d{2}-\d{2}-[a-z0-9][a-z0-9-]*\z/

    def self.valid_date?(value)
      return false unless value.is_a?(String) && value.match?(DATE_PATTERN)

      Date.iso8601(value).iso8601 == value
    rescue ArgumentError
      false
    end

    def self.valid_published?(name)
      name.is_a?(String) && name.match?(PUBLISHED_PATTERN) && valid_date?(name[0, 10])
    end

    def self.valid_candidate?(name)
      name.is_a?(String) && name.match?(CANDIDATE_PATTERN) && valid_date?(name[0, 10])
    end
  end
end
