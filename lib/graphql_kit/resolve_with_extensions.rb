module GraphqlKit::ResolveWithExtensions
  def resolve(obj, args, ctx)
    with_extensions(obj, args, ctx) do |extended_obj, extended_args|
      super(extended_obj, extended_args, ctx)
    end
  end

  def self.apply_on(field)
    clone_field(field).tap { |cloned| apply_on! cloned }
  end

  def self.clone_field(field)
    field.clone.tap do |cloned|
      ['@extras', '@extensions', '@own_arguments'].each do |ivar_name|
        ivar_val = cloned.instance_variable_get(ivar_name)
        cloned.instance_variable_set(ivar_name, ivar_val.clone)
      end
      instance_variable_set('@graphql_definition', nil)
    end
  end

  def self.apply_on!(field)
    field.singleton_class.prepend self
  end
end
