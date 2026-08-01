#!/usr/bin/env ruby
# Compatibility entry point for the shared Codex behavioral archiver.

ENV["ZSTACK_BEHAVIORAL_HOST"] = "codex"
load File.expand_path("archive-behavioral-run.rb", __dir__)
