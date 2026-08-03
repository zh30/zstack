# frozen_string_literal: true

require "pathname"

module Zstack
  module EvalSkillSource
    module_function

    def resolve(repository_root:, relative_path:, skill_id:)
      unless relative_path.is_a?(String) && !relative_path.empty?
        raise "#{skill_id}: skill path must be a non-empty string"
      end

      lexical_skills_root = File.join(repository_root, "skills")
      lexical_path = File.expand_path(relative_path, repository_root)
      unless lexical_path.start_with?(lexical_skills_root + File::SEPARATOR)
        raise "#{skill_id}: skill path must stay inside skills/"
      end

      real_skills_root = File.realpath(lexical_skills_root)
      relative = Pathname.new(lexical_path).relative_path_from(Pathname.new(lexical_skills_root)).to_s
      expected_real_path = File.join(real_skills_root, relative)
      real_path = File.realpath(lexical_path)
      unless real_path == expected_real_path && real_path.start_with?(real_skills_root + File::SEPARATOR)
        raise "#{skill_id}: skill path must not traverse a symbolic link"
      end

      stat = File.lstat(real_path)
      raise "#{skill_id}: skill directory is missing" unless stat.directory?
      raise "#{skill_id}: skill directory must not be a symbolic link" if stat.symlink?

      real_path
    rescue Errno::ENOENT, Errno::EACCES, Errno::ELOOP, Errno::ENOTDIR => e
      raise "#{skill_id}: skill directory cannot be resolved safely: #{e.class}"
    end
  end
end
