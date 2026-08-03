#!/usr/bin/env ruby
# Generate deterministic whole-archive manifests for evaluation evidence.

require "digest"
require "find"
require "optparse"
require "pathname"
require "tempfile"
require_relative "lib/eval_archive_lock"
require_relative "lib/eval_archive_name"
require_relative "lib/eval_input_file"
require_relative "lib/eval_limits"

ROOT = File.expand_path("..", __dir__)
RUNS_ROOT = File.join(ROOT, "evals", "runs")
MANIFEST_NAME = "archive-manifest.txt"
HEADER = "sha256                                                            bytes  path\n"
EVAL_ARCHIVE_NAME = Zstack::EvalArchiveName
EVAL_LIMITS = Zstack::EvalLimits

options = { check: false, publication_lock_held: false }
OptionParser.new do |parser|
  parser.banner = "Usage: ruby scripts/generate-evidence-manifests.rb [--check] [ARCHIVE ...]"
  parser.on("--check", "Fail when an archive manifest is missing or stale") do
    options[:check] = true
  end
  parser.on("--publication-lock-held", "Internal: caller already holds the evals/runs publication lock") do
    options[:publication_lock_held] = true
  end
end.parse!

def relative_to_root(path)
  Pathname.new(path).relative_path_from(Pathname.new(ROOT)).to_s
end

def bounded_top_level_entries(directory)
  entries = []
  Dir.each_child(directory) do |name|
    if entries.length >= EVAL_LIMITS::MAX_EVIDENCE_ARCHIVES
      raise "evals/runs has more than #{EVAL_LIMITS::MAX_EVIDENCE_ARCHIVES} top-level entries"
    end
    entries << File.join(directory, name)
  end
  entries.sort
end

def canonical_relative_path(path, base_directory)
  relative_path = Pathname.new(path).relative_path_from(Pathname.new(base_directory)).to_s
  clean_path = Pathname.new(relative_path).cleanpath.to_s
  unless relative_path == clean_path && relative_path == relative_path.strip &&
         !relative_path.match?(/[[:cntrl:]]/) && relative_path != "."
    raise "#{relative_to_root(path)}: path is not canonical and portable"
  end
  relative_path
end

def owned_directory_state(path, label)
  stat = File.lstat(path)
  unless stat.directory? && !stat.symlink? && stat.uid == Process.uid
    raise "#{label} must be a real directory owned by uid #{Process.uid}"
  end

  [stat.dev, stat.ino, stat.mode, stat.uid]
end

def safe_archive_file?(stat)
  stat.file? && stat.uid == Process.uid && stat.nlink == 1
end

def archive_files(archive_directory)
  archive_state = owned_directory_state(archive_directory, relative_to_root(archive_directory))
  entries = 0
  files = []
  Find.find(archive_directory) do |path|
    next if path == archive_directory

    entries += 1
    if entries > EVAL_LIMITS::MAX_ARCHIVE_TREE_ENTRIES
      raise "archive has more than #{EVAL_LIMITS::MAX_ARCHIVE_TREE_ENTRIES} tree entries"
    end
    stat = File.lstat(path)
    raise "#{relative_to_root(path)}: symbolic links are not allowed" if stat.symlink?
    if stat.directory?
      raise "#{relative_to_root(path)}: archive directory must be owned by uid #{Process.uid}" unless stat.uid == Process.uid
      next
    end
    unless stat.file?
      raise "#{relative_to_root(path)}: archive content must be a regular file or directory"
    end
    unless safe_archive_file?(stat)
      raise "#{relative_to_root(path)}: archive file must be owned by uid #{Process.uid} with one hard link"
    end
    next if File.basename(path) == MANIFEST_NAME && File.dirname(path) == archive_directory

    files << path
  end
  unless owned_directory_state(archive_directory, relative_to_root(archive_directory)) == archive_state
    raise "#{relative_to_root(archive_directory)}: archive directory changed while it was enumerated"
  end
  [files.sort, entries]
end

def stable_fingerprint(path)
  path_before = File.lstat(path)
  unless safe_archive_file?(path_before) && !path_before.symlink?
    raise "#{relative_to_root(path)}: archive file must be owned by uid #{Process.uid} with one hard link"
  end

  digest = Digest::SHA256.new
  bytes = 0
  io_before = nil
  io_after = nil
  stable_fields = %i[dev ino size mtime ctime]
  open_flags = File::RDONLY | File::NONBLOCK
  open_flags |= File::NOFOLLOW if File.const_defined?(:NOFOLLOW)
  File.open(path, open_flags) do |file|
    io_before = file.stat
    unless safe_archive_file?(io_before)
      raise "#{relative_to_root(path)}: archive content must remain current-owner and single-link while hashing"
    end
    unless stable_fields.all? { |field| path_before.public_send(field) == io_before.public_send(field) }
      raise "#{relative_to_root(path)}: file changed before manifest hashing"
    end

    while (chunk = file.read(1024 * 1024))
      digest.update(chunk)
      bytes += chunk.bytesize
      if bytes > EVAL_LIMITS::MAX_RETAINED_FILE_BYTES
        raise "#{relative_to_root(path)}: archive file exceeded #{EVAL_LIMITS::MAX_RETAINED_FILE_BYTES} bytes while hashing"
      end
    end
    io_after = file.stat
  end
  path_after = File.lstat(path)
  stable = stable_fields.all? do |field|
    path_before.public_send(field) == io_before.public_send(field) &&
      io_before.public_send(field) == io_after.public_send(field) &&
      io_after.public_send(field) == path_after.public_send(field)
  end
  unless stable && bytes == io_after.size && safe_archive_file?(io_after) &&
         safe_archive_file?(path_after) && !path_after.symlink?
    raise "#{relative_to_root(path)}: file changed while its manifest entry was generated"
  end

  [digest.hexdigest, bytes]
end

def validate_archive_input_bounds(paths)
  projected_files = paths.length + 1
  if projected_files > EVAL_LIMITS::MAX_ARCHIVE_FILES
    raise "archive would have #{projected_files} regular files including #{MANIFEST_NAME}; maximum is #{EVAL_LIMITS::MAX_ARCHIVE_FILES}"
  end

  total_bytes = 0
  paths.each do |path|
    bytes = File.size(path)
    if bytes > EVAL_LIMITS::MAX_RETAINED_FILE_BYTES
      raise "#{relative_to_root(path)}: archive file is #{bytes} bytes; maximum is #{EVAL_LIMITS::MAX_RETAINED_FILE_BYTES}"
    end
    total_bytes += bytes
    if total_bytes > EVAL_LIMITS::MAX_ARCHIVE_BYTES
      raise "archive input is #{total_bytes} bytes before #{MANIFEST_NAME}; maximum published archive is #{EVAL_LIMITS::MAX_ARCHIVE_BYTES}"
    end
  end
  total_bytes
end

def manifest_target_state(manifest_path)
  stat = File.lstat(manifest_path)
  unless safe_archive_file?(stat) && !stat.symlink?
    raise "#{relative_to_root(manifest_path)}: existing archive manifest must be a current-owner single-link regular file"
  end

  [:regular, stat.dev, stat.ino, stat.size, stat.mode & 0o777, stat.mtime, stat.ctime]
rescue Errno::ENOENT
  [:missing]
end

def manifest_content(archive_directory)
  archive_state = owned_directory_state(archive_directory, relative_to_root(archive_directory))
  manifest_path = File.join(archive_directory, MANIFEST_NAME)
  target_state = manifest_target_state(manifest_path)
  target_content = if target_state == [:missing]
                     nil
                   else
                     Zstack::EvalInputFile.read(
                       manifest_path,
                       max_bytes: EVAL_LIMITS::MAX_RETAINED_FILE_BYTES,
                       label: relative_to_root(manifest_path),
                       require_utf8: false,
                       root: ROOT
                     )
                   end
  unless manifest_target_state(manifest_path) == target_state
    raise "#{relative_to_root(manifest_path)}: manifest target changed while it was captured"
  end

  paths, tree_entries = archive_files(archive_directory)
  validate_archive_input_bounds(paths)
  actual_bytes = 0
  body = paths.map do |path|
    relative_path = canonical_relative_path(path, archive_directory)
    digest, bytes = stable_fingerprint(path)
    actual_bytes += bytes
    if actual_bytes > EVAL_LIMITS::MAX_ARCHIVE_BYTES
      raise "archive input grew to #{actual_bytes} bytes while hashing; maximum published archive is #{EVAL_LIMITS::MAX_ARCHIVE_BYTES}"
    end
    "#{digest}  #{bytes}  #{relative_path}\n"
  end.join
  content = HEADER + body
  if content.bytesize > EVAL_LIMITS::MAX_RETAINED_FILE_BYTES
    raise "#{MANIFEST_NAME} would be #{content.bytesize} bytes; maximum is #{EVAL_LIMITS::MAX_RETAINED_FILE_BYTES}"
  end
  projected_bytes = actual_bytes + content.bytesize
  if projected_bytes > EVAL_LIMITS::MAX_ARCHIVE_BYTES
    raise "archive would be #{projected_bytes} bytes including #{MANIFEST_NAME}; maximum is #{EVAL_LIMITS::MAX_ARCHIVE_BYTES}"
  end
  observed_paths, observed_tree_entries = archive_files(archive_directory)
  unless observed_paths == paths && observed_tree_entries == tree_entries
    raise "archive contents changed while #{MANIFEST_NAME} was generated"
  end
  unless owned_directory_state(archive_directory, relative_to_root(archive_directory)) == archive_state
    raise "archive directory changed while #{MANIFEST_NAME} was generated"
  end
  [content, target_state, target_content, archive_state, tree_entries]
end

def remove_created_file(path, created_stat)
  current = File.lstat(path)
  return unless current.file? && !current.symlink?
  return unless current.dev == created_stat.dev && current.ino == created_stat.ino

  File.unlink(path)
rescue Errno::ENOENT, Errno::EACCES, Errno::EPERM
  nil
end

def write_atomically(path, content, expected_target_state, expected_directory_state, mode: 0o644)
  directory = File.dirname(path)
  unless owned_directory_state(directory, relative_to_root(directory)) == expected_directory_state
    raise "#{relative_to_root(directory)}: archive directory changed after preflight"
  end
  temporary = Tempfile.create(["archive-manifest", ".tmp"], directory)
  temporary_path = temporary.path
  temporary_stat = temporary.stat
  begin
    temporary.binmode
    temporary.write(content)
    temporary.flush
    temporary.fsync
    temporary.chmod(mode)
    temporary.close
    unless manifest_target_state(path) == expected_target_state
      raise "#{relative_to_root(path)}: manifest target changed after preflight"
    end
    unless owned_directory_state(directory, relative_to_root(directory)) == expected_directory_state
      raise "#{relative_to_root(directory)}: archive directory changed after preflight"
    end
    File.rename(temporary_path, path)
    manifest_target_state(path)
  ensure
    temporary.close unless temporary.closed?
    remove_created_file(temporary_path, temporary_stat)
  end
end

def rollback_publications(publications)
  errors = []
  publications.reverse_each do |publication|
    path = publication.fetch(:path)
    begin
      current_state = manifest_target_state(path)
      unless current_state == publication.fetch(:published_state)
        raise "manifest target changed after publication; replacement was preserved"
      end

      old_state = publication.fetch(:old_state)
      if old_state == [:missing]
        File.unlink(path)
        raise "new manifest remained after rollback" unless manifest_target_state(path) == [:missing]
      else
        write_atomically(
          path,
          publication.fetch(:old_content),
          current_state,
          publication.fetch(:directory_state),
          mode: old_state.fetch(4)
        )
        restored = Zstack::EvalInputFile.read(
          path,
          max_bytes: EVAL_LIMITS::MAX_RETAINED_FILE_BYTES,
          label: relative_to_root(path),
          require_utf8: false,
          root: ROOT
        )
        raise "restored manifest bytes do not match the preflight snapshot" unless restored == publication.fetch(:old_content)
      end
    rescue SystemCallError, RuntimeError => e
      errors << "#{relative_to_root(path)}: rollback failed: #{e.message}"
    end
  end
  errors
end

def verify_publications!(publications, expected_runs_root_state, publication_lock)
  publication_lock.verify!
  unless owned_directory_state(RUNS_ROOT, "evals/runs") == expected_runs_root_state
    raise "evals/runs changed after manifest publication"
  end

  publications.each do |publication|
    publication_lock.verify!
    path = publication.fetch(:path)
    directory = File.dirname(path)
    unless owned_directory_state(directory, relative_to_root(directory)) == publication.fetch(:directory_state)
      raise "#{relative_to_root(directory)}: archive directory changed after manifest publication"
    end
    unless manifest_target_state(path) == publication.fetch(:published_state)
      raise "#{relative_to_root(path)}: manifest target changed after publication"
    end
    content = Zstack::EvalInputFile.read(
      path,
      max_bytes: EVAL_LIMITS::MAX_RETAINED_FILE_BYTES,
      label: relative_to_root(path),
      require_utf8: false,
      root: ROOT
    )
    unless content == publication.fetch(:expected_content)
      raise "#{relative_to_root(path)}: published manifest bytes differ from the prepared content"
    end
  end

  publication_lock.verify!
  true
end

begin
  runs_root_state = owned_directory_state(RUNS_ROOT, "evals/runs")
rescue SystemCallError, RuntimeError => e
  warn "ERROR: #{e.message}"
  exit 1
end

publication_lock = if options[:publication_lock_held]
                     parent_lease = Zstack::EvalArchiveLock.borrow_from_parent(RUNS_ROOT)
                     unless parent_lease
                       raise "archive-manifest caller did not prove that its parent holds the publication lock"
                     end
                     parent_lease
                   else
                     Zstack::EvalArchiveLock.acquire(RUNS_ROOT)
                   end
at_exit { publication_lock&.close }
publication_lock.verify!

runs_root_real = File.realpath(RUNS_ROOT)
targets = if ARGV.empty?
            begin
              entries = bounded_top_level_entries(RUNS_ROOT)
            rescue SystemCallError, RuntimeError => e
              warn "ERROR: #{e.message}"
              exit 1
            end
            invalid_entries = entries.reject do |path|
              !File.symlink?(path) && File.directory?(path) && EVAL_ARCHIVE_NAME.valid_published?(File.basename(path))
            end
            invalid_entries.each do |path|
              if File.symlink?(path) || !File.directory?(path)
                warn "ERROR: #{relative_to_root(path)}: top-level entry must be a real archive directory"
              else
                warn "ERROR: #{relative_to_root(path)}: archive directory name must use a valid ISO calendar date as YYYY-MM-DD or YYYY-MM-DD-kebab-slug"
              end
            end
            exit 1 unless invalid_entries.empty?
            entries
          else
            if ARGV.length > EVAL_LIMITS::MAX_EVIDENCE_ARCHIVES
              warn "ERROR: at most #{EVAL_LIMITS::MAX_EVIDENCE_ARCHIVES} archive targets may be processed at once"
              exit 1
            end
            ARGV.map { |path| File.expand_path(path, ROOT) }
          end

if targets.empty?
  warn "ERROR: no evidence archives found"
  exit 1
end

if targets.uniq.length != targets.length
  warn "ERROR: duplicate evidence archive targets are not allowed"
  exit 1
end

failures = 0
targets.each do |archive_directory|
  begin
    unless File.directory?(archive_directory) && !File.symlink?(archive_directory) &&
           File.dirname(File.realpath(archive_directory)) == runs_root_real
      raise "target must be one archive directory directly under evals/runs"
    end
  rescue SystemCallError, RuntimeError => e
    warn "ERROR: #{relative_to_root(archive_directory)}: #{e.message}"
    failures += 1
  end
end
exit 1 if failures.positive?

prepared = []
evidence_tree_entries = 0
targets.each do |archive_directory|
  begin
    expected, target_state, target_content, archive_state, tree_entries = manifest_content(archive_directory)
    evidence_tree_entries += tree_entries + 1
    if evidence_tree_entries > EVAL_LIMITS::MAX_EVIDENCE_TREE_ENTRIES
      raise "evidence tree has more than #{EVAL_LIMITS::MAX_EVIDENCE_TREE_ENTRIES} entries"
    end
    prepared << [archive_directory, expected, target_state, target_content, archive_state, tree_entries]
  rescue SystemCallError, RuntimeError => e
    warn "ERROR: #{relative_to_root(archive_directory)}: #{e.message}"
    failures += 1
  end
end
exit 1 if failures.positive?

# A second full pass prevents an early archive from changing while later
# targets are still being prepared. Nothing is written until every target and
# existing manifest has matched both observations.
prepared.each do |archive_directory, expected, target_state, target_content, archive_state, tree_entries|
  begin
    observed, observed_target_state, observed_target_content, observed_archive_state, observed_tree_entries =
      manifest_content(archive_directory)
    unless observed == expected && observed_target_state == target_state && observed_archive_state == archive_state &&
           observed_target_content == target_content && observed_tree_entries == tree_entries &&
           owned_directory_state(RUNS_ROOT, "evals/runs") == runs_root_state
      raise "archive contents or manifest target changed after preflight"
    end
  rescue SystemCallError, RuntimeError => e
    warn "ERROR: #{relative_to_root(archive_directory)}: #{e.message}"
    failures += 1
  end
end
exit 1 if failures.positive?

if options[:check]
  prepared.each do |archive_directory, expected, target_state, _target_content, archive_state, _tree_entries|
    manifest_path = File.join(archive_directory, MANIFEST_NAME)
    relative_manifest = relative_to_root(manifest_path)
    begin
      publication_lock.verify!
      observed = if target_state == [:missing]
                   nil
                 else
                   Zstack::EvalInputFile.read(
                     manifest_path,
                     max_bytes: EVAL_LIMITS::MAX_RETAINED_FILE_BYTES,
                     label: relative_manifest,
                     require_utf8: false,
                     root: ROOT
                   )
                 end
      if observed == expected &&
         owned_directory_state(archive_directory, relative_to_root(archive_directory)) == archive_state &&
         owned_directory_state(RUNS_ROOT, "evals/runs") == runs_root_state
        puts "OK: #{relative_manifest}"
      else
        warn "STALE: #{relative_manifest}"
        failures += 1
      end
      publication_lock.verify!
    rescue SystemCallError, RuntimeError => e
      warn "ERROR: #{relative_to_root(archive_directory)}: #{e.message}"
      failures += 1
    end
  end
else
  publications = []
  prepared.each do |archive_directory, expected, target_state, target_content, archive_state, _tree_entries|
    manifest_path = File.join(archive_directory, MANIFEST_NAME)
    begin
      publication_lock.verify!
      unless owned_directory_state(RUNS_ROOT, "evals/runs") == runs_root_state
        raise "evals/runs changed after preflight"
      end
      published_state = write_atomically(manifest_path, expected, target_state, archive_state)
      publications << {
        path: manifest_path,
        old_state: target_state,
        old_content: target_content,
        expected_content: expected,
        directory_state: archive_state,
        published_state: published_state
      }
      publication_lock.verify!
    rescue SystemCallError, RuntimeError => e
      warn "ERROR: #{relative_to_root(archive_directory)}: #{e.message}"
      rollback_publications(publications).each { |message| warn "ERROR: #{message}" }
      failures += 1
      break
    end
  end
  if failures.zero?
    begin
      verify_publications!(publications, runs_root_state, publication_lock)
    rescue SystemCallError, RuntimeError => e
      warn "ERROR: manifest publication could not be verified: #{e.message}"
      rollback_publications(publications).each { |message| warn "ERROR: #{message}" }
      failures += 1
    end
  end
  if failures.zero?
    publication_lock.verify!
    publications.each { |publication| puts "updated #{relative_to_root(publication.fetch(:path))}" }
  end
end

exit 1 if failures.positive?
