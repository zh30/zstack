# Minimal Codex home construction for evaluation processes.

require "fileutils"

module Zstack
  module EvalCodexHome
    ANALYTICS_OVERRIDE = "analytics.enabled=false"

    AMBIENT_CONTEXT_KEYS = %w[
      CODEX_INTERNAL_ORIGINATOR_OVERRIDE
      CODEX_PERMISSION_PROFILE
      CODEX_THREAD_ID
    ].freeze

    module_function

    def prepare(root:, case_id:, auth_path:)
      home = File.join(root, ".codex-homes", case_id)
      FileUtils.mkdir_p(home, mode: 0o700)
      File.chmod(0o700, home)

      copied_auth = false
      if File.exist?(auth_path)
        raise "Codex auth path must be a regular file" unless File.file?(auth_path)
        raise "Codex auth path must not be a symbolic link" if File.symlink?(auth_path)

        destination = File.join(home, "auth.json")
        FileUtils.copy_file(auth_path, destination)
        File.chmod(0o600, destination)
        copied_auth = true
      end

      [home, copied_auth]
    end

    def environment(home)
      { "CODEX_HOME" => home }.merge(AMBIENT_CONTEXT_KEYS.to_h { |key| [key, nil] })
    end
  end
end
