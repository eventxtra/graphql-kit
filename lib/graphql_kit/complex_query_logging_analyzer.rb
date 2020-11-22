class GraphqlKit::ComplexQueryLoggingAnalyzer < GraphQL::Analysis::AST::QueryComplexity
  def result
    complexity = super

    threshold_complexity = ENV['GRAPHQL_COMPLEXITY_WARNING_THRESHOLD']&.to_i
    return if threshold_complexity.nil?

    if complexity > threshold_complexity
      message = [
        "[GraphQL Complex Query] ",
        "complexity: #{complexity} (warning threshold: #{threshold_complexity}) ",
        "query string: #{query.query_string.to_json}"
      ].join
      Rails.logger.warn(message)
    end
  end
end
