class GraphqlKit::QueryComplexityRecorder < GraphQL::Analysis::AST::QueryComplexity
  def result
    complexity = super
    query.context[:computed_query_complexity] = complexity
  end
end
