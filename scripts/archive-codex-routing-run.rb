#!/usr/bin/env ruby
# Compatibility entry point for the shared Codex routing archiver.

ENV["ZSTACK_ROUTING_HOST"] = "codex"
load File.expand_path("archive-routing-run.rb", __dir__)
