# frozen_string_literal: true

require "tempfile"
require_relative "eval_output_file"
require_relative "eval_process_supervisor"

module Zstack
  module EvalBoundedCommand
    Result = Struct.new(:stdout, :stderr, :status, :timed_out, :output_limited, keyword_init: true)

    module_function

    def capture(*command, timeout_seconds:, max_output_bytes:, chdir: nil)
      unless !command.empty? && command.all? { |argument| argument.is_a?(String) && !argument.empty? }
        raise ArgumentError, "command must contain only non-empty string arguments"
      end
      unless timeout_seconds.is_a?(Numeric) && timeout_seconds.finite? && timeout_seconds.positive?
        raise ArgumentError, "command timeout must be finite and positive"
      end
      unless max_output_bytes.is_a?(Integer) && max_output_bytes.positive?
        raise ArgumentError, "command output limit must be a positive integer"
      end
      unless chdir.nil? || (chdir.is_a?(String) && !chdir.empty?)
        raise ArgumentError, "command working directory must be a non-empty string"
      end

      stdout_file, stdout_identity = private_tempfile("out")
      stderr_file, stderr_identity = private_tempfile("err")
      output_paths = [stdout_file.path, stderr_file.path]
      spawn_options = {
        in: File::NULL,
        out: stdout_file,
        err: stderr_file,
        pgroup: true,
        rlimit_fsize: max_output_bytes + 1
      }
      spawn_options[:chdir] = chdir if chdir
      started_at = EvalProcessSupervisor.monotonic_time
      pid = Process.spawn(*command, **spawn_options)
      status, timed_out, output_limited = EvalProcessSupervisor.wait(
        pid,
        started_at: started_at,
        timeout_seconds: timeout_seconds,
        output_paths: output_paths,
        max_output_bytes: max_output_bytes
      )
      pid = nil
      stdout_file.close
      stderr_file.close

      stdout = timed_out || output_limited ? "" : read_output(stdout_file.path, max_output_bytes, "command stdout")
      stderr = timed_out || output_limited ? "" : read_output(stderr_file.path, max_output_bytes, "command stderr")
      Result.new(
        stdout: stdout,
        stderr: stderr,
        status: status,
        timed_out: timed_out,
        output_limited: output_limited
      )
    ensure
      EvalProcessSupervisor.terminate_and_reap(pid) if pid
      close_and_unlink(stdout_file, stdout_identity)
      close_and_unlink(stderr_file, stderr_identity)
    end

    def private_tempfile(extension)
      # Tempfile.create returns a plain File without a pathname-based finalizer;
      # cleanup below can therefore preserve a concurrently replaced path.
      file = Tempfile.create(["zstack-command", ".#{extension}"])
      identity = file.stat
      file.chmod(0o600)
      [file, identity]
    rescue StandardError
      close_and_unlink(file, identity)
      raise
    end
    private_class_method :private_tempfile

    def read_output(path, max_output_bytes, label)
      content, error = EvalOutputFile.read_optional(
        path,
        max_bytes: max_output_bytes,
        label: label,
        require_utf8: true
      )
      raise error if error

      content
    end
    private_class_method :read_output

    def close_and_unlink(file, identity)
      return unless file && identity

      file.close unless file.closed?
      current = File.lstat(file.path)
      return unless current.file? && !current.symlink?
      return unless current.dev == identity.dev && current.ino == identity.ino

      File.unlink(file.path)
    rescue IOError, SystemCallError
      nil
    end
    private_class_method :close_and_unlink
  end
end
