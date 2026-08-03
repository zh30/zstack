# frozen_string_literal: true

require "find"
require "digest"
require_relative "eval_limits"
require_relative "eval_output_file"
require_relative "eval_skill_snapshot"

module Zstack
  module EvalWorkspaceWatchdog
    ALLOWED_TOP_LEVEL = %w[.git .zstack-skill artifacts].freeze
    PromptState = Struct.new(:bytes, :sha256, keyword_init: true)

    module_function

    def artifact_error(workspace, retained_files:, retained_bytes:, copied_skill: nil, copied_skill_state: nil, host_home: nil)
      baseline = baseline_error(
        workspace,
        allowed_top_level: ALLOWED_TOP_LEVEL,
        copied_skill: copied_skill,
        copied_skill_state: copied_skill_state,
        host_home: host_home
      )
      return baseline if baseline

      artifact_tree_error(workspace, retained_files: retained_files, retained_bytes: retained_bytes)
    end

    def baseline_error(workspace, allowed_top_level:, copied_skill: nil, copied_skill_state: nil, host_home: nil)
      workspace_stat = File.lstat(workspace)
      unless workspace_stat.directory? && !workspace_stat.symlink? && workspace_stat.uid == Process.uid
        return "case workspace must remain a real directory owned by the current user"
      end

      top_level_entries = 0
      Dir.each_child(workspace) do |name|
        top_level_entries += 1
        return "case wrote outside its allowed workspace layout" unless allowed_top_level.include?(name)
        return "workspace has unexpected top-level entries" if top_level_entries > allowed_top_level.length
      end

      baseline_error = bounded_tree_error(
        File.join(workspace, ".git"),
        label: "workspace Git directory",
        max_files: EvalLimits::MAX_RUNTIME_GIT_FILES,
        max_entries: EvalLimits::MAX_RUNTIME_GIT_TREE_ENTRIES,
        max_bytes: EvalLimits::MAX_RUNTIME_GIT_BYTES
      )
      return baseline_error if baseline_error

      if copied_skill
        skill_errors = EvalLimits.skill_package_errors(copied_skill)
        return "copied skill exceeded its runtime bounds: #{skill_errors.first}" unless skill_errors.empty?
        if copied_skill_state
          skill_error = EvalSkillSnapshot.validation_error(copied_skill, copied_skill_state)
          return skill_error if skill_error
        end
      end
      if host_home
        home_error = bounded_tree_error(
          host_home,
          label: "isolated host home",
          max_files: EvalLimits::MAX_RUNTIME_HOST_HOME_FILES,
          max_entries: EvalLimits::MAX_RUNTIME_HOST_HOME_TREE_ENTRIES,
          max_bytes: EvalLimits::MAX_RUNTIME_HOST_HOME_BYTES
        )
        return home_error if home_error
      end
      nil
    rescue SystemCallError => e
      "workspace could not be monitored safely: #{e.class}"
    end

    def capture_prompt_state(path)
      content, error = EvalOutputFile.read_optional(
        path,
        max_bytes: EvalLimits::MAX_PROMPT_BYTES,
        label: "private prompt"
      )
      raise error if error

      PromptState.new(bytes: content.bytesize, sha256: Digest::SHA256.hexdigest(content)).freeze
    end

    def shared_root_error(workspace_root, workspace_specs:, prompt_states: {})
      root = File.expand_path(workspace_root)
      root_stat = File.lstat(root)
      unless root_stat.directory? && !root_stat.symlink? && root_stat.uid == Process.uid && (root_stat.mode & 0o077).zero?
        return "shared workspace root must remain an owner-private real directory"
      end

      expected_top_level = []
      home_groups = {}
      workspace_specs.each do |spec|
        workspace = File.expand_path(spec.fetch(:workspace))
        return "case workspace escaped its shared root" unless File.dirname(workspace) == root

        expected_top_level << File.basename(workspace)
        host_home = spec[:host_home]
        next unless host_home

        home = File.expand_path(host_home)
        container = File.dirname(home)
        return "isolated host home escaped its shared root" unless File.dirname(container) == root

        expected_top_level << File.basename(container)
        (home_groups[container] ||= []) << File.basename(home)
      end

      unless prompt_states.empty?
        prompt_directories = prompt_states.keys.map { |path| File.dirname(File.expand_path(path)) }.uniq
        return "private prompts must share one directory" unless prompt_directories.length == 1

        prompt_directory = prompt_directories.fetch(0)
        return "private prompt directory escaped its shared root" unless File.dirname(prompt_directory) == root

        expected_top_level << File.basename(prompt_directory)
      end

      actual_top_level = Dir.children(root).sort
      unless actual_top_level == expected_top_level.uniq.sort
        return "shared workspace root contains unexpected or missing entries"
      end

      workspace_specs.each do |spec|
        error = baseline_error(
          spec.fetch(:workspace),
          allowed_top_level: spec.fetch(:allowed_top_level),
          copied_skill: spec[:copied_skill],
          copied_skill_state: spec[:copied_skill_state],
          host_home: spec[:host_home]
        )
        return error if error
      end

      home_groups.each do |container, expected_names|
        error = exact_directory_entries_error(
          container,
          expected_names,
          label: "isolated host-home container"
        )
        return error if error
      end

      private_prompt_error(prompt_states)
    rescue SystemCallError => e
      "shared workspace root could not be monitored safely: #{e.class}"
    end

    def artifact_tree_error(workspace, retained_files:, retained_bytes:)
      artifact_root = File.join(workspace, "artifacts")
      root_stat = File.lstat(artifact_root)
      unless root_stat.directory? && !root_stat.symlink? && root_stat.uid == Process.uid
        return "workspace output root must be a real directory owned by the current user"
      end

      entries = 0
      files = retained_files
      bytes = retained_bytes
      Find.find(artifact_root) do |path|
        next if path == artifact_root

        entries += 1
        if entries > EvalLimits::MAX_ARTIFACT_TREE_ENTRIES
          return "workspace output has more than #{EvalLimits::MAX_ARTIFACT_TREE_ENTRIES} tree entries"
        end
        stat = File.lstat(path)
        return "workspace output contains a symbolic link" if stat.symlink?
        if stat.file?
          return "workspace output contains a file not owned by the current user" unless stat.uid == Process.uid
          return "workspace output contains a multiply linked file" unless stat.nlink == 1
          return "artifact file exceeds #{EvalLimits::MAX_RETAINED_FILE_BYTES} bytes" if stat.size > EvalLimits::MAX_RETAINED_FILE_BYTES

          files += 1
          bytes += stat.size
          if files > EvalLimits::MAX_RUN_ARTIFACT_FILES
            return "artifact run exceeds #{EvalLimits::MAX_RUN_ARTIFACT_FILES} retained files"
          end
          if bytes > EvalLimits::MAX_RUN_ARTIFACT_BYTES
            return "artifact run exceeds #{EvalLimits::MAX_RUN_ARTIFACT_BYTES} retained bytes"
          end
        elsif stat.directory?
          return "workspace output contains a directory not owned by the current user" unless stat.uid == Process.uid
        else
          return "workspace output contains a non-regular entry"
        end
      end
      nil
    rescue SystemCallError => e
      "artifact workspace could not be monitored safely: #{e.class}"
    end
    private_class_method :artifact_tree_error

    def bounded_tree_error(root, label:, max_files:, max_entries:, max_bytes:)
      stat = File.lstat(root)
      unless stat.directory? && !stat.symlink? && stat.uid == Process.uid
        return "#{label} must remain a real directory owned by the current user"
      end

      files = 0
      entries = 0
      bytes = 0
      Find.find(root) do |path|
        next if path == root

        entries += 1
        return "#{label} exceeds #{max_entries} tree entries" if entries > max_entries

        child = File.lstat(path)
        return "#{label} contains a symbolic link" if child.symlink?
        if child.file?
          return "#{label} contains a file not owned by the current user" unless child.uid == Process.uid
          return "#{label} contains a multiply linked file" unless child.nlink == 1
          files += 1
          bytes += child.size
          return "#{label} exceeds #{max_files} files" if files > max_files
          return "#{label} exceeds #{max_bytes} bytes" if bytes > max_bytes
          if child.size > EvalLimits::MAX_RETAINED_FILE_BYTES
            return "#{label} file exceeds #{EvalLimits::MAX_RETAINED_FILE_BYTES} bytes"
          end
        elsif child.directory?
          return "#{label} contains a directory not owned by the current user" unless child.uid == Process.uid
        else
          return "#{label} contains a non-regular entry"
        end
      end
      nil
    end
    private_class_method :bounded_tree_error

    def exact_directory_entries_error(directory, expected_names, label:)
      stat = File.lstat(directory)
      unless stat.directory? && !stat.symlink? && stat.uid == Process.uid
        return "#{label} must remain a real directory owned by the current user"
      end
      return "#{label} contains unexpected or missing entries" unless Dir.children(directory).sort == expected_names.uniq.sort

      nil
    end
    private_class_method :exact_directory_entries_error

    def private_prompt_error(prompt_states)
      return nil if prompt_states.empty?

      directory = File.dirname(File.expand_path(prompt_states.keys.fetch(0)))
      error = exact_directory_entries_error(
        directory,
        prompt_states.keys.map { |path| File.basename(path) },
        label: "private prompt directory"
      )
      return error if error

      total_bytes = 0
      prompt_states.each do |path, expected|
        content, read_error = EvalOutputFile.read_optional(
          path,
          max_bytes: EvalLimits::MAX_PROMPT_BYTES,
          label: "private prompt"
        )
        return read_error if read_error

        total_bytes += content.bytesize
        if content.bytesize != expected.bytes || Digest::SHA256.hexdigest(content) != expected.sha256
          return "private prompt changed after runner capture"
        end
      end
      return "private prompt tree exceeds #{EvalLimits::MAX_RUN_PROMPT_BYTES} bytes" if total_bytes > EvalLimits::MAX_RUN_PROMPT_BYTES

      nil
    end
    private_class_method :private_prompt_error
  end
end
