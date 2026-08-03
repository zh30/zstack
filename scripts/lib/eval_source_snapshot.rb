# Capture bounded, stable runner files before an evaluation archive trusts them.

require "fileutils"
require "pathname"
require "tmpdir"
require_relative "eval_limits"
require_relative "eval_owned_directory"

module Zstack
  class EvalSourceSnapshot
    STABLE_STAT_FIELDS = %i[dev ino size mtime ctime].freeze

    attr_reader :run_directory

    def initialize(run_directory)
      @run_directory = File.realpath(run_directory)
      @run_directory_identity = EvalOwnedDirectory.capture(
        @run_directory,
        label: "runner source directory"
      )
      @snapshot_directory = Dir.mktmpdir("zstack-eval-source-snapshot-")
      @snapshot_identity = EvalOwnedDirectory.capture(
        @snapshot_directory,
        label: "runner source snapshot directory"
      )
      @captured = {}
      @captured_by_path = {}
      @captured_bytes = 0
    end

    def capture(relative_path)
      validate_relative_path!(relative_path)
      return @captured.fetch(relative_path).fetch(:path) if @captured.key?(relative_path)
      raise "runner source snapshot is closed" unless @snapshot_directory
      if @captured.length >= EvalLimits::MAX_ARCHIVER_SOURCE_FILES
        raise "runner source snapshot exceeds #{EvalLimits::MAX_ARCHIVER_SOURCE_FILES} files"
      end

      source = File.join(@run_directory, relative_path)
      validate_run_directory!
      validate_source_path!(source, relative_path)
      target = File.join(@snapshot_directory, relative_path)
      FileUtils.mkdir_p(File.dirname(target))
      content = copy_stable_file(source, target, relative_path)
      @captured_bytes += content.bytesize
      record = { path: target, content: content }.freeze
      @captured[relative_path] = record
      @captured_by_path[target] = record
      target
    end

    # Captured bytes, rather than the replaceable snapshot pathname, are the
    # authority for every later parse, digest, comparison, and archive copy.
    def read(reference)
      captured_record(reference).fetch(:content)
    end

    def read_text(reference)
      content = read(reference).dup.force_encoding(Encoding::UTF_8)
      raise "captured runner source is not valid UTF-8: #{reference}" unless content.valid_encoding?

      content.freeze
    end

    def bytesize(reference)
      read(reference).bytesize
    end

    def copy(reference, target)
      content = read(reference)
      copied = false
      target_stat = nil
      output_flags = File::WRONLY | File::CREAT | File::EXCL
      File.open(target, output_flags, 0o600) do |output|
        target_stat = output.stat
        output.write(content)
        output.flush
        output.fsync
        opened_after = output.stat
        unless safe_source_file?(opened_after) && opened_after.dev == target_stat.dev &&
               opened_after.ino == target_stat.ino && opened_after.size == content.bytesize
          raise "captured runner destination changed while it was written: #{target}"
        end
      end
      target_after = File.lstat(target)
      unless safe_source_file?(target_after) && target_after.dev == target_stat.dev &&
             target_after.ino == target_stat.ino && target_after.size == content.bytesize
        raise "captured runner destination changed while it was written: #{target}"
      end
      copied = true
      target
    rescue SystemCallError => e
      raise "captured runner source could not be copied to #{target}: #{e.class}"
    ensure
      remove_created_target(target, target_stat) if !copied && target_stat
    end

    def close
      return unless @snapshot_directory

      EvalOwnedDirectory.remove_if_same(@snapshot_directory, @snapshot_identity)
      @snapshot_directory = nil
      @snapshot_identity = nil
      @captured.clear
      @captured_by_path.clear
    end

    private

    def validate_relative_path!(relative_path)
      unless relative_path.is_a?(String) && !relative_path.empty?
        raise "runner path must be a non-empty relative string"
      end
      candidate = Pathname.new(relative_path)
      clean = candidate.cleanpath.to_s
      unless !candidate.absolute? && clean == relative_path && !clean.start_with?("../") && clean != "." &&
             relative_path == relative_path.strip && !relative_path.match?(/[[:cntrl:]]/)
        raise "runner path must be canonical and stay inside the run directory: #{relative_path.dump}"
      end
    end

    def validate_source_path!(source, relative_path)
      current = @run_directory
      relative_path.split("/").each do |component|
        current = File.join(current, component)
        raise "runner path contains a symbolic link: #{relative_path}" if File.symlink?(current)
      end
      raise "runner file is missing or non-regular: #{relative_path}" unless File.file?(source)
      resolved = File.realpath(source)
      unless resolved.start_with?("#{@run_directory}/")
        raise "runner file resolves outside the run directory: #{relative_path}"
      end
    rescue Errno::ENOENT, Errno::EACCES => e
      raise "runner file cannot be accessed: #{relative_path}: #{e.class}"
    end

    def validate_run_directory!
      current = File.lstat(@run_directory)
      unless current.directory? && !current.symlink? && current.uid == Process.uid &&
             current.dev == @run_directory_identity.dev && current.ino == @run_directory_identity.ino
        raise "runner source directory changed while sources were captured"
      end
    rescue SystemCallError => e
      raise "runner source directory could not be verified safely: #{e.class}"
    end

    def copy_stable_file(source, target, relative_path)
      captured = false
      before = File.lstat(source)
      unless safe_source_file?(before)
        raise "runner source must remain a regular file owned by uid #{Process.uid} with one hard link: #{relative_path}"
      end

      flags = File::RDONLY | File::NONBLOCK
      flags |= File::NOFOLLOW if File.const_defined?(:NOFOLLOW)
      content = +"".b
      opened_before = nil
      opened_after = nil
      target_stat = nil
      File.open(source, flags) do |input|
        opened_before = input.stat
        unless safe_source_file?(opened_before)
          raise "runner source must remain a regular file owned by uid #{Process.uid} with one hard link: #{relative_path}"
        end
        unless STABLE_STAT_FIELDS.all? { |field| before.public_send(field) == opened_before.public_send(field) }
          raise "runner source changed before it was captured: #{relative_path}"
        end

        output_flags = File::WRONLY | File::CREAT | File::EXCL
        File.open(target, output_flags, 0o600) do |output|
          target_stat = output.stat
          while (chunk = input.read(1024 * 1024))
            content << chunk.b
            if content.bytesize > EvalLimits::MAX_RETAINED_FILE_BYTES
              raise "runner source file exceeds #{EvalLimits::MAX_RETAINED_FILE_BYTES} bytes: #{relative_path}"
            end
            if @captured_bytes + content.bytesize > EvalLimits::MAX_ARCHIVER_SOURCE_BYTES
              raise "runner source snapshot exceeds #{EvalLimits::MAX_ARCHIVER_SOURCE_BYTES} bytes"
            end
            output.write(chunk)
          end
          output.flush
          output.fsync
        end
        opened_after = input.stat
      end
      after = File.lstat(source)
      target_after = File.lstat(target)
      resolved_after = File.realpath(source)
      stable = STABLE_STAT_FIELDS.all? do |field|
        before.public_send(field) == opened_before.public_send(field) &&
          opened_before.public_send(field) == opened_after.public_send(field) &&
          opened_after.public_send(field) == after.public_send(field)
      end
      target_stable = safe_source_file?(target_after) && target_after.dev == target_stat.dev &&
                      target_after.ino == target_stat.ino
      validate_run_directory!
      unless stable && content.bytesize == opened_after.size && safe_source_file?(opened_after) &&
             safe_source_file?(after) && !after.symlink? && target_stable &&
             resolved_after.start_with?("#{@run_directory}/")
        raise "runner source changed while it was captured: #{relative_path}"
      end
      captured = true
      content.freeze
    rescue SystemCallError => e
      raise "runner source could not be captured: #{relative_path}: #{e.class}"
    ensure
      remove_created_target(target, target_stat) if !captured && target_stat
    end

    def remove_created_target(target, target_stat)
      current = File.lstat(target)
      return unless current.file? && !current.symlink?
      return unless current.dev == target_stat.dev && current.ino == target_stat.ino

      File.unlink(target)
    rescue Errno::ENOENT, Errno::EACCES, Errno::EPERM
      nil
    end

    def safe_source_file?(stat)
      stat.file? && stat.uid == Process.uid && stat.nlink == 1
    end

    def captured_record(reference)
      raise "runner source snapshot is closed" unless @snapshot_directory
      unless reference.is_a?(String) && !reference.empty?
        raise "runner source reference must be a non-empty string"
      end

      record = @captured[reference]
      record ||= @captured_by_path[File.expand_path(reference)]
      raise "runner source was not captured: #{reference}" unless record

      record
    end
  end
end
