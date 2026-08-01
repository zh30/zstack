# frozen_string_literal: true

# Private evaluation paths must not reveal semantic case ids to the model.

require "securerandom"

module Zstack
  module EvalPrivatePaths
    TOKEN_PATTERN = /\Acase-[0-9a-f]{32}\z/
    STRATEGY = "random opaque 128-bit tokens for private workspaces, host homes, and Grok prompt transport"

    module_function

    def build_tokens(case_ids)
      raise "case ids must be unique before private tokens are allocated" unless case_ids.uniq.length == case_ids.length

      used = {}
      case_ids.to_h do |id|
        token = nil
        loop do
          token = "case-#{SecureRandom.hex(16)}"
          break unless used.key?(token)
        end
        used[token] = true
        [id, token]
      end
    end

    def token?(value)
      value.is_a?(String) && value.match?(TOKEN_PATTERN)
    end
  end
end
