# frozen_string_literal: true

require_relative "eval_limits"

module Zstack
  module EvalOutputFile
    STABLE_STAT_FIELDS = %i[dev ino size mtime ctime].freeze

    def self.read_optional(
      path,
      max_bytes: EvalLimits::MAX_HOST_OUTPUT_BYTES,
      label: "final response",
      require_utf8: true
    )
      raise ArgumentError, "output label must be a non-empty string" unless label.is_a?(String) && !label.empty?
      unless [true, false].include?(require_utf8)
        raise ArgumentError, "require_utf8 must be true or false"
      end

      return [nil, "missing #{label}"] unless File.exist?(path) || File.symlink?(path)

      before = File.lstat(path)
      unless safe_regular_file?(before)
        return [nil, "#{label} must be a regular non-link file owned by uid #{Process.uid} with one hard link"]
      end
      return [nil, "#{label} exceeds #{max_bytes} bytes"] if before.size > max_bytes

      flags = File::RDONLY | File::NONBLOCK
      flags |= File::NOFOLLOW if File.const_defined?(:NOFOLLOW)
      content = +""
      opened_before = nil
      opened_after = nil
      File.open(path, flags) do |file|
        opened_before = file.stat
        unless safe_regular_file?(opened_before)
          return [nil, "#{label} must remain a regular file owned by uid #{Process.uid} with one hard link"]
        end
        unless STABLE_STAT_FIELDS.all? { |field| before.public_send(field) == opened_before.public_send(field) }
          return [nil, "#{label} changed before content was read"]
        end

        while (chunk = file.read(64 * 1024))
          content << chunk
          return [nil, "#{label} exceeds #{max_bytes} bytes"] if content.bytesize > max_bytes
        end
        opened_after = file.stat
      end
      after = File.lstat(path)
      stable = STABLE_STAT_FIELDS.all? do |field|
        before.public_send(field) == opened_before.public_send(field) &&
          opened_before.public_send(field) == opened_after.public_send(field) &&
          opened_after.public_send(field) == after.public_send(field)
      end
      unless stable && content.bytesize == opened_after.size && safe_regular_file?(opened_after) &&
             safe_regular_file?(after) && !after.symlink?
        return [nil, "#{label} changed while it was captured"]
      end
      if require_utf8
        content.force_encoding(Encoding::UTF_8)
        return [nil, "#{label} must be valid UTF-8"] unless content.valid_encoding?
      else
        content.force_encoding(Encoding::BINARY)
      end

      [content, nil]
    rescue SystemCallError => e
      [nil, "#{label} could not be read safely: #{e.class}"]
    end

    def self.write_exclusive(path, content, max_bytes: EvalLimits::MAX_HOST_OUTPUT_BYTES, label: "final response")
      raise ArgumentError, "output label must be a non-empty string" unless label.is_a?(String) && !label.empty?
      raise ArgumentError, "#{label} must be a string" unless content.is_a?(String)
      unless max_bytes.is_a?(Integer) && max_bytes.positive?
        raise ArgumentError, "final response byte limit must be a positive integer"
      end
      utf8_content = content.dup.force_encoding(Encoding::UTF_8)
      raise ArgumentError, "#{label} must be valid UTF-8" unless utf8_content.valid_encoding?
      raise ArgumentError, "#{label} exceeds #{max_bytes} bytes" if content.bytesize > max_bytes

      flags = File::WRONLY | File::CREAT | File::EXCL
      flags |= File::NOFOLLOW if File.const_defined?(:NOFOLLOW)
      created_stat = nil
      File.open(path, flags, 0o600) do |file|
        created_stat = file.stat
        file.write(content)
        file.flush
        file.fsync
      end
    rescue SystemCallError, IOError => e
      remove_created_target(path, created_stat)
      raise "#{label} could not be written safely: #{e.class}"
    end

    def self.open_exclusive(path, label: "host output")
      raise ArgumentError, "output label must be a non-empty string" unless label.is_a?(String) && !label.empty?

      flags = File::WRONLY | File::CREAT | File::EXCL
      flags |= File::NOFOLLOW if File.const_defined?(:NOFOLLOW)
      File.open(path, flags, 0o600)
    rescue SystemCallError, IOError => e
      raise "#{label} could not be created safely: #{e.class}"
    end

    def self.remove_created_target(path, created_stat)
      return unless created_stat

      current = File.lstat(path)
      return unless current.file? && !current.symlink?
      return unless current.dev == created_stat.dev && current.ino == created_stat.ino

      File.unlink(path)
    rescue Errno::ENOENT, Errno::EACCES, Errno::EPERM
      nil
    end
    private_class_method :remove_created_target

    def self.safe_regular_file?(stat)
      stat.file? && stat.uid == Process.uid && stat.nlink == 1
    end
    private_class_method :safe_regular_file?
  end
end
