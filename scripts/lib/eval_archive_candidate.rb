# Bind a validated archive candidate to one exact pre-publication tree.

require_relative "eval_evidence_tree"

module Zstack
  module EvalArchiveCandidate
    Snapshot = Struct.new(:entries, keyword_init: true)

    module_function

    def capture(path)
      Snapshot.new(entries: EvalEvidenceTree.capture(path).entries).freeze
    end

    def verify!(path, expected, relocated: false)
      raise "archive candidate snapshot is invalid" unless expected.is_a?(Snapshot)

      observed = EvalEvidenceTree.capture(path).entries
      if relocated
        expected_root = root_identity(expected.entries.fetch("."))
        observed_root = root_identity(observed.fetch("."))
        expected_children = expected.entries.reject { |relative, _entry| relative == "." }
        observed_children = observed.reject { |relative, _entry| relative == "." }
        unless observed_root == expected_root && observed_children == expected_children
          raise "published archive differs from the prevalidated candidate tree"
        end
      elsif observed != expected.entries
        raise "archive candidate changed during pre-publication validation"
      end
      true
    end

    def root_identity(entry)
      %i[type dev ino uid mode].to_h { |field| [field, entry.fetch(field)] }
    end
    private_class_method :root_identity
  end
end
