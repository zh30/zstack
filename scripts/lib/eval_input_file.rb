# frozen_string_literal: true

require_relative "eval_limits"
require_relative "eval_output_file"
require "pathname"

module Zstack
  module EvalInputFile
    class ReadError < RuntimeError; end

    module_function

    def read(
      path,
      max_bytes: EvalLimits::MAX_RETAINED_FILE_BYTES,
      label: "evaluation input",
      require_utf8: true,
      root: nil
    )
      if root
        safe_path, directory_identities = capture_directory_identities(path, root, label)
      else
        safe_path = path
      end
      content, error = EvalOutputFile.read_optional(
        safe_path,
        max_bytes: max_bytes,
        label: label,
        require_utf8: require_utf8
      )
      raise ReadError, error if error
      validate_directory_identities!(directory_identities, label) if directory_identities

      content
    rescue ReadError
      raise
    rescue SystemCallError => e
      raise ReadError, "#{label} parent directories could not be validated safely: #{e.class}"
    end

    def capture_directory_identities(path, root, label)
      expanded_root = File.expand_path(root)
      expanded_candidate = File.expand_path(path)
      reject_linked_descendants!(expanded_candidate, expanded_root, label)
      root_path = File.realpath(expanded_root)
      candidate_parent = File.realpath(File.dirname(expanded_candidate))
      candidate = File.join(candidate_parent, File.basename(expanded_candidate))
      relative = Pathname.new(candidate).relative_path_from(Pathname.new(root_path)).to_s
      if relative == "." || relative == ".." || relative.start_with?("../")
        raise ReadError, "#{label} must stay inside its trusted root"
      end

      directories = [root_path]
      relative.split("/")[0...-1].each do |component|
        directories << File.join(directories.last, component)
      end
      identities = directories.map do |directory|
        stat = File.lstat(directory)
        unless stat.directory? && !stat.symlink? && stat.uid == Process.uid
          raise ReadError, "#{label} parent directory must be a real directory owned by uid #{Process.uid}"
        end
        [directory, stat.dev, stat.ino, stat.uid]
      end
      [candidate, identities]
    end
    private_class_method :capture_directory_identities

    def reject_linked_descendants!(candidate, expanded_root, label)
      relative = Pathname.new(candidate).relative_path_from(Pathname.new(expanded_root)).to_s
      return if relative == ".." || relative.start_with?("../")

      current = expanded_root
      relative.split("/")[0...-1].each do |component|
        current = File.join(current, component)
        stat = File.lstat(current)
        unless stat.directory? && !stat.symlink? && stat.uid == Process.uid
          raise ReadError, "#{label} parent directory must be a real directory owned by uid #{Process.uid}"
        end
      end
    end
    private_class_method :reject_linked_descendants!

    def validate_directory_identities!(identities, label)
      identities.each do |directory, device, inode, uid|
        stat = File.lstat(directory)
        unless stat.directory? && !stat.symlink? && stat.uid == uid && stat.uid == Process.uid &&
               stat.dev == device && stat.ino == inode
          raise ReadError, "#{label} parent directory changed while it was read"
        end
      end
    end
    private_class_method :validate_directory_identities!
  end
end
