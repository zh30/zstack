#!/usr/bin/env ruby
# Thin Grok adapter for the shared behavioral archiver.

ENV["ZSTACK_BEHAVIORAL_HOST"] = "grok"
load File.expand_path("archive-behavioral-run.rb", __dir__)
