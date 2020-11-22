module GraphqlKit::AutoBatchLoadingRelationConnectionExtension
  def self.included(base)
    base.include InstanceMethods
    base.extend ClassMethods
  end

  module ClassMethods
    def connection_loader
      GraphqlKit::AssociationConnectionLoader
    end
  end

  module InstanceMethods
    def nodes
      after_lazy_nodes { super }
    end

    def edges
      after_lazy_nodes { super }
    end

    def start_cursor
      after_lazy_nodes { super }
    end

    def end_cursor
      after_lazy_nodes { super }
    end

    private

    def can_lazy?
      @can_lazy ||= connection_loader.can_load?(assoc_query)
    end

    def will_lazy?
      can_lazy? && !@loaded
    end

    def after_lazy_nodes(&callback)
      will_lazy? ? lazy_load(&callback) : callback.call
    end

    def lazy_load(&callback)
      connection_loader.load(assoc_query).then do |loaded_records|
        @nodes ||= loaded_records
        @loaded = true
        callback.call
      end
    end

    def load_nodes
      super unless can_lazy?
    end

    def self.included(base)
      base.instance_exec do
        attr_reader :loaded_records
        alias_method :assoc_query, :limited_nodes

        delegate :connection_loader, to: :class
      end
    end
  end
end
