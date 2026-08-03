# frozen_string_literal: true

module Zstack
  module EvalAuthFile
    MAX_BYTES = 1024 * 1024
    STABLE_STAT_FIELDS = %i[dev ino size mtime ctime].freeze

    def self.copy_optional(source:, destination:)
      return false unless File.exist?(source) || File.symlink?(source)

      destination_stat = nil
      copied = false
      before = File.lstat(source)
      unless before.file? && !before.symlink? && before.nlink == 1 && before.uid == Process.uid &&
             (before.mode & 0o077).zero?
        raise "auth path must be an owner-private single-link regular file: #{source}"
      end
      raise "auth file exceeds #{MAX_BYTES} bytes: #{source}" if before.size > MAX_BYTES

      flags = File::RDONLY | File::NONBLOCK
      flags |= File::NOFOLLOW if File.const_defined?(:NOFOLLOW)
      bytes = 0
      opened_before = nil
      opened_after = nil
      File.open(source, flags) do |input|
        opened_before = input.stat
        unless opened_before.file? && opened_before.nlink == 1 && opened_before.uid == Process.uid &&
               (opened_before.mode & 0o077).zero?
          raise "auth file changed to an unsafe source while opening: #{source}"
        end
        unless STABLE_STAT_FIELDS.all? { |field| before.public_send(field) == opened_before.public_send(field) }
          raise "auth file changed before it was copied: #{source}"
        end

        output_flags = File::WRONLY | File::CREAT | File::EXCL
        File.open(destination, output_flags, 0o600) do |output|
          destination_stat = output.stat
          while (chunk = input.read(64 * 1024))
            bytes += chunk.bytesize
            raise "auth file exceeded #{MAX_BYTES} bytes while copying: #{source}" if bytes > MAX_BYTES

            output.write(chunk)
          end
          output.flush
          output.fsync
        end
        opened_after = input.stat
      end
      after = File.lstat(source)
      stable = STABLE_STAT_FIELDS.all? do |field|
        before.public_send(field) == opened_before.public_send(field) &&
          opened_before.public_send(field) == opened_after.public_send(field) &&
          opened_after.public_send(field) == after.public_send(field)
      end
      unless stable && bytes == opened_after.size && after.file? && !after.symlink? && after.nlink == 1 &&
             after.uid == Process.uid && (after.mode & 0o077).zero?
        raise "auth file changed while it was copied: #{source}"
      end
      copied = true
      true
    rescue SystemCallError => e
      raise "auth file could not be copied safely: #{source}: #{e.class}"
    ensure
      remove_created_destination(destination, destination_stat) if !copied && destination_stat
    end

    def self.remove_created_destination(destination, destination_stat)
      current = File.lstat(destination)
      return unless current.file? && !current.symlink?
      return unless current.dev == destination_stat.dev && current.ino == destination_stat.ino

      File.unlink(destination)
    rescue Errno::ENOENT, Errno::EACCES, Errno::EPERM
      nil
    end
    private_class_method :remove_created_destination
  end
end
