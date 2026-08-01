#!/usr/bin/env ruby
# Claude Code entry point for the shared behavioral archiver.

ENV["ZSTACK_BEHAVIORAL_HOST"] = "claude"
load File.expand_path("archive-behavioral-run.rb", __dir__)
