# frozen_string_literal: true

# JSON objects with repeated keys are ambiguous to humans even though Ruby's
# default parser silently keeps the last value. Evidence inputs must fail closed.

require "json"

module Zstack
  module EvalStrictJson
    class DuplicateKeyError < JSON::ParserError; end

    class Object < Hash
      def []=(key, value)
        raise DuplicateKeyError, "duplicate JSON object key" if key?(key)

        super
      end
    end

    module_function

    def parse(source, **options)
      raise ArgumentError, "object_class is reserved for strict JSON parsing" if options.key?(:object_class)

      JSON.parse(source, **options, object_class: Object)
    end
  end
end
