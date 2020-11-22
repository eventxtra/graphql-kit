class GraphqlKit::TypeMapper
  def initialize
    @forward_mapping = {}
    @inverse_mapping = {}
    @custom_model_type_mappers = {}
  end

  def add(gql_name, model_name, custom_type_mapper: nil)
    @forward_mapping[gql_name] = model_name
    @inverse_mapping[model_name] = gql_name

    existing_type_mapper = @custom_model_type_mappers[model_name]
    if existing_type_mapper.nil? || custom_type_mapper == existing_type_mapper
      @custom_model_type_mappers[model_name] = custom_type_mapper
    else
      raise ArgumentError, "type mapper must be the same across all model resolvable definitions of #{model_name} (when processing model resolvable definition of #{gql_name})"
    end
  end

  def add_from_schema(schema)
    schema.types.collect do |gql_name, gql_type_object|
      type_class = gql_type_object.type_class
      defn = type_class.try(:model_resolve_definition)
      next unless defn

      self.add defn.type_name, defn.model_name, custom_type_mapper: defn.type_mapper
    end
  end

  concerning :MapFromGraphqlType do
    included do
      def all_graphql_type_names
        @forward_mapping.keys
      end

      def model_name_for_graphql_type(gql_name)
        @forward_mapping[gql_name]
      end

      def model_class_for_graphql_type(gql_name)
        model_name = model_name_for_graphql_type(gql_name)
        model_name&.constantize
      end

      def model_class_compatible?(gql_name, klass)
        gql_type_model_class = model_class_for_graphql_type(gql_name)
        return false if gql_type_model_class.nil?

        # A GraphQL type is considered to be compatible with a finder if its
        # model class is equal, inherit by, or inherit the finder's model class

        # Example:
        #   Given two classes:
        #     class Superclass < ApplicationRecord; end
        #     class Subclass < Superclass; end
        #
        #   Case 1: The GraphQL ID represents a Subclass and the finder is a Superclass finder
        #           => The finder will always return instances of Superclass,
        #              the finder can be used to find instances of Subclass,
        #              hence the finder is compatible with the target GraphQL ID's type.
        #
        #   Case 2: The GraphQL ID represents a Superclass and the finder is a Subclass finder
        #           => The finder will always return instances of Subclass since ActiveRecord
        #              automatically adds `type IN ('Subclass')` condition into the query,
        #              therefore only instances of Subclass can be returned from the finder.
        #              Although the finder can only be used to find a subset of Superclass
        #              objects, the finder is still considered to be compatible with the
        #              target GraphQL ID's type.
        # Conclusion:
        #   As long as the finder is within the inheritance tree of the GraphQL ID's model
        #   class, the finder is considered to be compatible with the GraphQL ID's type.
        !(klass <=> gql_type_model_class).nil?
      end
    end
  end

  concerning :MapFromModel do
    included do
      def all_model_names
        @inverse_mapping.keys
      end

      def all_model_classes
        @inverse_mapping.keys.collect(&:constantize)
      end

      def type_from_object(obj)
        model_class = obj.class
        model_name = model_class.name

        # find directly by name first as it is more performant
        resolved_type_name = resolve_type_from_object(obj)
        return resolved_type_name if resolved_type_name

        # the model class can inherit from one of the declared model class
        # match the closest super class of `model_class`
        candidates = self.all_model_classes
        matched_parent_class = GraphqlKit::ClassUtils.closest_ancestor(model_class, candidates)
        return nil unless matched_parent_class

        save_polymorphic_model_cache child: model_name, parent: matched_parent_class.name

        resolve_type_from_object(obj)
      end

      private

      def resolve_with_mapping(obj)
        @inverse_mapping[obj.class.name]
      end

      def resolve_with_custom_mapper(obj)
        custom_type_mapper = @custom_model_type_mappers[obj.class.name]
        return nil if custom_type_mapper.nil?

        resolved_type = custom_type_mapper.type_from_object(obj)
        unless resolved_type.respond_to?(:graphql_name)
          raise ArgumentError, "unexpected `#{resolved_type.inspect}` received from custom type mapper `#{custom_type_mapper.name}`"
        end

        resolved_type.graphql_name
      end

      def resolve_type_from_object(obj)
        resolve_with_custom_mapper(obj) || resolve_with_mapping(obj)
      end

      def save_polymorphic_model_cache(child:, parent:)
        @inverse_mapping[child] = @inverse_mapping[parent]
        @custom_model_type_mappers[child] = @custom_model_type_mappers[parent]
      end
    end
  end

  def self.from_schema(schema)
    self.new.tap do |instance|
      instance.add_from_schema(schema)
    end
  end

  class CustomTypeMapper
    class << self
      def instance
        @instance ||= new
      end

      delegate :type_from_object, to: :instance
    end

    def type_from_object(_obj)
      raise NoMethodError, 'method `type_from_object` is not defined'
    end
  end
end
