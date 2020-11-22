class GraphqlKit::AssociationConnectionLoader < GraphQL::Batch::Loader
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
    partition_record_ids = assoc_queries.collect { |x| x.proxy_association.owner.id }

    model = assoc_query.model
    table_name = assoc.table_name

    query_partitioned = assoc_query
      .unscope(:limit, :offset, where: [paritition_column.column])
      .where(paritition_column.unquoted => partition_record_ids)
      .select(
        [
          %{ROW_NUMBER() OVER (PARTITION BY #{paritition_column.quoted}},
          begin
            assoc_query.arel.orders.collect { |x| x.try(:to_sql) || x }.join(', ')
              .then { |ordering| ordering.blank? ? '' : %{ ORDER BY #{ordering}} }
          end,
          %{) AS __row_num__}
        ].join,
        paritition_column.quoted,
        *assoc_query.arel.projections
      )

    records = model
      .select('*')
      .unscope(:where, :order, :limit, :offset)
      .from(%{(#{query_partitioned.to_sql}) AS top})
      .where(%{top.__row_num__ BETWEEN #{row_number_start} AND #{row_number_end}})

    record_groups = records.group_by(&:"#{paritition_column.column}")

    assoc_queries.each do |assoc_query|
      group_id = assoc_query.proxy_association.owner.id
      result_records = record_groups[group_id] || []
      fulfill(assoc_query, result_records)
    end
  end

  private

  TableColumn = Struct.new(:table, :column) do
    def quoted
      [quoted_table, quoted_column].join('.')
    end

    def unquoted
      [table, column].join('.')
    end

    def quoted_table
      ActiveRecord::Base.connection.quote_table_name(table)
    end

    def quoted_column
      ActiveRecord::Base.connection.quote_column_name(column)
    end
  end

  def paritition_column
    @paritition_column ||= begin
      table_name = assoc.table_name

      if assoc.is_a?(ActiveRecord::Reflection::ThroughReflection)
        partition_side = assoc.through_reflection
        TableColumn.new(partition_side.table_name, partition_side.foreign_key)
      elsif assoc.is_a?(ActiveRecord::Reflection::HasManyReflection)
        TableColumn.new(assoc.table_name, assoc.foreign_key)
      else
        raise ArgumentError, "unsupported association type #{assoc}"
      end
    end
  end

  # inclusive
  def row_number_start
    (@offset || 0) + 1
  end

  # inclusive
  def row_number_end
    (row_number_start - 1) + @limit
  end
end
