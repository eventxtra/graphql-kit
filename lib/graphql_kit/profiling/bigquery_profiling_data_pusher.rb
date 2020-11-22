module GraphqlKit::Profiling
  class BigqueryProfilingDataPusher
    Record = Struct.new(:ts, :field, :benchmark, :divisor)

    # rubocop:disable Metrics/ParameterLists
    def initialize(
      project:, credential_json:, dataset:, table:,
      push_min_interval: nil, push_max_interval: nil,
      push_batch_size: nil, push_buffer_capacity: nil
    )
      begin
        require 'google/cloud/bigquery'
      rescue
        raise 'gem "google-cloud-bigquery" is required'
      end
      @project = project
      @credential_json = credential_json
      @dataset_name = dataset
      @table_name = table

      push_min_interval ||= 0.1
      push_max_interval ||= 30
      push_batch_size ||= 500
      push_buffer_capacity ||= 1_000_000

      @executor = QueuedExecutor.new
      @emitter = LossyBatchedEmitter.new(
        min_emit_interval: push_min_interval,
        max_emit_interval: push_max_interval,
        batch_size: push_batch_size,
        capacity: push_buffer_capacity
      ) do |batch|
        push_batch_to_remote(batch)
      end
    end
    # rubocop:enable Metrics/ParameterLists

    def push_remote(profiling_data)
      run_queued do
        @emitter.push generate_records(profiling_data)
      end
    end

    private

    NULL_LOGGER = Logger.new(
      File.open(File::NULL, 'w')
    )

    delegate :run_queued, to: :@executor

    def client
      @client ||= begin
        Google::Apis.logger = NULL_LOGGER
        Google::Cloud::Bigquery.new(
          project: @project,
          credentials: JSON.parse(@credential_json)
        )
      end
    end

    def dataset
      @dataset ||= begin
        client.dataset(@dataset_name) || client.create_dataset(@dataset_name)
      end
    end

    def table
      @table ||= begin
        dataset.table(@table_name) || begin
          dataset.create_table(@table_name) do |t|
            t.name = 'Profiling Data'
            t.schema do |s|
              s.timestamp 'ts', mode: :nullable
              s.string 'field', mode: :required
              s.integer 'benchmark', mode: :required
              s.integer 'divisor', mode: :required
            end
          end
        end
      end
    end

    def generate_records(profiling_data)
      ts = Time.now.iso8601
      profiling_data.benchmarks.collect do |bm|
        Record.new(ts, bm.field, bm.time, bm.divisor)
      end
    end

    def push_batch_to_remote(batch)
      table.insert batch.collect(&:to_h)
      message = [
        "[BigqueryProfilingDataPusher] ",
        "successfully pushed batch to remote with size: #{batch&.size}"
      ].join
      Rails.logger.info message
    rescue => e
      message = [
        "[BigqueryProfilingDataPusher] ",
        "failed to push batch (size: #{batch&.size}): #{e.message}"
      ].join
      Rails.logger.warn message
    end
  end
end
