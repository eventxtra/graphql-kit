module GraphqlKit::OffsetCursorEncoder
  class << self
    PATTERN = /^offset\:([0-9]+)$/

    def encode(offset, *)
      "offset:#{offset}"
    end

    def decode(cursor, *)
      cursor.match(PATTERN)&.then { |m| m.captures[0] }
    end
  end
end
