# Capture one bounded, content-bound evidence tree for validation and reporting.

require "digest"
require "pathname"
require_relative "eval_input_file"
require_relative "eval_limits"

module Zstack
  module EvalEvidenceTree
    Snapshot = Struct.new(:root, :entries, keyword_init: true) do
      def run_json_paths
        entries.keys.select { |relative| relative.match?(%r{\A[^/]+/run\.json\z}) }
               .sort
               .map { |relative| File.join(root, relative) }
      end

      def verify_content!(path, content)
        parent = File.realpath(File.dirname(File.expand_path(path)))
        canonical = File.join(parent, File.basename(path))
        relative = Pathname.new(canonical).relative_path_from(Pathname.new(root)).to_s
        entry = entries.fetch(relative) { raise "evidence file was not in the validated tree: #{relative}" }
        unless entry.fetch(:type) == "file" && entry.fetch(:bytes) == content.bytesize &&
               entry.fetch(:sha256) == Digest::SHA256.hexdigest(content)
          raise "evidence file differs from the validated tree: #{relative}"
        end

        true
      rescue ArgumentError
        raise "evidence file must stay inside the validated tree"
      end
    end

    module_function

    def capture(root)
      expanded_root = File.expand_path(root)
      unless File.exist?(expanded_root) || File.symlink?(expanded_root)
        return Snapshot.new(root: expanded_root, entries: {}.freeze).freeze
      end

      canonical_root = File.realpath(root)
      root_stat = File.lstat(canonical_root)
      unless root_stat.directory? && !root_stat.symlink? && root_stat.uid == Process.uid
        raise "evidence root must be a real directory owned by uid #{Process.uid}"
      end

      entries = { "." => directory_entry(root_stat) }
      top_level = bounded_children(
        canonical_root,
        EvalLimits::MAX_EVIDENCE_ARCHIVES,
        "evidence root has more than #{EvalLimits::MAX_EVIDENCE_ARCHIVES} top-level entries"
      )
      total_entries = 0
      top_level.sort.each do |name|
        archive_path = File.join(canonical_root, name)
        stat = File.lstat(archive_path)
        total_entries += 1
        check_total_entries!(total_entries)
        entries[name] = capture_entry(archive_path, stat, canonical_root, name)
        next unless stat.directory? && !stat.symlink?

        pending = bounded_children(
          archive_path,
          EvalLimits::MAX_ARCHIVE_TREE_ENTRIES,
          "evidence archive has more than #{EvalLimits::MAX_ARCHIVE_TREE_ENTRIES} tree entries: #{name}"
        ).sort.reverse.map { |child| [File.join(archive_path, child), File.join(name, child)] }
        archive_entries = 0
        until pending.empty?
          path, relative = pending.pop
          stat = File.lstat(path)
          archive_entries += 1
          total_entries += 1
          if archive_entries > EvalLimits::MAX_ARCHIVE_TREE_ENTRIES
            raise "evidence archive has more than #{EvalLimits::MAX_ARCHIVE_TREE_ENTRIES} tree entries: #{name}"
          end
          check_total_entries!(total_entries)
          entries[relative] = capture_entry(path, stat, canonical_root, relative)
          next unless stat.directory? && !stat.symlink?

          remaining = EvalLimits::MAX_ARCHIVE_TREE_ENTRIES - archive_entries - pending.length
          children = bounded_children(
            path,
            remaining,
            "evidence archive has more than #{EvalLimits::MAX_ARCHIVE_TREE_ENTRIES} tree entries: #{name}"
          )
          children.sort.reverse_each do |child|
            pending << [File.join(path, child), File.join(relative, child)]
          end
        end
      end

      Snapshot.new(root: canonical_root, entries: entries.freeze).freeze
    rescue EvalInputFile::ReadError => e
      raise "evidence tree could not be captured safely: #{e.message}"
    rescue SystemCallError => e
      raise "evidence tree could not be captured safely: #{e.class}"
    end

    def bounded_children(directory, maximum, error)
      raise error if maximum.negative?

      children = []
      Dir.each_child(directory) do |name|
        raise error if children.length >= maximum

        children << name
      end
      children
    end
    private_class_method :bounded_children

    def capture_entry(path, stat, root, relative)
      if stat.symlink?
        raise "evidence tree contains a symbolic link: #{relative}"
      elsif stat.directory?
        unless stat.uid == Process.uid
          raise "evidence directory must be owned by uid #{Process.uid}: #{relative}"
        end
        directory_entry(stat)
      elsif stat.file?
        unless stat.uid == Process.uid && stat.nlink == 1
          raise "evidence file must be owned by uid #{Process.uid} with one hard link: #{relative}"
        end
        content = EvalInputFile.read(
          path,
          max_bytes: EvalLimits::MAX_RETAINED_FILE_BYTES,
          label: relative,
          require_utf8: false,
          root: root
        )
        current = File.lstat(path)
        unless current.file? && !current.symlink? && current.uid == Process.uid && current.nlink == 1
          raise "evidence file changed while the tree was captured: #{relative}"
        end
        file_entry(current, content)
      else
        raise "evidence tree contains a non-regular entry: #{relative}"
      end
    end
    private_class_method :capture_entry

    def directory_entry(stat)
      {
        type: "directory",
        dev: stat.dev,
        ino: stat.ino,
        uid: stat.uid,
        mode: stat.mode,
        mtime: stat.mtime.to_r,
        ctime: stat.ctime.to_r
      }.freeze
    end
    private_class_method :directory_entry

    def file_entry(stat, content)
      {
        type: "file",
        dev: stat.dev,
        ino: stat.ino,
        uid: stat.uid,
        nlink: stat.nlink,
        mode: stat.mode,
        bytes: content.bytesize,
        mtime: stat.mtime.to_r,
        ctime: stat.ctime.to_r,
        sha256: Digest::SHA256.hexdigest(content)
      }.freeze
    end
    private_class_method :file_entry

    def check_total_entries!(entries)
      return if entries <= EvalLimits::MAX_EVIDENCE_TREE_ENTRIES

      raise "evidence tree has more than #{EvalLimits::MAX_EVIDENCE_TREE_ENTRIES} entries"
    end
    private_class_method :check_total_entries!
  end
end
