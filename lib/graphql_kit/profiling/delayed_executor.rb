module GraphqlKit::Profiling
  class DelayedExecutor
    def initialize
      begin
        require 'fc'
      rescue
        raise 'gem "priority_queue_cxx" is required'
      end
      reset
    end

    def run_delayed(delay, &work)
      reset_if_forked
      work_id = synchronize do
        enqueue_work_at_time(work, time_now + delay)
      end
      wake_to_work
      work_id
    end

    def cancel(work_id)
      reset_if_forked
      work = synchronize { @works.delete(work_id) }
      !work.nil?
    end

    def shutdown
      reset_if_forked
      @executor.kill
    end

    delegate :alive?, to: :@executor

    private

    def run_executor
      loop do
        sleep if synchronize { idle? }

        ready_work = synchronize do
          pop_next_work if next_work_in <= 0.01
        end
        post_work(ready_work) if ready_work

        sleep(synchronize { next_work_in })
      end
    end

    def post_work(work)
      @work_executor.run_queued(&work)
    end

    def sleep_await_next_work(duration)
      sleep(duration)
    end

    def enqueue_work_at_time(work, time)
      work_id = @incr_id
      @incr_id += 1
      @works[work_id] = work
      @pqueue.push(work_id, time)
      work_id
    end

    def wake_to_work
      synchronize { @executor.wakeup }
    end

    def next_work_time
      @pqueue.top_key
    end

    def next_work_in
      return 1 if next_work_time.nil?

      duration = next_work_time - time_now
      duration.positive? ? duration : 0
    end

    def pop_next_work
      @works.delete(@pqueue.pop) unless @pqueue.empty?
    end

    def idle?
      @works.empty?
    end

    delegate :synchronize, to: :@mutex

    def time_now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def reset_if_forked
      reset if $PROCESS_ID != @pid
    end

    def reset
      @pid = $PROCESS_ID
      @incr_id = 0
      @works = {}
      @mutex = Mutex.new
      @pqueue = FastContainers::PriorityQueue.new(:min)
      @work_executor = QueuedExecutor.new
      @executor = Thread.new { run_executor }
    end
  end
end
