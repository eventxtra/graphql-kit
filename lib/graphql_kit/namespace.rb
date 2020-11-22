module GraphqlKit
  module Namespace
    def self.included(namespace)
      namespace.extend ClassMethods
      namespace.const_set('Shared', make_shared_module(namespace))
    end

    def self.make_shared_module(namespace)
      Module.new do
        extend ActiveSupport::Concern

        included do |base|
          base.const_set 'Types', namespace::Types
          base.const_set 'Mutations', namespace::Mutations
        end

        define_method :gqt, &namespace.method(:gqt)

        def raw_object(type:, **hash)
          unless type.respond_to?(:graphql_name)
            raise 'type is not a valid graphql type'
          end

          type.raw_object(hash)
        end

        def recordset_map_each(recordset, &transformer)
          GraphqlKit::RecordsetMapEachConnection::Adapter.new(recordset, &transformer)
        end

        class_methods do
          define_method :gqt, &namespace.method(:gqt)

          define_method :schema do
            namespace::Schema
          end
        end
      end
    end

    module ClassMethods
      def graphql_type(input)
        graphql_namespace = self
        graphql_namespace_name = self.name
        case input
        when GraphQL::BaseType
          input.metadata[:type_class]
        when Symbol
          name = input.to_s.gsub('_', '::')
          "#{graphql_namespace_name}::Types::#{name}Type".constantize
        when String
          gqt(graphql_namespace::Schema.types[input])
        when Module
          input
        end
      end

      alias gqt graphql_type
    end
  end
end
