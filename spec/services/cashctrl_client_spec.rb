# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CashctrlClient do
  let(:client) { described_class.new }

  describe '#initialize' do
    it 'uses config from Rails' do
      allow(Rails.application.config).to receive(:cashctrl).and_return({
                                                                         org: 'test-org',
                                                                         api_key: 'test-key'
                                                                       })

      client = described_class.new
      expect(client.base_url).to eq('https://test-org.cashctrl.com/api/v1')
    end
  end

  describe '#get' do
    before do
      allow(Rails.application.config).to receive(:cashctrl).and_return({
                                                                         org: 'test-org',
                                                                         api_key: 'test-key'
                                                                       })
    end

    it 'makes authenticated GET request' do
      stub_request(:get, 'https://test-org.cashctrl.com/api/v1/test.json')
        .with(basic_auth: ['test-key', ''])
        .to_return(status: 200, body: '{"success": true}')

      result = client.get('/test.json')
      expect(result).to eq({ 'success' => true })
    end
  end

  describe '#post' do
    before do
      allow(Rails.application.config).to receive(:cashctrl).and_return({
                                                                         org: 'test-org',
                                                                         api_key: 'test-key'
                                                                       })
    end

    it 'makes authenticated POST request' do
      stub_request(:post, 'https://test-org.cashctrl.com/api/v1/test.json')
        .with(basic_auth: ['test-key', ''])
        .to_return(status: 200, body: '{"id": 123}')

      result = client.post('/test.json', { name: 'Test' })
      expect(result).to eq({ 'id' => 123 })
    end
  end

  describe '#find_person_by_email' do
    before do
      allow(Rails.application.config).to receive(:cashctrl).and_return({
                                                                         org: 'test-org',
                                                                         api_key: 'test-key'
                                                                       })
    end

    it 'returns person when found' do
      stub_request(:get, 'https://test-org.cashctrl.com/api/v1/person/list.json')
        .with(query: { query: 'test@example.com' })
        .to_return(status: 200, body: '{"data": [{"id": 123, "email": "test@example.com"}]}')

      result = client.find_person_by_email('test@example.com')
      expect(result['id']).to eq(123)
    end

    it 'returns nil when not found' do
      stub_request(:get, 'https://test-org.cashctrl.com/api/v1/person/list.json')
        .with(query: { query: 'missing@example.com' })
        .to_return(status: 200, body: '{"data": []}')

      result = client.find_person_by_email('missing@example.com')
      expect(result).to be_nil
    end
  end

  describe '#create_person' do
    before do
      allow(Rails.application.config).to receive(:cashctrl).and_return({
                                                                         org: 'test-org',
                                                                         api_key: 'test-key'
                                                                       })
    end

    it 'creates person and returns id' do
      stub_request(:post, 'https://test-org.cashctrl.com/api/v1/person/create.json')
        .to_return(status: 200, body: '{"success": true, "insertId": 456}')

      result = client.create_person(
        first_name: 'Test',
        last_name: 'User',
        email: 'test@example.com'
      )
      expect(result).to eq(456)
    end
  end
end
