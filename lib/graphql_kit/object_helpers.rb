module GraphqlKit::ObjectHelpers
  extend ActiveSupport::Concern

  class_methods do
    def raw_object(hash)
      GraphqlKit::RawObject.new(type: self, **hash)
    end

    def implements?(interface_type)
      interface_type = gqt(interface_type)
      gqltype_object = schema.types[graphql_name]
      interface_type_object = schema.types[interface_type&.graphql_name]
      gqltype_object.interfaces.include?(interface_type_object)
    end
  end
end
