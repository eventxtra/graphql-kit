module GraphqlKit
  module ActAsPolymorphicInput
    # Allows an InputObject to receive inputs with more than one shape/type
    # at different times, while keeping argument inputs strongly-typed.
    #
    # A enum-typed field `type` would be used for locating the strongly-typed
    # argument value, it would be snake_cased before matching.
    # Any other argument fields which does not match `type` should be null.
    #
    # Queries would be validated against the above rule and those failed
    # validation would be rejected by raising `GraphQL::ExecutionError` error.
    #
    # For example:
    #   For an InputObject with schema:
    #     { type: enum(STRING_VALUE, INT_VALUE), string_value: String, int_value: Integer }
    #
    #   Inputs below would pass validation:
    #     { type: STRING_VALUE, string_value: "Hello World" }
    #     { type: STRING_VALUE, string_value: "" }
    #     { type: INT_VALUE, int_value: 42 }
    #
    #   Inputs below would fail validation:
    #     { type: STRING_VALUE, int_value: 42 }
    #     { type: INT_VALUE, string_value: "Hello World" }
    #     { type: STRING_VALUE }
    #     { type: STRING_VALUE, string_value: "Hello World", int_value: 42 }
    #

    def validate
      polymorphic_argument_names = keys.without(:type)
      polymorphic_argument_names.each do |argument_name|
        should_be_blank = argument_name != symbolized_type
        argument_input = send(argument_name)
        next if argument_input.nil? == should_be_blank

        graphql_name = self.class.graphql_name
        should_humanized = should_be_blank ? "should be blank" : "should not be blank"
        raise GraphQL::ExecutionError,
          "polymorphic argument #{argument_name} for #{graphql_name} #{should_humanized}"
      end
      true
    end

    def value
      validate && send(symbolized_type)
    end

    def symbolized_type
      @symbolized_type ||= type.underscore.to_sym
    end
  end
end
