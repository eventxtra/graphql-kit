class GraphqlKit::AssociationCountLoader < GraphQL::Batch::Loader
  class << self
    def can_load?(assoc_query)
      begin
        assert_loadable(assoc_query)
        true
      rescue
        false
      end
    end

    def load(assoc_query)
      return if assoc_query.nil?

      assert_loadable(assoc_query)

      loader_kwargs = {
        offset: nil,
        limit: nil,
        order: assoc_query.values[:order]&.map { |x| x.try(:to_sql) || x }.presence
      }.merge assoc_query.values.slice(:offset, :limit)

      assoc_reflect = assoc_query.proxy_association.reflection
      self.for(assoc_reflect, **loader_kwargs).load(assoc_query)
    end

    private

    def assert_loadable(assoc_query)
      unless assoc_query.respond_to?(:proxy_association)
        raise ArgumentError, [
          'unsupported object type: ',
          assoc_query.class.name,
          ', expected it to respond to `proxy_association`'
        ].join
      end

      proxy_assoc = assoc_query.proxy_association
      unless identical_wheres(assoc_query, proxy_assoc.scope)
        raise ArgumentError, "`where` predicates are not supported, received predicate: #{assoc_query.arel.where_sql} when attempting to batch load `#{assoc_query.klass.name}`"
      end
    end

    def identical_wheres(rel_a, rel_b)
      rel_a.values[:where] == rel_b.values[:where]
    end
  end

  attr_reader :assoc, :order, :offset, :limit

  def initialize(assoc, order:, offset:, limit:)
    @assoc = assoc
    @order = order
    @offset = offset
    @limit = limit
  end

  def perform(assoc_queries)
    assoc_query = assoc_queries.first
    from_record_ids = assoc_queries.collect { |x| x.proxy_association.owner.id }

    foreign_key = assoc.foreign_key
    table_name = assoc.table_name
    full_foreign_column = %{"#{table_name}"."#{foreign_key}"}

    list_results = assoc_query
      .unscope(:select, :order, :offset, :limit, where: [foreign_key])
      .select(full_foreign_column, 'COUNT(*) AS "count"')
      .where(foreign_key => from_record_ids)
      .group(full_foreign_column)

    indexed_results = list_results
      .index_by(&:"#{foreign_key}")
      .transform_values(&:count)

    assoc_queries.each do |assoc_query|
      group_id = assoc_query.proxy_association.owner.id
      result = indexed_results[group_id] || 0
      fulfill(assoc_query, result)
    end
  end
end
