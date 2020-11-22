class GraphqlKit::BaseMutationCommand
  include ActiveModel::Model
  include Memoizer

  class_attribute :input_fields
  class_attribute :output_fields
  class_attribute :output_preprocessors
  class_attribute :exec_proc

  self.input_fields ||= []
  self.output_fields ||= []
  self.output_preprocessors = {}

  def self.inputs(*input_fields)
    input_fields.collect!(&:to_s)
    input_fields.each do |input_field|
      attr_accessor input_field
    end
    self.input_fields += input_fields
    self.input_fields.uniq!

    input_fields
  end

  def self.outputs(*output_fields)
    output_fields.collect!(&:to_s)
    output_fields.each do |output_field|
      attr_accessor output_field unless method_defined?(output_field)
    end
    self.output_fields += output_fields
    self.output_fields.uniq!

    output_fields
  end

  def self.preprocesses_output(output_field, &processor_proc)
    output_field = output_field.to_s

    self.output_preprocessors = output_preprocessors.merge(
      output_field => processor_proc
    )

    output_field
  end

  def self.memoizes(field, &value_proc)
    define_method(field, &value_proc)
    memoize field

    field
  end

  # populates a memoized field `field` which is loaded from `finder` using `by`
  # when `requried` is true, it will set up a validator which emits error for
  # id field name `by` when result of `field` is blank
  def self.finds(field, by:, finder:, required: false)  # rubocop:disable Naming/UncommunicativeMethodParamName
    id_field_name = by
    finder_proc = finder

    memoizes(field) do
      graphql_id = send(:"#{id_field_name}")
      object_finder = instance_exec(&finder_proc)
      context.object_by_id(graphql_id, finder: object_finder)
    end

    if required
      validator_name = :"validate_#{id_field_name}"
      define_method(validator_name) do
        object_found = send(:"#{field}")
        errors.add(:"#{id_field_name}", :invalid) if object_found.blank?
      end
      validate validator_name
    end

    field
  end

  def self.validates_can(ability, object_field)
    validator_name = :"validate_#{object_field}_#{ability}_ability"
    define_method(validator_name) do
      object = send(:"#{object_field}")
      unless current_ability.can?(ability, object)
        errors.add(:"#{object_field}", :no_permission,
          ability: ability)
      end
    end
    validate validator_name
  end

  def self.execute(&exec_proc)
    self.exec_proc = exec_proc
  end

  inputs :context, :error_encoder
  outputs :success, :errors

  preprocesses_output(:errors) { |output| error_encoder.encode(output) }

  def initialize(*args)
    super(*args)
    fail!
  end

  def call
    valid? and exec
  end

  def command_output
    output_fields.collect do |output_field|
      preprocessor = output_preprocessors[output_field] || proc(&:itself)

      key = output_field
      value_before_preprocess = send(:"#{output_field}")
      value = instance_exec(value_before_preprocess, &preprocessor)

      [key, value]
    end.to_h
  end

  protected

  delegate :current_ability, :current_identity, to: :context

  def accessible_objects_of(klass)
    klass.accessible_by current_ability
  end

  def exec
    raise ArgumentError, 'execute block not declared' unless exec_proc

    instance_exec(&exec_proc)
  end

  def succeed!
    self.success = true
  end

  def fail!
    self.success = false
  end
end
