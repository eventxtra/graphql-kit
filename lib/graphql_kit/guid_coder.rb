class GraphqlKit::GuidCoder
  attr_accessor :enckey

  def initialize
    @enckey = Base58.base58_to_binary self.class.read_enckey_from_env
  end

  def encode(gql_typename, object_id)
    guid_plaintext = [gql_typename, object_id].join('-')
    GraphqlKit::CryptoUtils.deterministically_encrypt(enckey, guid_plaintext)
  end

  def decode(encoded_guid)
    begin
      guid_plaintext = GraphqlKit::CryptoUtils.deterministically_decrypt(enckey, encoded_guid)
    rescue
      return nil
    end
    guid_plaintext.split('-')
  end

  def self.read_enckey_from_env
    ENV.fetch("GRAPHQL_ID_ENCRYPTION_KEY", "cfMstKHokMk8jY8EWhb2CvgipoN3NdSLFex4PFTSeRro")
  end
end
