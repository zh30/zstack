# frozen_string_literal: true

require_relative "eval_bounded_command"
require_relative "eval_limits"
require_relative "eval_process_supervisor"

module Zstack
  module EvalGitWorkspace
    module_function

    def prepare(
      workspace,
      git_executable: "git",
      timeout_seconds: EvalLimits::WORKSPACE_INIT_TIMEOUT_SECONDS,
      max_output_bytes: EvalLimits::MAX_WORKSPACE_INIT_OUTPUT_BYTES
    )
      unless workspace.is_a?(String) && workspace.start_with?(File::SEPARATOR)
        raise ArgumentError, "git workspace must be an absolute path"
      end
      unless git_executable.is_a?(String) && !git_executable.empty?
        raise ArgumentError, "git executable must be a non-empty string"
      end

      before = File.lstat(workspace)
      unless before.directory? && !before.symlink?
        raise "git workspace must be a real directory"
      end
      git_directory = File.join(workspace, ".git")
      if File.exist?(git_directory) || File.symlink?(git_directory)
        raise "git workspace already contains .git"
      end

      begin
        result = EvalBoundedCommand.capture(
          git_executable,
          "init",
          "-q",
          "--template=",
          workspace,
          timeout_seconds: timeout_seconds,
          max_output_bytes: max_output_bytes
        )
      rescue Errno::ENOENT
        raise "git executable not found: #{git_executable}"
      end
      if result.timed_out
        raise "git init timed out after #{timeout_seconds} seconds"
      end
      if result.output_limited
        raise "git init exceeded #{max_output_bytes} output bytes"
      end
      unless result.status.success?
        detail = [result.stdout, result.stderr].reject(&:empty?).join("\n").strip
        suffix = detail.empty? ? "exit #{EvalProcessSupervisor.exit_status(result.status)}" : detail
        raise "git init failed: #{suffix}"
      end

      after = File.lstat(workspace)
      unless after.directory? && !after.symlink? && before.dev == after.dev && before.ino == after.ino
        raise "git workspace changed identity during initialization"
      end
      git_stat = File.lstat(git_directory)
      raise "git init did not create a real .git directory" unless git_stat.directory? && !git_stat.symlink?
      true
    end
  end
end
