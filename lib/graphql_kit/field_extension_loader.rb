class GraphqlKit::FieldExtensionLoader < GraphQL::Schema::FieldExtension
  HAS_FIELD_TYPES = [
    GraphQL::Schema::Interface,
    GraphQL::Schema::Object
  ]

  def initialize(schema_defn, extension:, argument_evaluator:)
    @extension = extension
    @argument_evaluator = argument_evaluator

    schema_defn.types.each do |_type_name, type_defn|
      visit_type(type_defn)
    end
  end

  def self.use(schema_defn, extension:, argument_evaluator:)
    new(schema_defn, extension: extension, argument_evaluator: argument_evaluator)
  end

  private

  def visit_type(type_defn)
    return unless of_type_has_fields?(type_defn)

    type_defn.fields.each do |_field_name, field_defn|
      containing_type = type_defn
      visit_field(field_defn, containing_type)
    end
  end

  def visit_field(field_defn, containing_type)
    return if extension_already_included?(field_defn)

    attach_extension(field_defn, containing_type)
  end

  def of_type_has_fields?(type_defn)
    HAS_FIELD_TYPES.any? { |type| type_defn < type } &&
      !type_defn.introspection?
  end

  def extension_already_included?(field_defn)
    field_defn.extensions.any? do |ext|
      ext.is_a?(@extension)
    end
  end

  def attach_extension(field_defn, containing_type)
    extension_args = @argument_evaluator.call(field_defn: field_defn, containing_type: containing_type)
    field_defn.extension @extension, **extension_args
  end
end
