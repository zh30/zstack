#!/usr/bin/env ruby
# Compatibility entry point for the shared Codex routing runner.

ENV["ZSTACK_ROUTING_HOST"] = "codex"
load File.expand_path("run-routing-evals.rb", __dir__)
