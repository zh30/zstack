#!/usr/bin/env ruby
# Claude Code entry point for the shared routing archiver.

ENV["ZSTACK_ROUTING_HOST"] = "claude"
load File.expand_path("archive-routing-run.rb", __dir__)
