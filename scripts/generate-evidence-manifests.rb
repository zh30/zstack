#!/usr/bin/env ruby
# Generate deterministic whole-archive manifests for evaluation evidence.

require "digest"
require "optparse"
require "pathname"
require "tempfile"

ROOT = File.expand_path("..", __dir__)
RUNS_ROOT = File.join(ROOT, "evals", "runs")
MANIFEST_NAME = "archive-manifest.txt"
HEADER = "sha256                                                            bytes  path\n"

options = { check: false }
OptionParser.new do |parser|
  parser.banner = "Usage: ruby scripts/generate-evidence-manifests.rb [--check] [ARCHIVE ...]"
  parser.on("--check", "Fail when an archive manifest is missing or stale") do
    options[:check] = true
  end
end.parse!

def relative_to_root(path)
  Pathname.new(path).relative_path_from(Pathname.new(ROOT)).to_s
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

def archive_files(archive_directory)
  Dir.glob(File.join(archive_directory, "**", "*"), File::FNM_DOTMATCH).select do |path|
    next false if %w[. ..].include?(File.basename(path))
    next false if File.basename(path) == MANIFEST_NAME && File.dirname(path) == archive_directory

    raise "#{relative_to_root(path)}: symbolic links are not allowed" if File.symlink?(path)
    File.file?(path)
  end.sort
end

def stable_fingerprint(path)
  path_before = File.lstat(path)
  raise "#{relative_to_root(path)}: symbolic links are not allowed" if path_before.symlink?

  digest = Digest::SHA256.new
  bytes = 0
  io_before = nil
  io_after = nil
  File.open(path, "rb") do |file|
    io_before = file.stat
    while (chunk = file.read(1024 * 1024))
      digest.update(chunk)
      bytes += chunk.bytesize
    end
    io_after = file.stat
  end
  path_after = File.lstat(path)
  stable_fields = %i[dev ino size mtime ctime]
  stable = stable_fields.all? do |field|
    path_before.public_send(field) == io_before.public_send(field) &&
      io_before.public_send(field) == io_after.public_send(field) &&
      io_after.public_send(field) == path_after.public_send(field)
  end
  unless stable && bytes == io_after.size && !path_after.symlink?
    raise "#{relative_to_root(path)}: file changed while its manifest entry was generated"
  end

  [digest.hexdigest, bytes]
end

def manifest_content(archive_directory)
  body = archive_files(archive_directory).map do |path|
    relative_path = canonical_relative_path(path, archive_directory)
    digest, bytes = stable_fingerprint(path)
    "#{digest}  #{bytes}  #{relative_path}\n"
  end.join
  HEADER + body
end

def write_atomically(path, content)
  directory = File.dirname(path)
  temporary = Tempfile.new(["archive-manifest", ".tmp"], directory)
  begin
    temporary.binmode
    temporary.write(content)
    temporary.flush
    temporary.fsync
    temporary.chmod(0o644)
    temporary.close
    File.rename(temporary.path, path)
  ensure
    temporary.close! if File.exist?(temporary.path)
  end
end

unless File.directory?(RUNS_ROOT) && !File.symlink?(RUNS_ROOT)
  warn "ERROR: evals/runs must be a real directory"
  exit 1
end

runs_root_real = File.realpath(RUNS_ROOT)
targets = if ARGV.empty?
            Dir.glob(File.join(RUNS_ROOT, "*")).select { |path| File.directory?(path) }.sort
          else
            ARGV.map { |path| File.expand_path(path, ROOT) }
          end

if targets.empty?
  warn "ERROR: no evidence archives found"
  exit 1
end

failures = 0
targets.each do |archive_directory|
  begin
    unless File.directory?(archive_directory) && !File.symlink?(archive_directory) &&
           File.dirname(File.realpath(archive_directory)) == runs_root_real
      raise "target must be one archive directory directly under evals/runs"
    end

    expected = manifest_content(archive_directory)
    manifest_path = File.join(archive_directory, MANIFEST_NAME)
    relative_manifest = relative_to_root(manifest_path)
    if options[:check]
      if File.file?(manifest_path) && !File.symlink?(manifest_path) && File.binread(manifest_path) == expected
        puts "OK: #{relative_manifest}"
      else
        warn "STALE: #{relative_manifest}"
        failures += 1
      end
    else
      write_atomically(manifest_path, expected)
      puts "updated #{relative_manifest}"
    end
  rescue SystemCallError, RuntimeError => e
    warn "ERROR: #{relative_to_root(archive_directory)}: #{e.message}"
    failures += 1
  end
end

exit 1 if failures.positive?
