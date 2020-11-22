class GraphqlKit::ComplexityEstimator < GraphQL::Schema::FieldExtension
  def apply
    field.complexity estimated_complexity if estimated_complexity
  end

  def estimated_complexity
    @estimated_complexity ||= begin
      can_estimate? && (dynamic_complexity || fixed_complexity)
    end
  end

  def fixed_complexity
    normalized_own_complexity
  end

  def dynamic_complexity
    return unless dynamic_complexity?

    lambda do |ctx, args, normalized_child_complexity|
      own_complexity = estimate_own_complexity(ctx, args)
      child_complexity = begin
        estimate_child_complexity(ctx, args, normalized_child_complexity)
      end
      own_complexity + child_complexity
    end
  end

  def normalized_own_complexity
    complexity_data[canonical_field_name]
  end

  def can_estimate?
    normalized_own_complexity.present?
  end

  def dynamic_complexity?
    [
      own_complexity_multiplier_evaluator,
      child_complexity_multiplier_evaluator
    ].any?
  end

  def estimate_own_complexity(ctx, args)
    multiplier = own_complexity_multiplier_evaluator&.call(ctx, args) || 1
    normalized_own_complexity * multiplier
  end

  def estimate_child_complexity(ctx, args, normalized_child_complexity)
    multiplier = child_complexity_multiplier_evaluator&.call(ctx, args) || 1
    normalized_child_complexity * multiplier
  end

  def canonical_field_name
    @options[:canonical_field_name] ||= begin
      [field_owner, field].collect(&:graphql_name).join('#')
    end
  end

  def field_owner
    override_field_owner || field.owner
  end

  def override_field_owner
    options[:override_field_owner]
  end

  def own_complexity_multiplier_evaluator
    options[:own_complexity_multiplier]
  end

  def child_complexity_multiplier_evaluator
    options[:child_complexity_multiplier]
  end

  def complexity_data
    options[:complexity_data]
  end
end
