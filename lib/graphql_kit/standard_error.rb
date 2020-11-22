module GraphqlKit::StandardError
  class StandardErrorPathSegmentScalar < GraphQL::Schema::Scalar
    graphql_name 'StandardErrorPathSegment'
    description 'Standard error key path, could be either a String or Int'

    def self.coerce_input(input_value, _context)
      return if input_value.nil?

      if [String, Integer].all? { |type| !input_value.is_a?(type) }
        raise GraphQL::CoercionError,
          "#{input_value.inspect} is not a String or Int"
      end
    end

    def self.coerce_result(ruby_value, _context)
      if [String, Integer, Symbol].all? { |type| !ruby_value.is_a?(type) }
        raise GraphQL::CoercionError,
          "expecting String, Integer or Symbol, #{ruby_value.inspect} is given"
      end
      ruby_value
    end
  end

  class ErrorDetailType < GraphQL::Schema::Object
    graphql_name 'StandardErrorDetail'
    description 'Standard error detail'

    field :key, 'String', null: false
    field :value, 'String', null: true
  end

  class StandardErrorType < GraphQL::Schema::Object
    graphql_name 'StandardError'
    description 'Standard error information'

    field :type, 'String', null: true
    field :path, [StandardErrorPathSegmentScalar], null: false
    field :message, 'String', null: false
    field :details, [ErrorDetailType], null: false
  end
end
