module GraphqlKit::CryptoUtils
  def self.deterministically_encrypt(key, plaintext)
    digest = Digest::SHA256.digest(key + plaintext).bytes
    iv = digest.first(16).zip(digest.last(16)).map { |a, b| (a ^ b).chr }.join

    cipher = OpenSSL::Cipher::AES256.new :CBC
    cipher.encrypt
    cipher.iv = iv
    cipher.key = key
    encrypted = cipher.update(plaintext) + cipher.final

    Base58.binary_to_base58(iv + encrypted)
  end

  def self.deterministically_decrypt(key, encrypt_result)
    encrpyted_decoded = Base58.base58_to_binary(encrypt_result)
    iv = encrpyted_decoded[0...16]
    ciphertext = encrpyted_decoded[16..-1]

    decipher = OpenSSL::Cipher::AES256.new :CBC
    decipher.decrypt
    decipher.iv = iv
    decipher.key = key

    decipher.update(ciphertext) + decipher.final
  end
end
