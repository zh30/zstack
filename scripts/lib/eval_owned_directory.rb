# Remove temporary evaluation directories only while they are still the
# directory created by this process.

require "fileutils"
require "tmpdir"

module Zstack
  module EvalOwnedDirectory
    Identity = Struct.new(:dev, :ino, keyword_init: true)

    module_function

    def capture(path, label: "temporary evaluation directory")
      stat = File.lstat(path)
      unless stat.directory? && !stat.symlink? && stat.uid == Process.uid
        raise "#{label} must be a non-link directory owned by uid #{Process.uid}: #{path}"
      end

      Identity.new(dev: stat.dev, ino: stat.ino).freeze
    rescue SystemCallError => e
      raise "#{label} could not be identified safely: #{path}: #{e.class}"
    end

    def remove_if_same(path, identity)
      return false unless path && identity

      quarantine_root = Dir.mktmpdir(".zstack-owned-directory-", File.dirname(path))
      quarantine_root_stat = File.lstat(quarantine_root)
      quarantined_path = File.join(quarantine_root, "entry")
      current = File.lstat(path)
      return false unless current.directory? && !current.symlink?
      return false unless current.dev == identity.dev && current.ino == identity.ino

      File.rename(path, quarantined_path)
      quarantined = File.lstat(quarantined_path)
      unless quarantined.directory? && !quarantined.symlink? &&
             quarantined.dev == identity.dev && quarantined.ino == identity.ino
        restore_quarantined_path(path, quarantined_path, quarantined)
        return false
      end

      # The random owner-private quarantine removes the caller-visible name
      # before recursive traversal and makes a later pathname swap fail closed.
      FileUtils.remove_entry_secure(quarantined_path)
      true
    rescue SystemCallError
      false
    ensure
      remove_empty_quarantine(quarantine_root, quarantine_root_stat)
    end

    def restore_quarantined_path(path, quarantined_path, quarantined_stat)
      return false if File.exist?(path) || File.symlink?(path)

      File.rename(quarantined_path, path)
      restored = File.lstat(path)
      restored.dev == quarantined_stat.dev && restored.ino == quarantined_stat.ino
    rescue SystemCallError
      false
    end
    private_class_method :restore_quarantined_path

    def remove_empty_quarantine(path, identity)
      return unless path && identity

      current = File.lstat(path)
      return unless current.directory? && !current.symlink?
      return unless current.dev == identity.dev && current.ino == identity.ino

      Dir.rmdir(path) if Dir.empty?(path)
    rescue SystemCallError
      nil
    end
    private_class_method :remove_empty_quarantine
  end
end
