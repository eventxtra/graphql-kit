module GraphqlKit::Schema
  extend ActiveSupport::Concern

  class_methods do
    include Memoizer

    def guid_coder
      GraphqlKit::GuidCoder.new
    end

    def type_mapper
      GraphqlKit::TypeMapper.from_schema(self)
    end

    def object_resolver
      GraphqlKit::ObjectResolver.new(
        schema: self,
        type_mapper: type_mapper,
        guid_coder: guid_coder
      )
    end

    memoize :guid_coder
    memoize :type_mapper
    memoize :object_resolver

    # Resolve to GraphQL from object for interface types (eg. `Node` interface)
    def resolve_type(_type, obj, _ctx)
      object_resolver.type_of_object(obj)
    end

    def id_from_object(object, _type_definition, _query_ctx)
      object_resolver.id_of_object(object)
    end

    def object_from_id(id, _query_ctx)
      object_resolver.object_by_id(id)
    end

    delegate :type_of_object, :id_of_object, :object_by_id, :objects_by_ids, to: :object_resolver
  end
end
