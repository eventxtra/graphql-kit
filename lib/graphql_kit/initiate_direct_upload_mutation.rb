# reference: https://dev.to/evilmartians/active-storage-meets-graphql-direct-uploads-3n38

class GraphqlKit::InitiateDirectUploadMutation < GraphQL::Schema::Mutation
  graphql_name 'InitiateDirectUpload'
  description 'Initiate direct file upload'

  class Input < GraphQL::Schema::InputObject
    graphql_name 'InitiateDirectUploadInput'
    description "File information required to prepare a direct upload"

    argument :filename, String, required: true,
      description: 'Original file name'
    argument :byte_size, Int, required: true,
      description: 'File size (bytes)'
    argument :checksum, String, required: true,
      description: 'MD5 file checksum as base64'
    argument :content_type, String, required: true,
      description: 'File content type'
  end

  class DirectUpload < GraphQL::Schema::Object
    graphql_name 'DirectUpload'
    description 'Represents direct upload credentials'

    field :url, String, null: false,
      description: 'Upload URL'
    field :headers, String, null: false,
      description: 'HTTP request headers (JSON-encoded)'
    field :signed_blob_id, GraphqlKit::SignedBlobId, null: false,
      description: 'Created blob record signed ID'
  end

  argument :input, Input, required: true

  field :direct_upload, DirectUpload, null: false

  def resolve(input:)
    blob = ActiveStorage::Blob.create_before_direct_upload!(input.to_h)
    {
      direct_upload: {
        url: blob.service_url_for_direct_upload,
        headers: blob.service_headers_for_direct_upload.to_json,
        signed_blob_id: blob.signed_id
      }
    }
  end

  def self.define_in(mutation_klass)
    mutation_klass.instance_exec do
      field :initiate_direct_upload, mutation: GraphqlKit::InitiateDirectUploadMutation
    end
  end
end
