# Minimal Codex home construction for evaluation processes.

require_relative "eval_auth_file"
require_relative "eval_host_home"

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
      home, identity = EvalHostHome.create(
        root: root,
        directory_name: ".codex-homes",
        case_id: case_id
      )

      begin
        destination = File.join(home, "auth.json")
        copied_auth = EvalAuthFile.copy_optional(source: auth_path, destination: destination)

        [home, copied_auth]
      rescue StandardError
        EvalOwnedDirectory.remove_if_same(home, identity)
        raise
      end
    end

    def environment(home)
      { "CODEX_HOME" => home }.merge(AMBIENT_CONTEXT_KEYS.to_h { |key| [key, nil] })
    end
  end
end
