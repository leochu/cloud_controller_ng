require 'cloud_controller/blobstore/webdav/nginx_secure_link_signer'

module CloudController
  module Blobstore
    class DavBlob < Blob
      attr_reader :key

      def initialize(httpmessage:, key:, signer:)
        @httpmessage = httpmessage
        @key         = key
        @signer      = signer
      end

      def internal_download_url

        uri = URI("http://abc:123@blobstore.service.cf.internal/sign?expire=1455159464\&prefix=/blobstore_url_signer\&path=/01/fb/01fb2bf9-00b6-4ed1-ba07-16abacbddecb")
        client = HTTPClient.new()
        auth = Base64.encode64( 'user:pass' ).chomp
        client.set_auth(nil, "user", "pass")
        response = client.get(uri, :follow_redirect => true, :Authorization => auth)
        Steno.logger("orange-internal").info(response.body)
        Steno.logger("orange-internal-content").info(response.content)

        expires   = Time.now.utc.to_i + 3600
        @signer.sign_internal_url(path: @key, expires: expires)

      end

      def public_download_url
        expires   = Time.now.utc.to_i + 3600
        @signer.sign_public_url(path: @key, expires: expires)
      end

      def attributes(*keys)
        @attributes ||= {
          etag:           @httpmessage.headers['ETag'],
          last_modified:  @httpmessage.headers['Last-Modified'],
          content_length: @httpmessage.headers['Content-Length'],
          created_at:     nil
        }

        return @attributes if keys.empty?
        @attributes.select { |key, _| keys.include? key }
      end
    end
  end
end
