module GraphqlKit::Profiling
  class BenchmarkResultSet
    def initialize
      @benchmarks = []
    end

    def add_entry(field, time, divisor)
      @benchmarks << BenchmarkEntry.new(field.to_sym, time, divisor)
    end

    def benchmarks
      @benchmarks.freeze
    end

    delegate_missing_to :@results
  end
end
