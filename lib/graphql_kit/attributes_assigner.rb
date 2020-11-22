class GraphqlKit::AttributesAssigner
  class_attribute :strategies, default: {}

  def self.define_strategy(name, &implementation)
    raise 'strategy implementation must be a proc' unless implementation.is_a?(Proc)

    self.strategies = strategies.merge(:"#{name}" => implementation)
  end

  def self.implementation_for_strategy(name)
    strategies[name] or raise "undefined strategy #{name}"
  end

  # default strategies
  define_strategy(:direct) { setter.call(value) }
  define_strategy(:object_from_id) do
    context = input.context
    setter.call(
      context.object_by_id(value, finder: eval_proc(finder))
    )
  end
  define_strategy(:objects_from_ids) do
    context = input.context
    setter.call(
      context.objects_by_ids(value, finder: eval_proc(finder))
    )
  end
  define_strategy(:build_object_list) do
    setter.call(
      value.collect.with_index do |subvalue, index|
        merge(
          array: value,
          array_index: index,
          value: subvalue
        ).eval_proc(factory)
      end
    )
  end

  class Builder
    def initialize(assigner, &block)
      @assigner = assigner
      instance_exec(&block)
    end

    delegate :define_assignment, to: :@assigner
    alias assign define_assignment
  end

  def initialize(&block)
    @assigners = []
    Builder.new(self, &block)
  end

  def define_assignment(name, options)
    raise 'strategy is required' if options[:strategy].nil?

    options = options.symbolize_keys
    @assigners << Assigner.new(
      implementation_for_strategy(options.delete(:strategy)),
      options.merge(
        to: name,
        from: options[:from] || name
      )
    )
  end

  delegate :implementation_for_strategy, to: :class

  def assign_attributes_to(target, input)
    @assigners.each do |assigner|
      assigner.perform_assign(target: target, input: input)
    end
    target
  end

  class Assigner
    attr_accessor :options

    def initialize(assign_proc, options)
      @assign_proc = assign_proc
      @options = options
    end

    def perform_assign(target:, input:)
      to_attr_name = @options[:to]
      from_attr_name = @options[:from]
      from_attr_value = read_input_attr(input, from_attr_name)
      return if from_attr_value.nil?

      AssignerContext.new(
        @options.merge(
          target: target, input: input,
          setter: proc do |value|
            target.send(:"#{to_attr_name}=", value)
          end,
          value: from_attr_value
        )
      ).eval_proc(@assign_proc)
    end

    private

    def read_input_attr(input, attr_name)
      input.respond_to?(:[]) ? input[attr_name] : input.send(attr_name)
    end
  end

  class AssignerContext < OpenStruct
    def merge(context_variables)
      AssignerContext.new(to_h.merge(context_variables))
    end

    def eval_proc(evaulate_proc, *args)
      instance_exec(*args, &evaulate_proc)
    end
  end

  def self.become_assigner(klass, &block)
    assigner_class = self

    assigner_mixin = klass.instance_exec do
      mod = const_set(:AttributeAssignerMethods, Module.new)
      private_constant :AttributeAssignerMethods
      include mod
      mod
    end

    assigner_mixin.instance_exec do
      define_method(:attributes_assigner) do
        assigner_class.new(&block)
      end
      define_method(:assign_attributes_to) do |target|
        attributes_assigner.assign_attributes_to(target, self)
      end
    end
  end
end
