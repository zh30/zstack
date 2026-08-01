#!/usr/bin/env ruby
# Thin Grok adapter for the shared behavioral runner.

ENV["ZSTACK_BEHAVIORAL_HOST"] = "grok"
load File.expand_path("run-behavioral-evals.rb", __dir__)
