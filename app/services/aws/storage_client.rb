# frozen_string_literal: true

require "aws-sdk-s3"

module Aws
  class StorageClient
    def initialize
      @client = ::Aws::S3::Client.new(s3_client_options)
      @bucket = ENV.fetch("S3_REPORTS_BUCKET")
    end

    def upload_report(key:, body:, content_type:)
      @client.put_object(
        bucket: @bucket,
        key: key,
        body: body,
        content_type: content_type
      )
      key
    end

    def download_url(key:, expires_in: 3600)
      signer = ::Aws::S3::Presigner.new(client: @client)
      signer.presigned_url(:get_object, bucket: @bucket, key: key, expires_in: expires_in)
    end

    def list_reports(prefix: "")
      response = @client.list_objects_v2(bucket: @bucket, prefix: prefix)
      response.contents.map { |obj| { key: obj.key, size: obj.size, last_modified: obj.last_modified } }
    end

    private

    def s3_client_options
      options = { region: ENV.fetch("AWS_REGION", "us-east-1") }

      if ENV["AWS_ENDPOINT_URL"].present?
        options[:endpoint] = ENV["AWS_ENDPOINT_URL"]
        options[:credentials] = ::Aws::Credentials.new("test", "test")
        options[:force_path_style] = true
      end

      options
    end
  end
end
