# frozen_string_literal: true

require_relative "eval_limits"
require "tempfile"

module Zstack
  module EvalPromptWriter
    module_function

    def anonymous_input(
      content,
      max_bytes: EvalLimits::MAX_PROMPT_BYTES,
      label: "prompt input"
    )
      raise ArgumentError, "#{label} must be a string" unless content.is_a?(String)
      unless max_bytes.is_a?(Integer) && max_bytes.positive?
        raise ArgumentError, "#{label} byte limit must be a positive integer"
      end
      utf8_content = content.dup.force_encoding(Encoding::UTF_8)
      raise ArgumentError, "#{label} must be valid UTF-8" unless utf8_content.valid_encoding?
      raise ArgumentError, "#{label} exceeds #{max_bytes} bytes" if content.bytesize > max_bytes

      input = Tempfile.new(["zstack-eval-prompt-", ".txt"])
      input.binmode
      input.chmod(0o600)
      input.write(content)
      input.flush
      input.fsync
      input.rewind
      input.unlink
      stat = input.stat
      unless stat.file? && stat.uid == Process.uid && stat.nlink.zero? &&
             (stat.mode & 0o077).zero? && stat.size == content.bytesize
        raise "#{label} anonymous descriptor is unsafe"
      end
      input
    rescue SystemCallError, IOError => e
      input&.close!
      raise "#{label} could not be prepared safely: #{e.class}"
    rescue StandardError
      input&.close!
      raise
    end

    class Budget
      attr_reader :total_bytes

      def initialize(
        max_bytes_per_prompt: EvalLimits::MAX_PROMPT_BYTES,
        max_bytes_per_run: EvalLimits::MAX_RUN_PROMPT_BYTES
      )
        unless max_bytes_per_prompt.is_a?(Integer) && max_bytes_per_prompt.positive?
          raise ArgumentError, "per-prompt byte limit must be a positive integer"
        end
        unless max_bytes_per_run.is_a?(Integer) && max_bytes_per_run.positive?
          raise ArgumentError, "run prompt byte limit must be a positive integer"
        end

        @max_bytes_per_prompt = max_bytes_per_prompt
        @max_bytes_per_run = max_bytes_per_run
        @total_bytes = 0
      end

      def write(path, content)
        raise ArgumentError, "prompt must be a string" unless content.is_a?(String)

        utf8_content = content.dup.force_encoding(Encoding::UTF_8)
        raise ArgumentError, "prompt must be valid UTF-8" unless utf8_content.valid_encoding?

        bytes = content.bytesize
        raise "prompt exceeds #{@max_bytes_per_prompt} bytes" if bytes > @max_bytes_per_prompt
        if @total_bytes + bytes > @max_bytes_per_run
          raise "prompt run exceeds #{@max_bytes_per_run} total bytes"
        end

        created_stat = nil
        flags = File::WRONLY | File::CREAT | File::EXCL
        File.open(path, flags, 0o600) do |file|
          created_stat = file.stat
          file.write(content)
          file.flush
          file.fsync
        end
        @total_bytes += bytes
        bytes
      rescue SystemCallError, IOError => e
        remove_created_target(path, created_stat)
        raise "prompt could not be written safely: #{e.class}"
      end

      private

      def remove_created_target(path, created_stat)
        return unless created_stat

        current = File.lstat(path)
        return unless current.file? && !current.symlink?
        return unless current.dev == created_stat.dev && current.ino == created_stat.ino

        File.unlink(path)
      rescue Errno::ENOENT, Errno::EACCES, Errno::EPERM
        nil
      end
    end
  end
end
