# frozen_string_literal: true

# Psych's safe loader prevents object construction but still accepts ambiguous
# duplicate keys and silently ignores later YAML documents. Evaluation inputs
# must have one unambiguous mapping tree before their values are trusted.

require "yaml"

module Zstack
  module EvalStrictYaml
    class ValidationError < Psych::Exception; end

    module_function

    def check_mapping_keys(node, source)
      case node
      when Psych::Nodes::Mapping
        seen = {}
        node.children.each_slice(2) do |key_node, value_node|
          unless key_node.is_a?(Psych::Nodes::Scalar)
            raise ValidationError,
                  "#{source}:#{key_node.start_line + 1}: mapping keys must be scalars"
          end

          key = key_node.value
          if seen.key?(key)
            raise ValidationError,
                  "#{source}:#{key_node.start_line + 1}: duplicate key #{key.inspect}"
          end
          seen[key] = true
          check_mapping_keys(value_node, source)
        end
      when Psych::Nodes::Stream, Psych::Nodes::Document, Psych::Nodes::Sequence
        node.children.each { |child| check_mapping_keys(child, source) }
      end
    end

    def parse(text, source)
      syntax_tree = Psych.parse_stream(text, source)
      unless syntax_tree.children.length == 1
        raise ValidationError, "#{source}: YAML must contain exactly one document"
      end

      check_mapping_keys(syntax_tree, source)
      YAML.safe_load(
        text,
        permitted_classes: [],
        permitted_symbols: [],
        aliases: false,
        filename: source
      )
    end
  end
end
