# Shared publication and runner bounds for evaluation evidence.

require "find"
require "pathname"

module Zstack
  module EvalLimits
    MAX_RETAINED_FILE_BYTES = 2 * 1024 * 1024
    MAX_ARCHIVE_FILES = 500
    MAX_ARCHIVE_BYTES = 10 * 1024 * 1024
    MAX_ARCHIVE_TREE_ENTRIES = 2_000
    MAX_EVIDENCE_ARCHIVES = 1_000
    MAX_EVIDENCE_TREE_ENTRIES = 100_000
    MAX_HOST_OUTPUT_BYTES = MAX_RETAINED_FILE_BYTES
    MAX_ARTIFACT_FILES = 400
    MAX_ARTIFACT_BYTES = 8 * 1024 * 1024
    MAX_ARTIFACT_TREE_ENTRIES = 2_000
    MAX_RUN_ARTIFACT_FILES = MAX_ARTIFACT_FILES
    MAX_RUN_ARTIFACT_BYTES = MAX_ARTIFACT_BYTES
    MAX_ARTIFACT_RUNNER_JOBS = 1
    MAX_RUNTIME_GIT_FILES = 100
    MAX_RUNTIME_GIT_TREE_ENTRIES = 500
    MAX_RUNTIME_GIT_BYTES = 2 * 1024 * 1024
    MAX_RUNTIME_HOST_HOME_FILES = 200
    MAX_RUNTIME_HOST_HOME_TREE_ENTRIES = 500
    MAX_RUNTIME_HOST_HOME_BYTES = 8 * 1024 * 1024
    MAX_SKILL_FILES = 100
    MAX_SKILL_BYTES = 5 * 1024 * 1024
    MAX_SKILL_TREE_ENTRIES = 1_000
    MAX_SKILL_COLLECTION_FILES = 10_000
    MAX_SKILL_COLLECTION_BYTES = 512 * 1024 * 1024
    MAX_SKILL_COLLECTION_TREE_ENTRIES = 100_000
    MAX_REPOSITORY_CANDIDATES = 100_000
    MAX_REPOSITORY_CANDIDATE_BYTES = 512 * 1024 * 1024
    MAX_REPOSITORY_CANDIDATE_INVENTORY_BYTES = 16 * 1024 * 1024
    MAX_ARCHIVER_SOURCE_FILES = 1_000
    MAX_ARCHIVER_SOURCE_BYTES = 64 * 1024 * 1024
    MAX_RUNNER_JOBS = 32
    MAX_RUNNER_CASES = 256
    MAX_RUNTIME_OUTPUT_FILES = 4_096
    MAX_RUNTIME_OUTPUT_TREE_ENTRIES = 8_192
    MAX_RUNTIME_OUTPUT_BYTES = 640 * 1024 * 1024
    MAX_PROMPT_BYTES = 512 * 1024
    MAX_RUN_PROMPT_BYTES = 16 * 1024 * 1024
    MAX_RUNNER_TIMEOUT_SECONDS = 24 * 60 * 60
    VERSION_PROBE_TIMEOUT_SECONDS = 10
    MAX_VERSION_OUTPUT_BYTES = 64 * 1024
    EVIDENCE_TOOL_TIMEOUT_SECONDS = 5 * 60
    MAX_EVIDENCE_TOOL_OUTPUT_BYTES = MAX_RETAINED_FILE_BYTES
    EVIDENCE_REPORT_TIMEOUT_SECONDS = EVIDENCE_TOOL_TIMEOUT_SECONDS + 30
    MAX_EVIDENCE_REPORT_OUTPUT_BYTES = MAX_EVIDENCE_TOOL_OUTPUT_BYTES
    WORKSPACE_INIT_TIMEOUT_SECONDS = 10
    MAX_WORKSPACE_INIT_OUTPUT_BYTES = 64 * 1024
    MAX_GROK_TURNS = 100
    MAX_DESCRIPTION_CHARACTERS = 4_096
    MAX_IDENTIFIER_CHARACTERS = 128

    module_function

    def finite_nonnegative_number?(value)
      value.is_a?(Numeric) && value.finite? && value >= 0
    end

    def finite_positive_number?(value)
      value.is_a?(Numeric) && value.finite? && value.positive?
    end

    def finite_json_value?(value)
      case value
      when Hash
        value.all? { |key, nested| key.is_a?(String) && finite_json_value?(nested) }
      when Array
        value.all? { |nested| finite_json_value?(nested) }
      when Numeric
        value.finite?
      when String, TrueClass, FalseClass, NilClass
        true
      else
        false
      end
    end

    def nonnegative_finite_json_value?(value)
      case value
      when Hash
        value.all? do |key, nested|
          key.is_a?(String) && nonnegative_finite_json_value?(nested)
        end
      when Array
        value.all? { |nested| nonnegative_finite_json_value?(nested) }
      when Numeric
        finite_nonnegative_number?(value)
      when String, TrueClass, FalseClass, NilClass
        true
      else
        false
      end
    end

    def portable_relative_path?(path)
      return false unless path.is_a?(String) && !path.empty?

      utf8_path = path.dup.force_encoding(Encoding::UTF_8)
      return false unless utf8_path.valid_encoding?

      candidate = Pathname.new(utf8_path)
      clean_path = candidate.cleanpath.to_s
      !candidate.absolute? && clean_path == utf8_path && clean_path != "." && clean_path != ".." &&
        !clean_path.start_with?("../") && utf8_path == utf8_path.strip &&
        !utf8_path.match?(/[[:cntrl:]]/)
    rescue ArgumentError
      false
    end

    def skill_package_errors(root)
      root = File.expand_path(root)
      root_stat = File.lstat(root)
      unless root_stat.directory? && !root_stat.symlink? && root_stat.uid == Process.uid
        return ["skill package root must be a real directory owned by the current user"]
      end
      files = 0
      bytes = 0
      entries = 0
      errors = []

      Find.find(root) do |path|
        next if path == root

        entries += 1
        if entries > MAX_SKILL_TREE_ENTRIES
          errors << "skill package has more than #{MAX_SKILL_TREE_ENTRIES} tree entries"
          break
        end
        relative = path.delete_prefix("#{root}/")
        unless portable_relative_path?(relative)
          errors << "skill package path is not canonical portable UTF-8: #{relative.dump}"
        end
        stat = File.lstat(path)
        if stat.symlink?
          errors << "skill package contains a symbolic link: #{relative.dump}"
          Find.prune
        elsif stat.file?
          files += 1
          errors << "skill package file is not owned by the current user: #{relative.dump}" unless stat.uid == Process.uid
          errors << "skill package file has multiple hard links: #{relative.dump}" unless stat.nlink == 1
          file_bytes = stat.size
          bytes += file_bytes
          if file_bytes > MAX_RETAINED_FILE_BYTES
            errors << "skill package file is #{file_bytes} bytes; maximum is #{MAX_RETAINED_FILE_BYTES}: #{relative.dump}"
          end
        elsif stat.directory?
          errors << "skill package directory is not owned by the current user: #{relative.dump}" unless stat.uid == Process.uid
        else
          errors << "skill package contains a non-regular entry: #{relative.dump}"
        end
      end

      errors << "skill package has #{files} files; maximum is #{MAX_SKILL_FILES}" if files > MAX_SKILL_FILES
      errors << "skill package is #{bytes} bytes; maximum is #{MAX_SKILL_BYTES}" if bytes > MAX_SKILL_BYTES
      errors
    rescue SystemCallError => e
      ["skill package could not be inspected safely: #{e.class}"]
    end
  end
end
