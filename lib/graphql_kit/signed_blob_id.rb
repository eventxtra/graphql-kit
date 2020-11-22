class GraphqlKit::SignedBlobId < GraphQL::Schema::Scalar
  graphql_name 'SignedBlobID'
  description "Signed blob ID generated via `createDirectUpload` mutation"

  def self.coerce_input(input_value, _context)
    return if input_value.nil?

    if input_value.is_a?(String)
      input_value
    else
      raise GraphQL::CoercionError, "SignedBlobID must be a string"
    end
  end

  def self.coerce_result(ruby_value, _context)
    ruby_value
  end
end
