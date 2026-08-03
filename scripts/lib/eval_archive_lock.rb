# Serialize evaluation archive publication without leaving repository-local state.

require "digest"
require "tmpdir"

module Zstack
  class EvalArchiveLock
    STABLE_STAT_FIELDS = %i[dev ino size mtime ctime].freeze
    MAX_OWNER_BYTES = 64

    def self.acquire(runs_root)
      path = path_for(runs_root)
      flags = File::RDWR | File::CREAT | File::NONBLOCK
      flags |= File::NOFOLLOW if File.const_defined?(:NOFOLLOW)
      file = File.open(path, flags, 0o600)
      path_stat = File.lstat(path)
      opened_stat = file.stat
      unless same_safe_lock_file?(path_stat, opened_stat)
        raise "evaluation archive lock must be an owner-private single-link regular file"
      end
      unless file.flock(File::LOCK_EX | File::LOCK_NB)
        raise "another evaluation archive publication is in progress"
      end

      locked_path_stat = File.lstat(path)
      locked_opened_stat = file.stat
      unless same_safe_lock_file?(locked_path_stat, locked_opened_stat)
        raise "evaluation archive lock path changed during acquisition"
      end

      file.rewind
      file.truncate(0)
      file.write("#{Process.pid}\n")
      file.flush
      file.fsync
      lock = new(file, path, owner_pid: Process.pid, owns_lock: true)
      lock.verify!
      lock
    rescue SystemCallError => e
      file&.close
      raise "evaluation archive lock could not be acquired: #{e.class}"
    rescue StandardError
      file&.close
      raise
    end

    def self.borrow_from_parent(runs_root)
      path = path_for(runs_root)
      flags = File::RDWR | File::NONBLOCK
      flags |= File::NOFOLLOW if File.const_defined?(:NOFOLLOW)
      file = File.open(path, flags)
      lease = new(file, path, owner_pid: Process.ppid, owns_lock: false)
      lease.verify!
      lease
    rescue SystemCallError, IOError, RuntimeError
      file&.close unless file&.closed?
      nil
    end

    def self.held_by_parent?(runs_root)
      lease = borrow_from_parent(runs_root)
      !lease.nil?
    ensure
      lease&.close
    end

    def self.path_for(runs_root)
      real_root = File.realpath(runs_root)
      key = Digest::SHA256.hexdigest(real_root)[0, 32]
      File.join(Dir.tmpdir, "zstack-eval-archive-#{key}.lock")
    end

    def self.safe_lock_stat?(stat)
      stat.file? && stat.nlink == 1 && stat.uid == Process.uid && (stat.mode & 0o077).zero?
    end

    def self.same_safe_lock_file?(path_stat, opened_stat)
      !path_stat.symlink? &&
        safe_lock_stat?(path_stat) &&
        safe_lock_stat?(opened_stat) &&
        path_stat.dev == opened_stat.dev &&
        path_stat.ino == opened_stat.ino
    end
    private_class_method :safe_lock_stat?, :same_safe_lock_file?

    def initialize(file, path, owner_pid:, owns_lock:)
      @file = file
      @path = path
      @owner_pid = owner_pid
      @owns_lock = owns_lock
    end

    def verify!
      raise "evaluation archive lock lease is closed" unless @file && !@file.closed?

      expected_process = @owns_lock ? Process.pid : Process.ppid
      unless expected_process == @owner_pid
        raise "evaluation archive lock ownership process changed"
      end

      path_before = File.lstat(@path)
      opened_before = @file.stat
      unless self.class.send(:same_safe_lock_file?, path_before, opened_before)
        raise "evaluation archive lock path changed or became unsafe"
      end

      owner = @file.pread(MAX_OWNER_BYTES + 1, 0)
      opened_after = @file.stat
      path_after = File.lstat(@path)
      stable = STABLE_STAT_FIELDS.all? do |field|
        path_before.public_send(field) == opened_before.public_send(field) &&
          opened_before.public_send(field) == opened_after.public_send(field) &&
          opened_after.public_send(field) == path_after.public_send(field)
      end
      unless stable && self.class.send(:same_safe_lock_file?, path_after, opened_after)
        raise "evaluation archive lock changed during lease verification"
      end
      unless owner == "#{@owner_pid}\n" && owner.bytesize <= MAX_OWNER_BYTES
        raise "evaluation archive lock owner metadata changed"
      end

      unless @owns_lock
        acquired = @file.flock(File::LOCK_EX | File::LOCK_NB)
        if acquired
          @file.flock(File::LOCK_UN)
          raise "evaluation archive parent no longer holds the publication lock"
        end
      end

      true
    rescue SystemCallError, IOError => e
      raise "evaluation archive lock lease could not be verified: #{e.class}"
    end

    def close
      return unless @file

      @file.flock(File::LOCK_UN) if @owns_lock
      @file.close
      @file = nil
    end
  end
end
