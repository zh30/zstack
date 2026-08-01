#!/usr/bin/env ruby
# Claude Code entry point for the shared routing runner.

ENV["ZSTACK_ROUTING_HOST"] = "claude"
load File.expand_path("run-routing-evals.rb", __dir__)
