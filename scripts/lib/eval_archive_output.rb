# Write generated archive files without following or overwriting raced paths.

require_relative "eval_limits"
require_relative "eval_owned_directory"

module Zstack
  class EvalArchiveOutput
    def initialize(root)
      @root = File.realpath(root)
      @root_identity = EvalOwnedDirectory.capture(@root, label: "archive transaction directory")
      @written = {}
    end

    def write(relative, content)
      unless EvalLimits.portable_relative_path?(relative) && File.dirname(relative) == "."
        raise "generated archive path must be one canonical top-level file: #{relative.inspect}"
      end
      raise "generated archive content must be a string: #{relative}" unless content.is_a?(String)
      if content.bytesize > EvalLimits::MAX_RETAINED_FILE_BYTES
        raise "generated archive file exceeds #{EvalLimits::MAX_RETAINED_FILE_BYTES} bytes: #{relative}"
      end
      raise "generated archive file was written twice: #{relative}" if @written.key?(relative)

      verify_root!
      path = File.join(@root, relative)
      written = false
      created_stat = nil
      flags = File::WRONLY | File::CREAT | File::EXCL
      flags |= File::NOFOLLOW if File.const_defined?(:NOFOLLOW)
      File.open(path, flags, 0o600) do |output|
        created_stat = output.stat
        output.write(content)
        output.flush
        output.fsync
        current = output.stat
        unless safe_file?(current) && current.dev == created_stat.dev &&
               current.ino == created_stat.ino && current.size == content.bytesize
          raise "generated archive file changed while it was written: #{relative}"
        end
      end
      verify_root!
      current = File.lstat(path)
      unless safe_file?(current) && current.dev == created_stat.dev &&
             current.ino == created_stat.ino && current.size == content.bytesize
        raise "generated archive file changed after it was written: #{relative}"
      end
      written = true
      @written[relative] = content
      path
    rescue SystemCallError => e
      raise "generated archive file could not be written safely: #{relative}: #{e.class}"
    ensure
      remove_created_file(path, created_stat) if !written && path && created_stat
    end

    private

    def verify_root!
      current = EvalOwnedDirectory.capture(@root, label: "archive transaction directory")
      raise "archive transaction directory changed while files were written" unless current == @root_identity
    end

    def safe_file?(stat)
      stat.file? && !stat.symlink? && stat.uid == Process.uid && stat.nlink == 1
    end

    def remove_created_file(path, created_stat)
      current = File.lstat(path)
      return unless current.file? && !current.symlink?
      return unless current.dev == created_stat.dev && current.ino == created_stat.ino

      File.unlink(path)
    rescue Errno::ENOENT, Errno::EACCES, Errno::EPERM
      nil
    end
  end
end
