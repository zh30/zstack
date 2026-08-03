# frozen_string_literal: true

require "find"
require "pathname"
require_relative "eval_limits"

module Zstack
  module EvalOutputTree
    Entry = Struct.new(:kind, :dev, :ino, :size, :mtime, :ctime, keyword_init: true)

    class State
      def initialize(root:, root_dev:, root_ino:, entries:, mutable_paths:)
        @root = root
        @root_dev = root_dev
        @root_ino = root_ino
        @entries = entries.freeze
        @mutable_paths = mutable_paths.freeze
        freeze
      end

      def validation_error
        root_stat = File.lstat(@root)
        unless root_stat.directory? && !root_stat.symlink? &&
               root_stat.dev == @root_dev && root_stat.ino == @root_ino
          return "runner output tree root changed during execution"
        end

        seen = {}
        files = 0
        entries = 0
        bytes = 0
        Find.find(@root) do |path|
          next if path == @root

          entries += 1
          return "runner output tree exceeds #{EvalLimits::MAX_RUNTIME_OUTPUT_TREE_ENTRIES} entries" if entries > EvalLimits::MAX_RUNTIME_OUTPUT_TREE_ENTRIES

          relative = path.delete_prefix("#{@root}/")
          stat = File.lstat(path)
          if stat.symlink?
            Find.prune
            return "runner output tree contains a symbolic link"
          end
          unless stat.file? || stat.directory?
            return "runner output tree contains a non-regular entry"
          end
          return "runner output tree contains an entry not owned by the current user" unless stat.uid == Process.uid

          if stat.file?
            return "runner output tree contains a multiply linked file" unless stat.nlink == 1
            files += 1
            bytes += stat.size
            return "runner output tree exceeds #{EvalLimits::MAX_RUNTIME_OUTPUT_FILES} files" if files > EvalLimits::MAX_RUNTIME_OUTPUT_FILES
            return "runner output tree exceeds #{EvalLimits::MAX_RUNTIME_OUTPUT_BYTES} bytes" if bytes > EvalLimits::MAX_RUNTIME_OUTPUT_BYTES
          end

          if @mutable_paths.include?(relative)
            return "runner mutable output must remain a regular file" unless stat.file?

            next
          end

          expected = @entries[relative]
          return "runner output tree contains an unexpected entry" unless expected
          return "runner output tree entry changed during execution" unless same_entry?(expected, stat)

          seen[relative] = true
        end

        return "runner output tree lost an immutable entry" unless seen.length == @entries.length

        nil
      rescue SystemCallError => e
        "runner output tree could not be monitored safely: #{e.class}"
      end

      private

      def same_entry?(expected, stat)
        kind = stat.directory? ? :directory : :file
        return false unless kind == expected.kind && stat.dev == expected.dev && stat.ino == expected.ino
        return true if kind == :directory

        stat.size == expected.size && stat.mtime == expected.mtime && stat.ctime == expected.ctime
      end
    end

    module_function

    def capture(root, mutable_paths:)
      expanded_root = File.expand_path(root)
      root_stat = File.lstat(expanded_root)
      unless root_stat.directory? && !root_stat.symlink? && root_stat.uid == Process.uid && (root_stat.mode & 0o077).zero?
        raise "runner output tree must be an owner-private real directory"
      end

      mutable = normalize_mutable_paths(expanded_root, mutable_paths)
      entries = {}
      Find.find(expanded_root) do |path|
        next if path == expanded_root

        relative = path.delete_prefix("#{expanded_root}/")
        stat = File.lstat(path)
        if stat.symlink?
          Find.prune
          raise "runner output tree contains a symbolic link"
        end
        raise "runner output tree contains a non-regular entry" unless stat.file? || stat.directory?
        raise "runner output tree contains an entry not owned by the current user" unless stat.uid == Process.uid
        raise "runner output tree contains a multiply linked file" if stat.file? && stat.nlink != 1
        next if mutable.include?(relative)

        entries[relative] = Entry.new(
          kind: stat.directory? ? :directory : :file,
          dev: stat.dev,
          ino: stat.ino,
          size: stat.size,
          mtime: stat.mtime,
          ctime: stat.ctime
        ).freeze
      end
      state = State.new(
        root: expanded_root,
        root_dev: root_stat.dev,
        root_ino: root_stat.ino,
        entries: entries,
        mutable_paths: mutable
      )
      error = state.validation_error
      raise error if error

      state
    rescue SystemCallError => e
      raise "runner output tree could not be captured safely: #{e.class}"
    end

    def normalize_mutable_paths(root, paths)
      paths.each_with_object({}) do |path, normalized|
        absolute = File.expand_path(path)
        relative = Pathname.new(absolute).relative_path_from(Pathname.new(root)).to_s
        unless EvalLimits.portable_relative_path?(relative)
          raise "runner mutable output path escaped its output tree"
        end

        normalized[relative] = true
      end.freeze
    rescue ArgumentError
      raise "runner mutable output path escaped its output tree"
    end
    private_class_method :normalize_mutable_paths
  end
end
