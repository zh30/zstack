# frozen_string_literal: true

require_relative "eval_auth_file"
require_relative "eval_host_home"

module Zstack
  module EvalGrokHome
    MAX_CONFIG_BYTES = 256 * 1024

    module_function

    def prepare(root:, case_id:, auth_path:, config:)
      home, identity = EvalHostHome.create(
        root: root,
        directory_name: ".grok-homes",
        case_id: case_id
      )

      begin
        config_path = File.join(home, "config.toml")
        write_config(config_path, config)
        auth_destination = File.join(home, "auth.json")
        auth_copied = EvalAuthFile.copy_optional(source: auth_path, destination: auth_destination)
        [home, auth_destination, auth_copied]
      rescue StandardError
        EvalOwnedDirectory.remove_if_same(home, identity)
        raise
      end
    end

    def environment(home:, auth_path:)
      {
        "GROK_HOME" => home,
        "GROK_AUTH_PATH" => auth_path,
        "GROK_MANAGED_MCPS_ENABLED" => "0",
        "GROK_OFFICIAL_MARKETPLACE_AUTO_REGISTER" => "0"
      }
    end

    def write_config(path, config)
      unless config.is_a?(String) && config.valid_encoding? && config.encoding == Encoding::UTF_8
        raise ArgumentError, "isolated Grok config must be valid UTF-8"
      end
      if config.bytesize > MAX_CONFIG_BYTES
        raise ArgumentError, "isolated Grok config exceeds #{MAX_CONFIG_BYTES} bytes"
      end

      created_stat = nil
      written = false
      flags = File::WRONLY | File::CREAT | File::EXCL
      File.open(path, flags, 0o600) do |file|
        created_stat = file.stat
        file.write(config)
        file.flush
        file.fsync
      end
      written = true
    rescue SystemCallError, IOError => e
      raise "isolated Grok config could not be written safely: #{e.class}"
    ensure
      remove_created_config(path, created_stat) if !written && created_stat
    end
    private_class_method :write_config

    def remove_created_config(path, created_stat)
      current = File.lstat(path)
      return unless current.file? && !current.symlink?
      return unless current.dev == created_stat.dev && current.ino == created_stat.ino

      File.unlink(path)
    rescue Errno::ENOENT, Errno::EACCES, Errno::EPERM
      nil
    end
    private_class_method :remove_created_config
  end
end
