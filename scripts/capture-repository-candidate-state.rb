#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "lib/repository_candidate_state"

unless ARGV.length == 2
  warn "Usage: ruby scripts/capture-repository-candidate-state.rb ROOT NUL_INVENTORY"
  exit 2
end

begin
  puts Zstack::RepositoryCandidateState.capture(ARGV.fetch(0), ARGV.fetch(1))
rescue Zstack::RepositoryCandidateState::CaptureError, ArgumentError => e
  warn "ERROR: repository candidate state capture failed: #{e.message}"
  exit 1
end
