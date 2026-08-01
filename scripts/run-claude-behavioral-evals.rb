#!/usr/bin/env ruby
# Claude Code entry point for the shared behavioral runner.

ENV["ZSTACK_BEHAVIORAL_HOST"] = "claude"
load File.expand_path("run-behavioral-evals.rb", __dir__)
