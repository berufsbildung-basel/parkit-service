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

  describe '#create_invoice' do
    before do
      allow(Rails.application.config).to receive(:cashctrl).and_return({
                                                                         org: 'test-org',
                                                                         api_key: 'test-key'
                                                                       })
    end

    it 'creates invoice with line items' do
      stub_request(:post, 'https://test-org.cashctrl.com/api/v1/order/create.json')
        .to_return(status: 200, body: '{"success": true, "insertId": 789}')

      result = client.create_invoice(
        person_id: 123,
        due_days: 30,
        date: Date.new(2025, 1, 15),
        items: [
          { artikel_nr: 'PARK-CAR-FD-WD', name: '15.01.2025 | Platz #1 | Ganztag', unit_price: 20.0 }
        ]
      )
      expect(result).to eq(789)
    end
  end

  describe '#get_invoice' do
    before do
      allow(Rails.application.config).to receive(:cashctrl).and_return({
                                                                         org: 'test-org',
                                                                         api_key: 'test-key'
                                                                       })
    end

    it 'fetches invoice details' do
      stub_request(:get, 'https://test-org.cashctrl.com/api/v1/order/read.json')
        .with(query: { id: '789' })
        .to_return(status: 200, body: '{"id": 789, "statusId": 16}')

      result = client.get_invoice(789)
      expect(result['statusId']).to eq(16)
    end
  end

  describe '#send_invoice_email' do
    before do
      allow(Rails.application.config).to receive(:cashctrl).and_return({
                                                                         org: 'test-org',
                                                                         api_key: 'test-key'
                                                                       })
    end

    it 'sends invoice via email' do
      stub_request(:post, 'https://test-org.cashctrl.com/api/v1/order/send-email.json')
        .to_return(status: 200, body: '{"success": true}')

      result = client.send_invoice_email(789)
      expect(result['success']).to be true
    end
  end

  describe '#get_invoice_pdf' do
    before do
      allow(Rails.application.config).to receive(:cashctrl).and_return({
                                                                         org: 'test-org',
                                                                         api_key: 'test-key'
                                                                       })
    end

    it 'returns PDF binary data' do
      pdf_content = '%PDF-1.4 test'
      stub_request(:get, 'https://test-org.cashctrl.com/api/v1/order/document.json')
        .with(query: { id: '789' })
        .to_return(status: 200, body: pdf_content, headers: { 'Content-Type' => 'application/pdf' })

      result = client.get_invoice_pdf(789)
      expect(result).to eq(pdf_content)
    end
  end

  describe '#create_journal_entry' do
    before do
      allow(Rails.application.config).to receive(:cashctrl).and_return({
                                                                         org: 'test-org',
                                                                         api_key: 'test-key',
                                                                         revenue_account_id: 100
                                                                       })
    end

    it 'creates journal entry with debit and credit' do
      stub_request(:post, 'https://test-org.cashctrl.com/api/v1/journal/create.json')
        .to_return(status: 200, body: '{"success": true, "insertId": 999}')

      result = client.create_journal_entry(
        debit_account_id: 200,
        credit_account_id: 100,
        amount: 150.50,
        description: 'Parkgebühren Januar 2025'
      )
      expect(result).to eq(999)
    end
  end

  describe '#get_account_balance' do
    before do
      allow(Rails.application.config).to receive(:cashctrl).and_return({
                                                                         org: 'test-org',
                                                                         api_key: 'test-key'
                                                                       })
    end

    it 'returns account balance' do
      stub_request(:get, 'https://test-org.cashctrl.com/api/v1/account/balance.json')
        .with(query: { id: '200' })
        .to_return(status: 200, body: '{"balance": 350.00}')

      result = client.get_account_balance(200)
      expect(result).to eq(350.00)
    end
  end
end
