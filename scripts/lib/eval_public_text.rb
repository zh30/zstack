# frozen_string_literal: true

module Zstack
  module EvalPublicText
    MACHINE_LOCAL_PATH = %r{
      (?:\A|[[:space:]`"'(=])
      (?:
        /Users/|
        /home/|
        /tmp/|
        /private/tmp/|
        /var/folders/|
        /private/var/folders/|
        [A-Za-z]:\\Users\\
      )
    }x.freeze

    module_function

    def machine_local_path?(text)
      text.is_a?(String) && text.match?(MACHINE_LOCAL_PATH)
    end
  end
end
