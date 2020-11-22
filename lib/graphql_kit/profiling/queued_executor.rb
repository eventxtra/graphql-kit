module GraphqlKit::Profiling
  class QueuedExecutor
    def initialize
      reset
    end

    def run_queued(&work)
      reset_if_forked
      @queue << work
    end

    private

    def run_executor
      while work = @queue.deq
        work.call
      end
    end

    def reset_if_forked
      reset if $PROCESS_ID != @pid
    end

    def reset
      @pid = $PROCESS_ID
      @queue = Thread::Queue.new
      @executor = Thread.new { run_executor }
    end
  end
end
