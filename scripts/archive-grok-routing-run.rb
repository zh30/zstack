#!/usr/bin/env ruby
# Grok Build entry point for the shared routing archiver.

ENV["ZSTACK_ROUTING_HOST"] = "grok"
load File.expand_path("archive-routing-run.rb", __dir__)
