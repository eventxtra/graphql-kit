class GraphqlKit::FieldProfiler < GraphQL::Schema::FieldExtension
  def resolve(object:, arguments:, context:)
    yield(object, arguments, now)
  end

  def after_resolve(value:, object:, arguments:, context:, memo:)
    start_at = memo
    runtime_sec = now - start_at

    on_benchmark(runtime_sec, arguments, value, context)

    value
  end

  def on_benchmark(runtime_sec, args, result, context)
    on_benchmark_callback&.call(
      query: context.query,
      key: canonical_field_name,
      time: runtime_sec,
      divisor: benchmark_divisor_for(args, result)
    )
  end

  def benchmark_divisor_for(args, result)
    benchmark_divisor_evaluator&.call(args, result) || 1
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
    @options[:override_field_owner]
  end

  def benchmark_divisor_evaluator
    options[:benchmark_divisor]
  end

  def on_benchmark_callback
    options[:on_benchmark]
  end

  def result_set_for(query)
    GraphqlKit::Profiling::BenchmarkResultSet.for_query(query)
  end

  def now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
