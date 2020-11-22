module GraphqlKit::ModelResolvable
  extend ActiveSupport::Concern

  included do
    class << self
      attr_reader :model_resolve_definition

      private

      def resolvable_as(*args)
        @model_resolve_definition = ModelResolveDefinition.new(self, *args)
      end
    end
  end

  class ModelResolveDefinition
    attr_accessor :type_class
    attr_accessor :model_name
    attr_accessor :type_mapper

    def initialize(type_class, model_name, type_mapper: nil)
      self.type_class = type_class
      self.model_name = model_name
      self.type_mapper = type_mapper
    end

    def type_name
      type_class.graphql_name
    end
  end
end
