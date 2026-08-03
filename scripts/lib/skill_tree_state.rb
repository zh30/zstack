# frozen_string_literal: true

require "digest"
require "find"
require "json"
require_relative "eval_input_file"
require_relative "eval_limits"

module Zstack
  module SkillTreeState
    class CaptureError < RuntimeError; end

    module_function

    def capture(root, snapshot_root: nil)
      expanded_root = File.realpath(root)
      root_before = safe_root_metadata(expanded_root)
      expanded_snapshot_root = prepare_snapshot_root(expanded_root, snapshot_root)
      snapshot_root_before = safe_snapshot_root_metadata(expanded_snapshot_root) if expanded_snapshot_root
      first = if expanded_snapshot_root
                capture_entries(expanded_root) do |relative, kind, content|
                  write_snapshot_entry(expanded_snapshot_root, relative, kind, content)
                end
              else
                capture_entries(expanded_root)
              end
      second = capture_entries(expanded_root)
      root_after = safe_root_metadata(expanded_root)

      unless root_before == root_after && first == second
        raise CaptureError, "skill tree changed while its state was captured"
      end
      if expanded_snapshot_root
        snapshot_root_after = safe_snapshot_root_metadata(expanded_snapshot_root, empty: false)
        unless snapshot_root_before == snapshot_root_after &&
               logical_entries(capture_entries(expanded_snapshot_root)) == logical_entries(first)
          raise CaptureError, "skill tree content snapshot changed while it was captured"
        end
      end

      JSON.generate(
        "version" => 1,
        "root" => root_before,
        "entries" => first
      )
    rescue CaptureError
      raise
    rescue EvalInputFile::ReadError => e
      raise CaptureError, e.message
    rescue SystemCallError => e
      raise CaptureError, "skill tree could not be captured safely: #{e.class}"
    end

    def capture_entries(root)
      entries = []
      entry_count = 0
      file_count = 0
      byte_count = 0

      Find.find(root) do |path|
        next if path == root

        entry_count += 1
        if entry_count > EvalLimits::MAX_SKILL_COLLECTION_TREE_ENTRIES
          raise CaptureError,
                "skill tree has more than #{EvalLimits::MAX_SKILL_COLLECTION_TREE_ENTRIES} entries"
        end

        relative = path.delete_prefix("#{root}/")
        unless EvalLimits.portable_relative_path?(relative)
          raise CaptureError, "skill tree path is not canonical portable UTF-8: #{relative.dump}"
        end

        before = File.lstat(path)
        if before.symlink?
          raise CaptureError, "skill tree contains a symbolic link: #{relative.dump}"
        elsif before.directory?
          ensure_owned!(before, relative, "directory")
          entries << [relative, "directory", stat_metadata(before)]
          yield relative, "directory", nil if block_given?
        elsif before.file?
          ensure_owned!(before, relative, "file")
          unless before.nlink == 1
            raise CaptureError, "skill tree file has multiple hard links: #{relative.dump}"
          end
          if before.size > EvalLimits::MAX_RETAINED_FILE_BYTES
            raise CaptureError,
                  "skill tree file exceeds #{EvalLimits::MAX_RETAINED_FILE_BYTES} bytes: #{relative.dump}"
          end

          content = EvalInputFile.read(
            path,
            max_bytes: EvalLimits::MAX_RETAINED_FILE_BYTES,
            label: "skill tree file #{relative.dump}",
            require_utf8: false,
            root: root
          )
          after = File.lstat(path)
          unless stat_metadata(before) == stat_metadata(after)
            raise CaptureError, "skill tree file changed while it was captured: #{relative.dump}"
          end

          file_count += 1
          byte_count += content.bytesize
          entries << [
            relative,
            "file",
            stat_metadata(after),
            Digest::SHA256.hexdigest(content)
          ]
          yield relative, "file", content if block_given?
        else
          raise CaptureError, "skill tree contains a non-regular entry: #{relative.dump}"
        end
      end

      if file_count > EvalLimits::MAX_SKILL_COLLECTION_FILES
        raise CaptureError,
              "skill tree has #{file_count} files; maximum is #{EvalLimits::MAX_SKILL_COLLECTION_FILES}"
      end
      if byte_count > EvalLimits::MAX_SKILL_COLLECTION_BYTES
        raise CaptureError,
              "skill tree is #{byte_count} bytes; maximum is #{EvalLimits::MAX_SKILL_COLLECTION_BYTES}"
      end

      entries.sort_by!(&:first)
    end
    private_class_method :capture_entries

    def prepare_snapshot_root(source_root, snapshot_root)
      return nil if snapshot_root.nil?

      expanded = File.realpath(snapshot_root)
      if expanded == source_root || expanded.start_with?("#{source_root}/") ||
         source_root.start_with?("#{expanded}/")
        raise CaptureError, "skill tree content snapshot must be outside the source tree"
      end
      expanded
    rescue SystemCallError => e
      raise CaptureError, "skill tree content snapshot root could not be resolved safely: #{e.class}"
    end
    private_class_method :prepare_snapshot_root

    def safe_snapshot_root_metadata(root, empty: true)
      stat = File.lstat(root)
      unless stat.directory? && !stat.symlink? && stat.uid == Process.uid && (stat.mode & 0o077).zero?
        raise CaptureError,
              "skill tree content snapshot root must be an owner-private real directory"
      end
      if empty && !Dir.empty?(root)
        raise CaptureError, "skill tree content snapshot root must be empty"
      end
      [stat.dev, stat.ino, stat.mode, stat.uid, stat.gid]
    end
    private_class_method :safe_snapshot_root_metadata

    def write_snapshot_entry(root, relative, kind, content)
      target = File.join(root, relative)
      if kind == "directory"
        Dir.mkdir(target, 0o700)
        return
      end

      flags = File::WRONLY | File::CREAT | File::EXCL
      flags |= File::NOFOLLOW if File.const_defined?(:NOFOLLOW)
      opened = nil
      File.open(target, flags, 0o600) do |file|
        opened = file.stat
        file.write(content)
        file.flush
        file.fsync
      end
      after = File.lstat(target)
      unless after.file? && !after.symlink? && after.uid == Process.uid && after.nlink == 1 &&
             after.dev == opened.dev && after.ino == opened.ino && after.size == content.bytesize
        raise CaptureError, "skill tree content snapshot file changed while it was written: #{relative.dump}"
      end
    rescue SystemCallError, IOError => e
      raise CaptureError, "skill tree content snapshot could not be written: #{relative.dump}: #{e.class}"
    end
    private_class_method :write_snapshot_entry

    def logical_entries(entries)
      entries.map do |relative, kind, _metadata, digest|
        [relative, kind, digest]
      end
    end
    private_class_method :logical_entries

    def safe_root_metadata(root)
      stat = File.lstat(root)
      unless stat.directory? && !stat.symlink? && stat.uid == Process.uid
        raise CaptureError,
              "skill tree root must be a real directory owned by uid #{Process.uid}"
      end
      stat_metadata(stat)
    end
    private_class_method :safe_root_metadata

    def ensure_owned!(stat, relative, kind)
      return if stat.uid == Process.uid

      raise CaptureError,
            "skill tree #{kind} is not owned by uid #{Process.uid}: #{relative.dump}"
    end
    private_class_method :ensure_owned!

    def stat_metadata(stat)
      [
        stat.dev,
        stat.ino,
        stat.mode,
        stat.uid,
        stat.gid,
        stat.nlink,
        stat.size,
        stat.mtime.to_i,
        stat.mtime.nsec,
        stat.ctime.to_i,
        stat.ctime.nsec
      ]
    end
    private_class_method :stat_metadata
  end
end
