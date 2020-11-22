class GraphqlKit::RecordsetMapEachConnection < GraphQL::Relay::BaseConnection
  def self.register_as_connection_implementation
    GraphQL::Relay::BaseConnection.register_connection_implementation(
      GraphqlKit::RecordsetMapEachConnection::Adapter,
      GraphqlKit::RecordsetMapEachConnection
    )
  end

  alias adapter nodes

  def initialize(adapter, *args)
    super(adapter, *args)
    @relation_connection = GraphQL::Relay::RelationConnection.new(
      adapter.record_set, *args
    )
  end

  delegate :cursor_from_node, to: :@relation_connection

  private

  def paged_nodes
    @relation_connection.edge_nodes.map do |record|
      adapter.transformer.call(record)
    end
  end

  def sliced_nodes
    # only paged_nodes is called in graphql gem's code so this is not needed
    raise NotImplementedError, 'not expected to be called since only paged_nodes is needed'
  end

  class Adapter
    attr_accessor :record_set
    attr_accessor :transformer

    def initialize(record_set, &transformer)
      @record_set = record_set
      @transformer = transformer
    end
  end
end
