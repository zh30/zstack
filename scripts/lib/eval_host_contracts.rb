# frozen_string_literal: true

# Shared immutable host inputs and runner-side structured-result parsing.
# Archivers intentionally keep independent invocation and raw-result checks.

require "json"

module Zstack
  module EvalHostContracts
    GROK_FINAL_MARKER = "ZSTACK_FINAL_RESPONSE_V1".freeze
    GROK_SYSTEM_PROMPTS = {
      "behavioral" => "Execute one isolated zstack behavioral evaluation. Follow only the user prompt and the exact skill snapshot it names. Do not inspect other skills, rules, memories, evaluation files, or user configuration. Use only allowed tools and workspace paths. Use tools silently. Begin the complete final answer with the exact standalone line #{GROK_FINAL_MARKER}; emit that marker exactly once and put no tool-use narration after it.",
      "routing" => "Execute one isolated zstack description-routing evaluation. Follow only the exact user prompt. Do not inspect files, skills, rules, memories, evaluation data, or user configuration. Do not use tools. Begin the required final two-line answer with the exact standalone line #{GROK_FINAL_MARKER}; emit that marker exactly once and put no setup narration after it."
    }.transform_values(&:freeze).freeze

    GROK_ISOLATED_CONFIG = <<~TOML.freeze
      [plugins]
      enabled = []

      [compat.claude]
      skills = false
      rules = false
      agents = false
      mcps = false
      hooks = false
      sessions = false

      [compat.cursor]
      skills = false
      rules = false
      agents = false
      mcps = false
      hooks = false
      sessions = false

      [compat.codex]
      sessions = false
    TOML

    module_function

    def grok_system_prompt(suite)
      GROK_SYSTEM_PROMPTS.fetch(suite)
    end

    def claude_error_category(data, completed)
      return nil if completed
      return "incomplete-result" unless data["is_error"] == true

      status = data["api_error_status"]
      message = data["result"].to_s.downcase
      return "model-unavailable" if message.include?("selected model") || (status == 404 && message.include?("model"))
      return "authentication" if [401, 403].include?(status)
      return "billing" if status == 402 || message.match?(/\b(?:billing|credit)\b/)
      return "rate-limit" if status == 429 || message.match?(/\brate[ -]?limit/)
      return "timeout" if message.include?("timeout") || message.include?("timed out")
      return "provider-error" if status.is_a?(Integer) && status.between?(500, 599)
      return "invalid-request" if status == 400

      "api-error"
    end

    def claude_result(path)
      data = JSON.parse(File.read(path))
      raise "Claude JSON result must be an object" unless data.is_a?(Hash)

      response = data["result"]
      models = data.fetch("modelUsage", {})
      models = {} unless models.is_a?(Hash)
      permission_denials = data.fetch("permission_denials", [])
      permission_denials = [] unless permission_denials.is_a?(Array)
      completed = data["type"] == "result" && data["subtype"] == "success" && data["is_error"] == false &&
                  response.is_a?(String) && !response.strip.empty? && !models.empty?
      api_error_status = data["api_error_status"]
      api_error_status = nil unless api_error_status.is_a?(Integer) && api_error_status.between?(100, 599)
      {
        "completed" => completed,
        "response" => response,
        "isError" => data["is_error"],
        "subtype" => data["subtype"],
        "apiErrorStatus" => api_error_status,
        "errorCategory" => claude_error_category(data, completed),
        "actualModels" => models.keys.sort,
        "numTurns" => data["num_turns"],
        "stopReason" => data["stop_reason"],
        "terminalReason" => data["terminal_reason"],
        "totalCostUsd" => data["total_cost_usd"],
        "permissionDenials" => permission_denials.length,
        "parseError" => nil
      }
    rescue Errno::ENOENT, JSON::ParserError, RuntimeError => e
      {
        "completed" => false,
        "response" => nil,
        "apiErrorStatus" => nil,
        "errorCategory" => "result-record-invalid",
        "actualModels" => [],
        "parseError" => e.message
      }
    end

    def grok_api_error_status(data)
      return nil unless data["type"] == "error"

      message = data["message"].to_s
      match = message.match(/\b(?:bad request|unauthorized|forbidden|payment required|not found|too many requests|internal server error|bad gateway|service unavailable|gateway timeout)\s*\((\d{3})\)\s+from\b/i) ||
              message.match(/\bHTTP(?:\/\d(?:\.\d)?)?\s+(\d{3})\b/i) ||
              message.match(/\bstatus(?:\s+code)?[=: ]+(\d{3})\b/i)
      status = match && Integer(match[1], 10)
      status if status&.between?(100, 599)
    end

    def grok_error_category(data, completed, final_boundary_error = nil, api_error_status = grok_api_error_status(data))
      return nil if completed
      return "final-boundary-invalid" if final_boundary_error
      return "incomplete-result" unless data["type"] == "error"

      message = data["message"].to_s.downcase
      return "model-unavailable" if message.include?("selected model") ||
                                    (api_error_status == 404 && message.include?("model"))
      return "authentication" if [401, 403].include?(api_error_status) ||
                                 message.match?(/\b(?:not authenticated|no auth context|invalid or expired credentials)\b/)
      return "billing" if api_error_status == 402 || message.match?(/\b(?:billing|credit)\b/)
      return "rate-limit" if api_error_status == 429 || message.match?(/\brate[ -]?limit/)
      return "timeout" if message.include?("timeout") || message.include?("timed out")
      return "provider-error" if api_error_status.is_a?(Integer) && api_error_status.between?(500, 599)
      return "invalid-request" if api_error_status == 400

      "api-error"
    end

    def grok_result(path)
      data = JSON.parse(File.read(path))
      raise "Grok JSON result must be an object" unless data.is_a?(Hash)

      raw_response = data["text"]
      response = nil
      prefinal_narration_bytes = nil
      final_boundary_error = nil
      if raw_response.is_a?(String)
        matches = raw_response.to_enum(:scan, /^#{Regexp.escape(GROK_FINAL_MARKER)}\r?$/).map { Regexp.last_match }
        if matches.length == 1
          marker = matches.fetch(0)
          response = raw_response[marker.end(0)..]&.sub(/\A\r?\n/, "")
          prefinal_narration_bytes = raw_response[0...marker.begin(0)].to_s.bytesize
          if response.nil? || response.strip.empty?
            response = nil
            final_boundary_error = "empty-final-response"
          end
        else
          final_boundary_error = matches.empty? ? "missing-final-marker" : "duplicate-final-marker"
        end
      elsif data["type"] != "error"
        final_boundary_error = "missing-final-text"
      end
      models = data.fetch("modelUsage", {})
      models = {} unless models.is_a?(Hash)
      turns = data["num_turns"]
      stop_reason = data["stopReason"]
      is_error = data["type"] == "error"
      completed = !is_error && response.is_a?(String) && !response.strip.empty? && !models.empty? &&
                  final_boundary_error.nil? && turns.is_a?(Integer) && turns.positive? && stop_reason == "end_turn"
      api_error_status = grok_api_error_status(data)
      {
        "completed" => completed,
        "response" => response,
        "apiErrorStatus" => api_error_status,
        "errorCategory" => grok_error_category(data, completed, final_boundary_error, api_error_status),
        "prefinalNarrationBytes" => prefinal_narration_bytes,
        "finalBoundaryError" => final_boundary_error,
        "isError" => is_error,
        "errorType" => data["type"],
        "actualModels" => models.keys.sort,
        "numTurns" => turns,
        "stopReason" => stop_reason,
        "totalCostUsd" => data["total_cost_usd"],
        "tokenUsage" => data["usage"],
        "parseError" => nil
      }
    rescue Errno::ENOENT, JSON::ParserError, RuntimeError => e
      {
        "completed" => false,
        "response" => nil,
        "apiErrorStatus" => nil,
        "errorCategory" => "result-record-invalid",
        "prefinalNarrationBytes" => nil,
        "finalBoundaryError" => nil,
        "actualModels" => [],
        "parseError" => e.message
      }
    end
  end
end
