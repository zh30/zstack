# frozen_string_literal: true

require "digest"
require "json"
require_relative "eval_input_file"
require_relative "eval_limits"

module Zstack
  module RepositoryCandidateState
    class CaptureError < RuntimeError; end

    module_function

    def capture(root, inventory_path)
      expanded_root = File.expand_path(root)
      root_before = safe_root_identity(expanded_root)
      inventory, inventory_state = capture_inventory(inventory_path)
      candidates = parse_inventory(inventory)
      first = capture_entries(expanded_root, candidates)
      checked_inventory, checked_inventory_state = capture_inventory(inventory_path)
      second = capture_entries(expanded_root, candidates)
      final_inventory, final_inventory_state = capture_inventory(inventory_path)
      root_after = safe_root_identity(expanded_root)

      unless root_before == root_after && first == second &&
             inventory == checked_inventory && inventory == final_inventory &&
             inventory_state == checked_inventory_state && inventory_state == final_inventory_state
        raise CaptureError, "repository candidates changed while their state was captured"
      end

      JSON.generate(
        "version" => 1,
        "root" => root_before,
        "inventorySha256" => Digest::SHA256.hexdigest(candidates.join("\0") + "\0"),
        "entries" => first
      )
    rescue CaptureError
      raise
    rescue EvalInputFile::ReadError => e
      raise CaptureError, e.message
    rescue SystemCallError => e
      raise CaptureError, "repository candidates could not be captured safely: #{e.class}"
    end

    def capture_inventory(path)
      before = File.lstat(path)
      content = EvalInputFile.read(
        path,
        max_bytes: EvalLimits::MAX_REPOSITORY_CANDIDATE_INVENTORY_BYTES,
        label: "repository candidate inventory",
        require_utf8: false
      )
      after = File.lstat(path)
      unless safe_regular_file?(before) && stat_metadata(before) == stat_metadata(after)
        raise CaptureError, "repository candidate inventory changed while it was captured"
      end
      [content, stat_metadata(after)]
    end
    private_class_method :capture_inventory

    def parse_inventory(content)
      paths = content.split("\0", -1)
      unless paths.pop == ""
        raise CaptureError, "repository candidate inventory must be NUL-terminated"
      end
      if paths.length > EvalLimits::MAX_REPOSITORY_CANDIDATES
        raise CaptureError,
              "repository has more than #{EvalLimits::MAX_REPOSITORY_CANDIDATES} candidates"
      end
      unless paths.uniq.length == paths.length
        raise CaptureError, "repository candidate inventory contains duplicate paths"
      end
      paths.each do |relative|
        unless EvalLimits.portable_relative_path?(relative)
          raise CaptureError,
                "repository candidate path is not canonical portable UTF-8: #{relative.dump}"
        end
      end
      paths.sort.freeze
    end
    private_class_method :parse_inventory

    def capture_entries(root, candidates)
      entries = []
      total_bytes = 0

      candidates.each do |relative|
        path = File.join(root, relative)
        before = File.lstat(path)
        if before.symlink?
          parents = capture_parent_identities(root, relative)
          target = File.readlink(path).b
          after = File.lstat(path)
          current_target = File.readlink(path).b
          validate_parent_identities!(parents)
          unless before.uid == Process.uid && stat_metadata(before) == stat_metadata(after) &&
                 target == current_target
            raise CaptureError,
                  "repository candidate symlink changed while it was captured: #{relative.dump}"
          end
          total_bytes += target.bytesize
          entries << [
            relative,
            "symlink",
            stat_metadata(after),
            Digest::SHA256.hexdigest(target)
          ]
        elsif before.file?
          unless safe_regular_file?(before)
            raise CaptureError,
                  "repository candidate must be owned by uid #{Process.uid} with one hard link: #{relative.dump}"
          end
          if before.size > EvalLimits::MAX_RETAINED_FILE_BYTES
            raise CaptureError,
                  "repository candidate exceeds #{EvalLimits::MAX_RETAINED_FILE_BYTES} bytes: #{relative.dump}"
          end
          content = EvalInputFile.read(
            path,
            max_bytes: EvalLimits::MAX_RETAINED_FILE_BYTES,
            label: "repository candidate #{relative.dump}",
            require_utf8: false,
            root: root
          )
          after = File.lstat(path)
          unless safe_regular_file?(after) && stat_metadata(before) == stat_metadata(after)
            raise CaptureError,
                  "repository candidate changed while it was captured: #{relative.dump}"
          end
          total_bytes += content.bytesize
          entries << [
            relative,
            "file",
            stat_metadata(after),
            Digest::SHA256.hexdigest(content)
          ]
        else
          raise CaptureError,
                "repository candidate is not a regular file or symlink: #{relative.dump}"
        end

        if total_bytes > EvalLimits::MAX_REPOSITORY_CANDIDATE_BYTES
          raise CaptureError,
                "repository candidates exceed #{EvalLimits::MAX_REPOSITORY_CANDIDATE_BYTES} bytes"
        end
      end

      entries
    end
    private_class_method :capture_entries

    def safe_root_identity(root)
      stat = File.lstat(root)
      unless stat.directory? && !stat.symlink? && stat.uid == Process.uid
        raise CaptureError,
              "repository root must be a real directory owned by uid #{Process.uid}"
      end
      [stat.dev, stat.ino, stat.mode, stat.uid]
    end
    private_class_method :safe_root_identity

    def capture_parent_identities(root, relative)
      current = root
      identities = [[root, *safe_root_identity(root)]]
      relative.split("/")[0...-1].each do |component|
        current = File.join(current, component)
        stat = File.lstat(current)
        unless stat.directory? && !stat.symlink? && stat.uid == Process.uid
          raise CaptureError,
                "repository candidate parent must be a real directory owned by uid #{Process.uid}"
        end
        identities << [current, stat.dev, stat.ino, stat.mode, stat.uid]
      end
      identities
    end
    private_class_method :capture_parent_identities

    def validate_parent_identities!(identities)
      identities.each do |path, device, inode, mode, uid|
        stat = File.lstat(path)
        unless stat.directory? && !stat.symlink? && stat.dev == device && stat.ino == inode &&
               stat.mode == mode && stat.uid == uid && stat.uid == Process.uid
          raise CaptureError, "repository candidate parent changed while it was captured"
        end
      end
    end
    private_class_method :validate_parent_identities!

    def safe_regular_file?(stat)
      stat.file? && !stat.symlink? && stat.uid == Process.uid && stat.nlink == 1
    end
    private_class_method :safe_regular_file?

    def stat_metadata(stat)
      [
        stat.dev,
        stat.ino,
        stat.mode,
        stat.uid,
        stat.gid,
        stat.nlink,
        stat.size,
        stat.mtime.to_i,
        stat.mtime.nsec,
        stat.ctime.to_i,
        stat.ctime.nsec
      ]
    end
    private_class_method :stat_metadata
  end
end
