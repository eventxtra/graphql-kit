module GraphqlKit::Profiling
  class ProfilingDataCollector
    def initialize(&after_collection_proc)
      raise ArgumentError, 'after collection proc must be given' unless block_given?

      @after_collection_proc = after_collection_proc
    end

    def before_query(query)
      initialize_result_set(query)
    end

    def after_query(query)
      profiling_data = conclude_result_set(query)
      return if profiling_data.nil?

      @after_collection_proc.call(profiling_data)
    end

    def collect_benchmark(query:, key:, time:, divisor:)
      result_set_for(query)&.add_entry(key, time, divisor)
    end

    private

    def result_set_store
      RequestStore.store[self.class] ||= {}
    end

    def initialize_result_set(query)
      result_set_store[query] = BenchmarkResultSet.new
    end

    def result_set_for(query)
      result_set_store[query]
    end

    def conclude_result_set(query)
      result_set_store.delete(query)
    end
  end
end
