#!/usr/bin/env ruby
# Grok Build entry point for the shared routing runner.

ENV["ZSTACK_ROUTING_HOST"] = "grok"
load File.expand_path("run-routing-evals.rb", __dir__)
