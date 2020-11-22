class GraphqlKit::RawObject < OpenStruct
  def initialize(hash)
    super(hash)
    unless type.respond_to?(:graphql_name)
      raise 'type is not a valid graphql type'
    end

    self.type = self.type.graphql_name
  end

  delegate :slice, to: :to_h
end
