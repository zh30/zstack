# frozen_string_literal: true

module Zstack
  module EvalExecutable
    MAX_PATH_BYTES = 64 * 1024
    MAX_PATH_ENTRIES = 256
    Snapshot = Struct.new(:path, :dev, :ino, :size, :mode, :mtime, :ctime, keyword_init: true)

    module_function

    def resolve(requested, display_name:)
      validate_name!(requested, display_name)
      candidate = if requested.include?(File::SEPARATOR)
                    File.expand_path(requested)
                  else
                    resolve_from_path(requested, display_name)
                  end
      real_path = File.realpath(candidate)
      stat = File.lstat(real_path)
      unless stat.file? && !stat.symlink? && File.executable?(real_path)
        raise "#{display_name} executable must resolve to an executable regular file"
      end

      snapshot(real_path, stat)
    rescue Errno::ENOENT, Errno::EACCES, Errno::ELOOP => e
      raise "#{display_name} executable cannot be resolved safely: #{e.class}"
    end

    def verify!(expected, display_name:)
      unless expected.is_a?(Snapshot) && expected.path.is_a?(String)
        raise ArgumentError, "expected executable snapshot is invalid"
      end

      stat = File.lstat(expected.path)
      current = snapshot(expected.path, stat)
      raise "#{display_name} executable changed during the run" unless current == expected

      true
    rescue Errno::ENOENT, Errno::EACCES, Errno::ELOOP
      raise "#{display_name} executable changed during the run"
    end

    def validate_name!(requested, display_name)
      requested_utf8 = requested.dup.force_encoding(Encoding::UTF_8) if requested.is_a?(String)
      unless requested_utf8 && !requested_utf8.empty? && requested_utf8.valid_encoding?
        raise ArgumentError, "host executable must be a non-empty valid string"
      end
      unless display_name.is_a?(String) && !display_name.empty?
        raise ArgumentError, "host display name must be a non-empty string"
      end
      if requested.each_codepoint.any? { |codepoint| codepoint < 32 || codepoint == 127 }
        raise ArgumentError, "host executable must not contain control characters"
      end
    end
    private_class_method :validate_name!

    def resolve_from_path(requested, display_name)
      path = ENV.fetch("PATH", "")
      raise "PATH exceeds #{MAX_PATH_BYTES} bytes" if path.bytesize > MAX_PATH_BYTES

      entries = path.split(File::PATH_SEPARATOR, -1)
      raise "PATH exceeds #{MAX_PATH_ENTRIES} entries" if entries.length > MAX_PATH_ENTRIES

      candidate = entries.lazy.map do |entry|
        directory = entry.empty? ? Dir.pwd : entry
        File.expand_path(requested, directory)
      end.find { |path_entry| File.file?(path_entry) && File.executable?(path_entry) }
      raise "#{display_name} executable not found on PATH" unless candidate

      candidate
    end
    private_class_method :resolve_from_path

    def snapshot(path, stat)
      Snapshot.new(
        path: path,
        dev: stat.dev,
        ino: stat.ino,
        size: stat.size,
        mode: stat.mode,
        mtime: stat.mtime,
        ctime: stat.ctime
      )
    end
    private_class_method :snapshot
  end
end
