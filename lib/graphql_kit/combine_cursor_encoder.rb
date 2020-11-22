class GraphqlKit::CombineCursorEncoder
  attr_reader :encoders
  attr_reader :decoders

  def initialize(encode:, decode: nil)
    @encoders = []
    @decoders = []
    add_encoders(*encode)
    add_decoders(*(decode || encode))
  end

  def add_encoders(*add_encoders)
    @encoders.concat(add_encoders)
  end

  def remove_encoders(*remove_encoders)
    remove_encoders.each { |enc| @encoders.delete(enc) }
  end

  def add_decoders(*add_decoders)
    @decoders.concat(add_decoders)
  end

  def remove_decoders(*remove_decoders)
    remove_decoders.each { |dec| @decoders.delete(dec) }
  end

  def encode(*encode_args)
    @encoders.lazy.map do |encoder|
      begin
        encoder.encode(*encode_args)
      rescue GraphQL::ExecutionError
        nil
      end
    end.detect(&non_nil)
  end

  def decode(*decode_args)
    @decoders.lazy.map do |decoder|
      begin
        decoder.decode(*decode_args)
      rescue GraphQL::ExecutionError
        nil
      end
    end.detect(&non_nil)
  end

  private

  def non_nil
    proc { |x| !x.nil? }
  end
end
