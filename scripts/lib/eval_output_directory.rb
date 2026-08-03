# frozen_string_literal: true

require "fileutils"
require "tmpdir"

module Zstack
  module EvalOutputDirectory
    LEASE_NAME = ".zstack-eval-output.lock"

    class Reservation
      attr_reader :path

      def initialize(path, directory_stat, lease, lease_stat)
        @path = path
        @directory_stat = directory_stat
        @lease = lease
        @lease_stat = lease_stat
      end

      def verification_error
        return "output reservation is closed" unless @lease && !@lease.closed?

        directory = File.lstat(@path)
        unless same_directory?(directory) && directory.uid == Process.uid && (directory.mode & 0o077).zero?
          return "output directory changed while it was reserved"
        end

        lease_path = File.join(@path, LEASE_NAME)
        current_lease = File.lstat(lease_path)
        open_lease = @lease.stat
        unless current_lease.file? && !current_lease.symlink? &&
               current_lease.dev == @lease_stat.dev && current_lease.ino == @lease_stat.ino &&
               open_lease.dev == @lease_stat.dev && open_lease.ino == @lease_stat.ino
          return "output directory lease changed while it was reserved"
        end

        nil
      rescue SystemCallError, IOError => e
        "output directory could not be verified safely: #{e.class}"
      end

      def verify!
        error = verification_error
        raise error if error

        true
      end

      def close
        return unless @lease

        @lease.close unless @lease.closed?
        directory = File.lstat(@path)
        return unless same_directory?(directory)

        lease_path = File.join(@path, LEASE_NAME)
        current = File.lstat(lease_path)
        if current.file? && !current.symlink? && current.dev == @lease_stat.dev && current.ino == @lease_stat.ino
          File.unlink(lease_path)
        end
      rescue SystemCallError, IOError
        nil
      ensure
        @lease = nil
        @lease_stat = nil
        @directory_stat = nil
      end

      private

      def same_directory?(stat)
        stat.directory? && !stat.symlink? &&
          stat.dev == @directory_stat.dev && stat.ino == @directory_stat.ino
      end
    end

    def self.prepare(requested_path, prefix:)
      if requested_path
        path = File.expand_path(requested_path)
        if File.symlink?(path)
          raise "output directory must not be a symbolic link: #{path}"
        elsif File.exist?(path)
          raise "output path is not a directory: #{path}" unless File.directory?(path)
          raise "output directory must be empty: #{path}" unless Dir.empty?(path)
        else
          FileUtils.mkdir_p(path, mode: 0o700)
        end
      else
        path = Dir.mktmpdir(prefix)
      end

      stat = File.lstat(path)
      unless stat.directory? && !stat.symlink? && stat.uid == Process.uid && (stat.mode & 0o077).zero?
        raise "output directory must be owner-private for uid #{Process.uid}: #{path}"
      end
      reserve(path, stat)
    end

    def self.reserve(path, directory_stat)
      lease_path = File.join(path, LEASE_NAME)
      lease = nil
      lease_stat = nil
      flags = File::WRONLY | File::CREAT | File::EXCL
      flags |= File::NOFOLLOW if File.const_defined?(:NOFOLLOW)
      lease = File.open(lease_path, flags, 0o600)
      lease_stat = lease.stat
      lease.write("#{Process.pid}\n")
      lease.flush
      lease.fsync
      reservation = Reservation.new(path, directory_stat, lease, lease_stat)
      reservation.verify!
      reservation
    rescue SystemCallError, IOError => e
      lease&.close unless lease&.closed?
      remove_created_lease(lease_path, directory_stat, lease_stat) if lease_stat
      raise "output directory could not be reserved safely: #{e.class}"
    rescue RuntimeError
      lease&.close unless lease&.closed?
      remove_created_lease(lease_path, directory_stat, lease_stat) if lease_stat
      raise
    end
    private_class_method :reserve

    def self.remove_created_lease(path, directory_stat, created_stat)
      directory = File.lstat(File.dirname(path))
      return unless directory.directory? && !directory.symlink?
      return unless directory.dev == directory_stat.dev && directory.ino == directory_stat.ino

      current = File.lstat(path)
      return unless current.file? && !current.symlink?
      return unless current.dev == created_stat.dev && current.ino == created_stat.ino

      File.unlink(path)
    rescue Errno::ENOENT, Errno::EACCES, Errno::EPERM
      nil
    end
    private_class_method :remove_created_lease
  end
end
