# frozen_string_literal: true

require_relative "eval_bounded_command"
require_relative "eval_limits"
require_relative "eval_process_supervisor"

module Zstack
  module EvalHostVersion
    module_function

    def probe(
      executable,
      display_name:,
      timeout_seconds: EvalLimits::VERSION_PROBE_TIMEOUT_SECONDS,
      max_output_bytes: EvalLimits::MAX_VERSION_OUTPUT_BYTES
    )
      unless executable.is_a?(String) && !executable.empty?
        raise ArgumentError, "host executable must be a non-empty string"
      end
      unless display_name.is_a?(String) && !display_name.empty?
        raise ArgumentError, "host display name must be a non-empty string"
      end
      unless timeout_seconds.is_a?(Numeric) && timeout_seconds.finite? && timeout_seconds.positive?
        raise ArgumentError, "version probe timeout must be finite and positive"
      end
      unless max_output_bytes.is_a?(Integer) && max_output_bytes.positive?
        raise ArgumentError, "version probe output limit must be a positive integer"
      end

      result = EvalBoundedCommand.capture(
        executable,
        "--version",
        timeout_seconds: timeout_seconds,
        max_output_bytes: max_output_bytes
      )
      raise "#{display_name} --version timed out after #{timeout_seconds} seconds" if result.timed_out
      raise "#{display_name} --version exceeded #{max_output_bytes} output bytes" if result.output_limited

      unless result.status.success?
        raise "cannot execute #{executable} --version: exit #{EvalProcessSupervisor.exit_status(result.status)}"
      end

      version = result.stdout.strip.lines.first
      raise "#{executable} --version returned no version" if version.nil? || version.empty?

      version
    rescue Errno::ENOENT
      raise "#{display_name} executable not found: #{executable}"
    end
  end
end
