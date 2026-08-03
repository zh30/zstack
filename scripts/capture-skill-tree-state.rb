#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "lib/skill_tree_state"

snapshot_root = nil
if ARGV.first == "--snapshot"
  ARGV.shift
  snapshot_root = ARGV.shift
end

unless ARGV.length == 1 && (snapshot_root.nil? || !snapshot_root.empty?)
  warn "Usage: ruby scripts/capture-skill-tree-state.rb [--snapshot SNAPSHOT_ROOT] SKILLS_ROOT"
  exit 2
end

begin
  puts Zstack::SkillTreeState.capture(ARGV.fetch(0), snapshot_root: snapshot_root)
rescue Zstack::SkillTreeState::CaptureError, ArgumentError => e
  warn "ERROR: skill tree state capture failed: #{e.message}"
  exit 1
end
