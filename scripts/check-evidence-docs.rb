#!/usr/bin/env ruby
# Keep visible current-source evidence claims aligned with archived coverage.

require "json"
require "optparse"
require "rbconfig"
require_relative "lib/eval_bounded_command"
require_relative "lib/eval_input_file"
require_relative "lib/eval_limits"

ROOT = File.expand_path("..", __dir__)
REPORTER = File.join(ROOT, "scripts", "report-evidence-coverage.rb")
DEFAULT_DOCUMENTS = [
  File.join(ROOT, "README.md"),
  File.join(ROOT, "README.zh-CN.md"),
  File.join(ROOT, "docs", "compatibility.md")
].freeze
START_MARKER = "<!-- zstack-current-evidence:start -->"
END_MARKER = "<!-- zstack-current-evidence:end -->"

def load_report(suite)
  result = Zstack::EvalBoundedCommand.capture(
    RbConfig.ruby,
    REPORTER,
    "--suite",
    suite,
    "--json",
    chdir: ROOT,
    timeout_seconds: Zstack::EvalLimits::EVIDENCE_REPORT_TIMEOUT_SECONDS,
    max_output_bytes: Zstack::EvalLimits::MAX_EVIDENCE_REPORT_OUTPUT_BYTES
  )
  if result.timed_out
    raise "coverage reporter timed out for #{suite} after #{Zstack::EvalLimits::EVIDENCE_REPORT_TIMEOUT_SECONDS} seconds"
  end
  if result.output_limited
    raise "coverage reporter exceeded #{Zstack::EvalLimits::MAX_EVIDENCE_REPORT_OUTPUT_BYTES} output bytes for #{suite}"
  end
  unless result.status.success?
    detail = result.stderr.strip
    detail = "exit #{result.status.exitstatus}" if detail.empty?
    raise "coverage reporter failed for #{suite}: #{detail}"
  end

  JSON.parse(result.stdout)
rescue JSON::ParserError => e
  raise "coverage reporter returned invalid #{suite} JSON: #{e.message}"
end

def host_current(report, host_family)
  host = Array(report["hosts"]).find { |entry| entry["hostFamily"] == host_family }
  raise "coverage report is missing host family #{host_family}" unless host

  count = host["currentCompletePassingCases"]
  raise "coverage report has an invalid current count for #{host_family}" unless count.is_a?(Integer)

  count
end

def suite_status(report)
  total = report.dig("summary", "cases")
  raise "coverage report has an invalid case total" unless total.is_a?(Integer) && total.positive?

  {
    "total" => total,
    "claude" => host_current(report, "claude"),
    "codex" => host_current(report, "codex"),
    "grok" => host_current(report, "grok")
  }
end

def status_block(behavioral, routing, language)
  if language == :zh
    return <<~MARKDOWN.strip
      #{START_MARKER}
      当前源码证据：Claude 行为 **#{behavioral.fetch("claude")}/#{behavioral.fetch("total")}**，
      Codex 行为 **#{behavioral.fetch("codex")}/#{behavioral.fetch("total")}**，Grok 行为
      **#{behavioral.fetch("grok")}/#{behavioral.fetch("total")}**；Claude 路由 **#{routing.fetch("claude")}/#{routing.fetch("total")}**，
      Codex 路由 **#{routing.fetch("codex")}/#{routing.fetch("total")}**，Grok 路由 **#{routing.fetch("grok")}/#{routing.fetch("total")}**。
      #{END_MARKER}
    MARKDOWN
  end

  <<~MARKDOWN.strip
    #{START_MARKER}
    Current-source evidence: Claude behavior **#{behavioral.fetch("claude")}/#{behavioral.fetch("total")}**,
    Codex behavior **#{behavioral.fetch("codex")}/#{behavioral.fetch("total")}**, Grok behavior
    **#{behavioral.fetch("grok")}/#{behavioral.fetch("total")}**; Claude routing **#{routing.fetch("claude")}/#{routing.fetch("total")}**,
    Codex routing **#{routing.fetch("codex")}/#{routing.fetch("total")}**, Grok routing **#{routing.fetch("grok")}/#{routing.fetch("total")}**.
    #{END_MARKER}
  MARKDOWN
end

documents = []
parser = OptionParser.new do |opts|
  opts.banner = "Usage: ruby scripts/check-evidence-docs.rb [--document PATH ...]"
  opts.on("--document PATH", "Check this document instead of the defaults; repeatable") do |path|
    documents << File.expand_path(path)
  end
  opts.on("-h", "--help", "Show help") do
    puts opts
    exit 0
  end
end

begin
  parser.parse!
  raise "unexpected positional arguments: #{ARGV.join(" ")}" unless ARGV.empty?
  documents = DEFAULT_DOCUMENTS if documents.empty?

  behavioral = suite_status(load_report("behavioral"))
  routing = suite_status(load_report("routing"))
  block_pattern = /#{Regexp.escape(START_MARKER)}.*?#{Regexp.escape(END_MARKER)}/m
  errors = []

  documents.each do |path|
    label = path.start_with?("#{ROOT}/") ? path.delete_prefix("#{ROOT}/") : path
    language = File.basename(path) == "README.zh-CN.md" ? :zh : :en
    expected = status_block(behavioral, routing, language)
    content = Zstack::EvalInputFile.read(
      path,
      label: "evidence document #{label}",
      root: File.dirname(path)
    )
    if content.scan(START_MARKER).length != 1 || content.scan(END_MARKER).length != 1
      errors << "#{label}: expected exactly one current-evidence marker pair"
      next
    end

    actual = content.match(block_pattern)&.[](0)&.gsub("\r\n", "\n")
    unless actual == expected
      errors << "#{label}: current-evidence block is stale; run the coverage report and update the marked block\nExpected block:\n#{expected}"
    end
  rescue Zstack::EvalInputFile::ReadError => e
    errors << "#{label}: cannot read document safely: #{e.message}"
  end

  unless errors.empty?
    warn errors.join("\n")
    exit 1
  end

  puts "documented current evidence: behavior claude=#{behavioral.fetch("claude")}/#{behavioral.fetch("total")} codex=#{behavioral.fetch("codex")}/#{behavioral.fetch("total")} grok=#{behavioral.fetch("grok")}/#{behavioral.fetch("total")}; routing claude=#{routing.fetch("claude")}/#{routing.fetch("total")} codex=#{routing.fetch("codex")}/#{routing.fetch("total")} grok=#{routing.fetch("grok")}/#{routing.fetch("total")}"
rescue StandardError => e
  warn e.message
  exit 1
end
