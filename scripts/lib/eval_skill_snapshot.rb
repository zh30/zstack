# frozen_string_literal: true

require "fileutils"
require "find"
require "tmpdir"
require_relative "eval_input_file"
require_relative "eval_limits"
require_relative "eval_owned_directory"

module Zstack
  module EvalSkillSnapshot
    module_function

    def materialize!(destination, state, label: "copied skill")
      expected = validate_state!(state)
      destination = File.expand_path(destination)
      hub = File.dirname(destination)
      raise "#{label} destination already exists" if File.exist?(destination) || File.symlink?(destination)

      Dir.mkdir(hub, 0o700)
      hub_identity = EvalOwnedDirectory.capture(hub, label: "skill snapshot hub")
      staging = Dir.mktmpdir(".zstack-snapshot-", hub)
      staging_identity = EvalOwnedDirectory.capture(staging, label: "staged skill snapshot")
      published = false
      complete = false

      expected.each do |relative, content|
        target = File.join(staging, relative)
        FileUtils.mkdir_p(File.dirname(target), mode: 0o700)
        File.open(target, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
          file.write(content)
          file.flush
          file.fsync
        end
      end

      error = validation_error(staging, expected, label: label)
      raise error if error

      File.rename(staging, destination)
      published = true
      moved = File.lstat(destination)
      unless moved.directory? && !moved.symlink? &&
             moved.dev == staging_identity.dev && moved.ino == staging_identity.ino
        raise "#{label} changed identity during publication"
      end

      error = validation_error(destination, expected, label: label)
      raise error if error

      complete = true
      destination
    rescue SystemCallError, IOError => e
      raise "#{label} could not be materialized safely: #{e.class}"
    ensure
      unless complete
        cleanup_path = published ? destination : staging
        EvalOwnedDirectory.remove_if_same(cleanup_path, staging_identity) if cleanup_path && staging_identity
        begin
          current_hub = File.lstat(hub) if hub
          if current_hub && hub_identity && current_hub.directory? && !current_hub.symlink? &&
             current_hub.dev == hub_identity.dev && current_hub.ino == hub_identity.ino && Dir.empty?(hub)
            Dir.rmdir(hub)
          end
        rescue SystemCallError
          nil
        end
      end
    end

    def validation_error(root, state, label: "copied skill")
      expected = validate_state!(state)
      package_errors = EvalLimits.skill_package_errors(root)
      return "#{label} is outside its safety bounds: #{package_errors.first}" unless package_errors.empty?

      expected_entries = expected_entry_types(expected)
      actual_entries = capture_entry_types(root)
      return "#{label} changed after runner capture" unless actual_entries == expected_entries

      expected.each do |relative, expected_content|
        content = EvalInputFile.read(
          File.join(root, relative),
          max_bytes: EvalLimits::MAX_RETAINED_FILE_BYTES,
          label: label,
          require_utf8: false,
          root: root
        )
        return "#{label} changed after runner capture" unless content == expected_content
      end

      current_entries = capture_entry_types(root)
      return "#{label} changed while it was verified" unless current_entries == expected_entries

      nil
    rescue ArgumentError => e
      "#{label} state is invalid: #{e.message}"
    rescue EvalInputFile::ReadError, SystemCallError => e
      "#{label} could not be verified safely: #{e.class}"
    end

    def validate_state!(state)
      raise ArgumentError, "must be a non-empty mapping" unless state.is_a?(Hash) && !state.empty?

      total_bytes = 0
      state.each do |relative, content|
        unless EvalLimits.portable_relative_path?(relative)
          raise ArgumentError, "contains a non-portable path"
        end
        raise ArgumentError, "contains non-string bytes" unless content.is_a?(String)
        if content.bytesize > EvalLimits::MAX_RETAINED_FILE_BYTES
          raise ArgumentError, "contains an oversized file"
        end
        total_bytes += content.bytesize
      end
      raise ArgumentError, "contains too many files" if state.length > EvalLimits::MAX_SKILL_FILES
      raise ArgumentError, "exceeds the skill byte limit" if total_bytes > EvalLimits::MAX_SKILL_BYTES

      state
    end
    private_class_method :validate_state!

    def expected_entry_types(state)
      entries = {}
      state.each_key do |relative|
        components = relative.split("/")
        components[0...-1].each_index do |index|
          entries[components[0..index].join("/")] = :directory
        end
        entries[relative] = :file
      end
      entries
    end
    private_class_method :expected_entry_types

    def capture_entry_types(root)
      expanded_root = File.expand_path(root)
      entries = {}
      Find.find(expanded_root) do |path|
        next if path == expanded_root

        relative = path.delete_prefix("#{expanded_root}/")
        stat = File.lstat(path)
        entries[relative] = stat.directory? && !stat.symlink? ? :directory : :file
      end
      entries
    end
    private_class_method :capture_entry_types
  end
end
