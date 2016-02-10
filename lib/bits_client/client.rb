require 'httpclient'

class BitsClient
  require_relative 'errors'

  def initialize(endpoint:)
    @endpoint = endpoint
  end

  def upload_buildpack(guid, buildpack_path, filename)
    with_file_arg!(buildpack_path) do |file|
      body = { buildpack: file, buildpack_name: filename }
      put("buildpacks/#{guid}", body)
    end
  end

  private

  attr_reader :endpoint

  def with_file_arg!(file_path, &block)
    validate_file! file_path

    File.open(file_path) do |file|
      yield file
    end
  end

  def validate_file!(file_path)
    return if File.exist?(file_path)

    raise Errors::FileDoesNotExist.new("Could not find file: #{file_path}")
  end

  def put(path, body)
    http_client.put(path, body)
  end

  def http_client
    @http_client ||= HTTPClient.new(base_url: endpoint)
  end
end
