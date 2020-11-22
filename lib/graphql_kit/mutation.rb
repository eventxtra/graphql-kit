module GraphqlKit::Mutation
  extend ActiveSupport::Concern

  class_methods do
    def resolves_with_command(&class_body)
      mutation_arguments = arguments.values.collect(&:keyword)
      cmd_klass = Class.new(GraphqlKit::BaseMutationCommand, &class_body)
      cmd_klass.instance_exec do
        inputs(*mutation_arguments)
      end
      const_set('Command', cmd_klass)
      include begin
        Module.new do
          define_method(:resolve) do |args = {}|
            execute_command(cmd_klass, args).command_output
          end
        end
      end

      field :success, 'Boolean', null: false,
        description: 'Whether the operation is successful'
      field :errors, [GraphqlKit::StandardError::StandardErrorType], null: false,
        description: 'Errors occured during the operation'
    end
  end

  def execute_command(cmd_klass, args)
    cmd_args = args.merge(context: context, error_encoder: error_encoder)
    cmd_klass.new(cmd_args).tap(&:call)
  end

  def error_encoder
    @error_encoder ||= begin
      error_base_path = self.class.graphql_name.camelize(:lower)
      GraphqlKit::MutationErrorEncoder.new(error_base_path)
    end
  end
end
