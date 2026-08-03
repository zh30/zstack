# Create one owner-private, non-reusable host home for an opaque evaluation case.

require_relative "eval_owned_directory"
require_relative "eval_private_paths"

module Zstack
  module EvalHostHome
    DIRECTORY_NAME_PATTERN = /\A\.[a-z]+-homes\z/

    module_function

    def create(root:, directory_name:, case_id:)
      unless directory_name.is_a?(String) && directory_name.match?(DIRECTORY_NAME_PATTERN)
        raise "isolated host-home directory name is invalid"
      end
      unless EvalPrivatePaths.token?(case_id)
        raise "isolated host home requires an opaque private case token"
      end

      # Preserve the caller's lexical root so provenance paths remain beside
      # workspaces even on macOS, where /var resolves through /private/var.
      root_path = File.expand_path(root)
      validate_private_directory!(root_path, "evaluation workspace root")
      homes_root = File.join(root_path, directory_name)
      begin
        Dir.mkdir(homes_root, 0o700)
      rescue Errno::EEXIST
        nil
      end
      validate_private_directory!(homes_root, "isolated host-home root")

      home = File.join(homes_root, case_id)
      Dir.mkdir(home, 0o700)
      identity = EvalOwnedDirectory.capture(home, label: "isolated host home")
      [home, identity]
    rescue SystemCallError => e
      raise "isolated host home could not be created safely: #{e.class}"
    end

    def validate_private_directory!(path, label)
      stat = File.lstat(path)
      unless stat.directory? && !stat.symlink? && stat.uid == Process.uid && (stat.mode & 0o077).zero?
        raise "#{label} must be an owner-private non-link directory: #{path}"
      end
    end
    private_class_method :validate_private_directory!
  end
end
