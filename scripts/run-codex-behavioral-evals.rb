#!/usr/bin/env ruby
# Compatibility entry point for the shared Codex behavioral runner.

ENV["ZSTACK_BEHAVIORAL_HOST"] = "codex"
load File.expand_path("run-behavioral-evals.rb", __dir__)
