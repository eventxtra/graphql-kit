module GraphqlKit::Profiling
  class LossyBatchedEmitter
    attr_reader :batch_size
    attr_reader :min_emit_interval
    attr_reader :max_emit_interval
    attr_reader :capacity
    attr_reader :last_emitted

    def initialize(
      min_emit_interval:,
      max_emit_interval:,
      batch_size:,
      capacity:,
      &emit_block
    )
      @min_emit_interval = min_emit_interval
      @max_emit_interval = max_emit_interval
      @batch_size = batch_size
      @capacity = capacity

      @items = []
      @mutex = Mutex.new
      @executor = DelayedExecutor.new
      @last_emitted = nil
      @emit_block = emit_block

      @emit_later_work = nil
      @underfilled_emit_work = nil
    end

    def push(batch)
      run_queued do
        synchronize do
          @items.concat(batch)
          drop_items_if_full
          decide_next_step
        end
      end
    end

    delegate :shutdown, :alive, to: :@executor

    delegate :empty?, :size, :count, to: :@items

    private

    delegate :synchronize, to: :@mutex
    delegate :run_delayed, :cancel, to: :@executor

    def run_queued(&block)
      run_delayed(0, &block)
    end

    def full_batch_available?
      @items.size >= batch_size
    end

    def throttle_delay
      @last_emitted ? @last_emitted + min_emit_interval - time_now : 0
    end

    def time_now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def fullness
      [@items.size - capacity, 0].max
    end

    def emit_batch(batch)
      run_queued do
        @emit_block.call(batch)
      end
    end

    def emit_single_batch
      run_queued do
        synchronize do
          cancel(@underfilled_emit_work)
          cancel(@emit_later_work)
          @underfilled_emit_work = nil
          @emit_later_work = nil

          break if empty? || try_again_later

          emit_batch @items.slice!(0, batch_size)
          @last_emitted = time_now
          decide_next_step
        end
      end
    end

    def decide_next_step
      if full_batch_available?
        emit_full_batch_within_limit
      else
        emit_underfilled_batch_after_delay
      end
    end

    def try_again_later
      time_gap = throttle_delay
      later = time_gap > 0.01
      if later
        @emit_later_work = run_delayed(time_gap) { emit_single_batch }
      end

      later
    end

    def emit_full_batch_within_limit
      return if @emit_later_work

      @emit_later_work = run_delayed(throttle_delay) { emit_single_batch }
    end

    def emit_underfilled_batch_after_delay
      return if @underfilled_emit_work

      @underfilled_emit_work = run_delayed(@max_emit_interval) do
        emit_single_batch
      end
    end

    def drop_items_if_full
      curr_fullness = fullness
      @items.slice!(0, curr_fullness) if curr_fullness.nonzero?
    end

    def run_after(delay)
      if delay <= 0
        yield
      else
        delay_executor.run_queued do
          sleep delay
          yield
        end
      end
    end
  end
end
