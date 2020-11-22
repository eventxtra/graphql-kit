class GraphqlKit::Context < GraphQL::Query::Context
  delegate id_of_object: 'schema.object_resolver',
           object_by_id: 'schema.object_resolver',
           objects_by_ids: 'schema.object_resolver'

  def current_ability
    raise NoMethodError, 'method `current_ability` not implemented'
  end
end
