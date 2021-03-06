require 'spec_helper'
require 'messages/packages/package_create_message'

module VCAP::CloudController
  RSpec.describe PackageCreateMessage do
    describe '.create_from_http_request' do
      let(:body) { { 'type' => 'docker', 'relationships' => { 'app' => { 'guid' => 'guid' } } } }

      it 'returns the correct PackageCreateMessage' do
        message = PackageCreateMessage.create_from_http_request(body)

        expect(message).to be_a(PackageCreateMessage)
        expect(message.app_guid).to eq('guid')
        expect(message.type).to eq('docker')
      end

      it 'converts requested keys to symbols' do
        message = PackageCreateMessage.create_from_http_request(body)

        expect(message.requested?(:type)).to be_truthy
      end
    end

    describe 'validations' do
      let(:relationships) { { app: { guid: 'some-guid' } } }

      context 'when unexpected keys are requested' do
        let(:params) { { relationships: relationships, type: 'bits', unexpected: 'foo', extra: 'bar' } }

        it 'is not valid' do
          message = PackageCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include("Unknown field(s): 'unexpected', 'extra'")
        end
      end

      context 'when a type parameter that is not allowed is provided' do
        let(:params) { { relationships: relationships, type: 'not-allowed' } }

        it 'is not valid' do
          message = PackageCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors[:type]).to include('must be one of \'bits, docker\'')
        end
      end

      context 'relationships' do
        let(:params) { { relationships: relationships, type: 'bits' } }

        context 'when guid is invalid' do
          let(:relationships) { { app: { guid: nil } } }

          it 'is not valid' do
            message = PackageCreateMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors_on(:relationships)).to_not be_empty
          end
        end

        context 'when there are unexpected keys' do
          let(:relationships) { { app: { guid: 'some-guid' }, potato: 'fried' } }

          it 'is not valid' do
            message = PackageCreateMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors_on(:relationships)).to_not be_empty
          end
        end
      end

      context 'bits' do
        context 'when a data parameter is provided for a bits package and it is not empty' do
          let(:params) { { relationships: relationships, type: 'bits', data: { foobar: 'foobaz' } } }

          it 'is not valid' do
            message = PackageCreateMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors[:data]).to include('Data must be empty if provided for bits packages')
          end
        end

        context 'when a data parameter is not provided for a bits package' do
          let(:params) { { relationships: relationships, type: 'bits' } }

          it 'is valid' do
            message = PackageCreateMessage.new(params)
            expect(message).to be_valid
          end
        end
      end

      context 'when a docker type is requested' do
        context 'when data is not provided' do
          let(:params) { { relationships: relationships, type: 'docker' } }

          it 'is invalid' do
            message = PackageCreateMessage.new(params)
            expect(message).not_to be_valid
            expect(message.errors.full_messages).to include('Data Image required')
          end
        end

        context 'when an image is not provided' do
          let(:params) { { relationships: relationships, type: 'docker', data: { store_image: false, credentials: {} } } }

          it 'is invalid' do
            message = PackageCreateMessage.new(params)
            expect(message).not_to be_valid
            expect(message.errors.full_messages).to include('Data Image required')
          end
        end

        context 'when a non-string image is provided' do
          let(:params) { { relationships: relationships, type: 'docker', data: { image: 5, store_image: false, credentials: {} } } }
          it 'is invalid' do
            message = PackageCreateMessage.new(params)
            expect(message).not_to be_valid
            expect(message.errors.full_messages).to include('Data Image must be a string')
          end
        end

        context 'when unexpected data keys are provided' do
          let(:params) { { relationships: relationships, type: 'docker', data: { image: 'path/to/image/', birthday: 'party' } } }

          it 'is invalid' do
            message = PackageCreateMessage.new(params)
            expect(message).not_to be_valid
            expect(message.errors.full_messages[0]).to include("Unknown field(s): 'birthday'")
          end
        end
      end
    end
  end
end
