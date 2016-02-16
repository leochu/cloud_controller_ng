require 'net/http/post/multipart'

class BitsClient
  require_relative 'errors'

  def initialize(endpoint:)
    @endpoint = URI.parse(endpoint)
  end

  def upload_buildpack(buildpack_path, filename)
    with_file_attachment!(buildpack_path, filename) do |file_attachment|
      body = { buildpack: file_attachment }
      post('/buildpacks', body)
    end
  end

  def download_buildpack(guid)
    get("/buildpacks/#{guid}")
  end

  def delete_buildpack(guid)
    delete("/buildpacks/#{guid}")
  end

  private

  attr_reader :endpoint

  def with_file_attachment!(file_path, filename, &block)
    validate_file! file_path

    File.open(file_path) do |file|
      attached_file = UploadIO.new(file, 'application/octet-stream', filename)
      yield attached_file
    end
  end

  def validate_file!(file_path)
    return if File.exist?(file_path)

    raise Errors::FileDoesNotExist.new("Could not find file: #{file_path}")
  end

  def get(path)
    request = Net::HTTP::Get.new(path)
    http_client.request(request)
  end

  def post(path, body)
    request = Net::HTTP::Post::Multipart.new(path, body)
    http_client.request(request)
  end

  def delete(path)
    request = Net::HTTP::Delete.new(path)
    http_client.request(request)
  end

  def http_client
    @http_client ||= Net::HTTP.new(endpoint.host, endpoint.port)
  end
end
