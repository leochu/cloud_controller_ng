require 'spec_helper'
require 'bits_client/client'

require 'securerandom'

describe BitsClient do
  let(:endpoint) { 'http://bits-service.com/' }
  subject { BitsClient.new(endpoint: endpoint) }

  context 'Buildpacks' do
    describe '#upload_buildpack' do
      let(:guid) { SecureRandom.uuid }
      let(:file_path) { Tempfile.new('buildpack').path }
      let(:file_name) { 'my-buildpack.zip' }

      it 'makes the correct request to the bits endpoint' do
        request = stub_request(:put, "http://bits-service.com/buildpacks/#{guid}").
          with(body: /.*buildpack".*/).
          to_return(status: 201)

        subject.upload_buildpack(guid, file_path, file_name)
        expect(request).to have_been_requested
      end

      it 'returns the request response' do
        stub_request(:put, "http://bits-service.com/buildpacks/#{guid}").
          to_return(status: 201)

        response = subject.upload_buildpack(guid, file_path, file_name)
        expect(response.status).to be(201)
      end

      context 'when invalid buildpack is given' do
        it 'raises the correct exception' do
          expect {
            subject.upload_buildpack(guid, '/not-here', file_name)
          }.to raise_error(BitsClient::Errors::FileDoesNotExist)
        end
      end
    end
  end
end
