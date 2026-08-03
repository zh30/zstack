# Bind raw archive files and their manifest to the exact bytes captured by an archiver.

require "digest"
require "set"
require_relative "eval_evidence_tree"
require_relative "eval_limits"
require_relative "eval_owned_directory"

module Zstack
  module EvalArchiveRawFiles
    MANIFEST_NAME = "artifact-manifest.txt"
    MANIFEST_HEADER = "sha256                                                            bytes  path"

    module_function

    def write_manifest(raw_directory, contents)
      normalized = normalize_contents(contents)
      verify!(raw_directory, normalized)
      manifest = manifest_content(normalized).freeze
      write_exclusively(File.join(raw_directory, MANIFEST_NAME), manifest)
      verify!(raw_directory, normalized, manifest)
      manifest
    end

    def verify!(raw_directory, contents, manifest_content = nil)
      normalized = normalize_contents(contents)
      expected_files = normalized.dup
      expected_files[MANIFEST_NAME] = manifest_content if manifest_content
      expected_entries = expected_entry_types(expected_files.keys)
      snapshot = EvalEvidenceTree.capture(raw_directory)
      unless snapshot.entries.keys.to_set == expected_entries.keys.to_set
        raise "raw archive inventory differs from captured files"
      end

      expected_entries.each do |relative, type|
        actual = snapshot.entries.fetch(relative)
        raise "raw archive entry type changed: #{relative}" unless actual.fetch(:type) == type
        next unless type == "file"

        content = expected_files.fetch(relative)
        unless actual.fetch(:bytes) == content.bytesize &&
               actual.fetch(:sha256) == Digest::SHA256.hexdigest(content)
          raise "raw archive file differs from captured bytes: #{relative}"
        end
      end
      true
    end

    def manifest_content(contents)
      normalized = normalize_contents(contents)
      lines = [MANIFEST_HEADER]
      normalized.keys.sort.each do |relative|
        content = normalized.fetch(relative)
        lines << "#{Digest::SHA256.hexdigest(content)}  #{content.bytesize}  #{relative}"
      end
      manifest = lines.join("\n") + "\n"
      if manifest.bytesize > EvalLimits::MAX_RETAINED_FILE_BYTES
        raise "raw archive manifest exceeds #{EvalLimits::MAX_RETAINED_FILE_BYTES} bytes"
      end
      manifest
    end

    def normalize_contents(contents)
      raise "raw archive contents must be a mapping" unless contents.is_a?(Hash)
      if contents.length + 1 > EvalLimits::MAX_ARCHIVE_FILES
        raise "raw archive exceeds #{EvalLimits::MAX_ARCHIVE_FILES} files including its manifest"
      end

      total_bytes = 0
      normalized = contents.each_with_object({}) do |(relative, content), result|
        unless EvalLimits.portable_relative_path?(relative) && relative != MANIFEST_NAME
          raise "raw archive path is not canonical and portable: #{relative.inspect}"
        end
        raise "raw archive content must be a string: #{relative}" unless content.is_a?(String)
        if content.bytesize > EvalLimits::MAX_RETAINED_FILE_BYTES
          raise "raw archive file exceeds #{EvalLimits::MAX_RETAINED_FILE_BYTES} bytes: #{relative}"
        end
        total_bytes += content.bytesize
        if total_bytes > EvalLimits::MAX_ARCHIVE_BYTES
          raise "raw archive exceeds #{EvalLimits::MAX_ARCHIVE_BYTES} captured bytes"
        end
        result[relative] = content
      end
      normalized.freeze
    end
    private_class_method :normalize_contents

    def expected_entry_types(files)
      entries = { "." => "directory" }
      files.each do |relative|
        components = relative.split("/")
        1.upto(components.length - 1) do |length|
          entries[components.first(length).join("/")] = "directory"
        end
        entries[relative] = "file"
      end
      entries
    end
    private_class_method :expected_entry_types

    def write_exclusively(path, content)
      directory = File.dirname(path)
      directory_identity = EvalOwnedDirectory.capture(directory, label: "raw archive directory")
      written = false
      created_stat = nil
      File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |output|
        created_stat = output.stat
        output.write(content)
        output.flush
        output.fsync
        current = output.stat
        unless safe_file?(current) && current.dev == created_stat.dev &&
               current.ino == created_stat.ino && current.size == content.bytesize
          raise "raw archive manifest changed while it was written"
        end
      end
      current_directory = EvalOwnedDirectory.capture(directory, label: "raw archive directory")
      current = File.lstat(path)
      unless current_directory == directory_identity && safe_file?(current) &&
             current.dev == created_stat.dev && current.ino == created_stat.ino &&
             current.size == content.bytesize
        raise "raw archive manifest or directory changed while it was written"
      end
      written = true
      path
    rescue SystemCallError => e
      raise "raw archive manifest could not be written safely: #{e.class}"
    ensure
      remove_created_file(path, created_stat) if !written && created_stat
    end
    private_class_method :write_exclusively

    def safe_file?(stat)
      stat.file? && !stat.symlink? && stat.uid == Process.uid && stat.nlink == 1
    end
    private_class_method :safe_file?

    def remove_created_file(path, created_stat)
      current = File.lstat(path)
      return unless current.file? && !current.symlink?
      return unless current.dev == created_stat.dev && current.ino == created_stat.ino

      File.unlink(path)
    rescue Errno::ENOENT, Errno::EACCES, Errno::EPERM
      nil
    end
    private_class_method :remove_created_file
  end
end
