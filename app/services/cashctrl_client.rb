# frozen_string_literal: true

require 'net/http'
require 'json'

class CashctrlClient
  attr_reader :base_url

  def initialize
    config = Rails.application.config.cashctrl
    @org = config[:org]
    @api_key = config[:api_key]
    @revenue_account_id = config[:revenue_account_id]
    @base_url = "https://#{@org}.cashctrl.com/api/v1"
  end

  def get(path, params = {})
    uri = URI("#{@base_url}#{path}")
    uri.query = URI.encode_www_form(params) if params.any?

    request = Net::HTTP::Get.new(uri)
    execute(uri, request)
  end

  def post(path, body = {})
    uri = URI("#{@base_url}#{path}")
    request = Net::HTTP::Post.new(uri)
    request.set_form_data(body)
    execute(uri, request)
  end

  # Person methods
  def find_person_by_email(email)
    result = get('/person/list.json', { query: email })
    result['data']&.first
  end

  def create_person(first_name:, last_name:, email:)
    result = post('/person/create.json', {
                    firstName: first_name,
                    lastName: last_name,
                    addresses: [{ type: 'MAIN', email: email }].to_json
                  })
    result['insertId']
  end

  def find_or_create_person(user)
    person = find_person_by_email(user.email)
    return person['id'] if person

    create_person(
      first_name: user.first_name,
      last_name: user.last_name,
      email: user.email
    )
  end

  # Invoice methods
  INVOICE_CATEGORY_ID = 1 # Adjust based on CashCtrl setup

  def create_invoice(person_id:, due_days:, items:)
    items_json = items.map do |item|
      {
        accountId: @revenue_account_id,
        name: item[:name],
        unitPrice: item[:unit_price],
        quantity: item[:quantity] || 1
      }
    end

    result = post('/order/create.json', {
                    associateId: person_id,
                    categoryId: INVOICE_CATEGORY_ID,
                    dueDays: due_days,
                    items: items_json.to_json
                  })
    result['insertId']
  end

  def get_invoice(invoice_id)
    get('/order/read.json', { id: invoice_id.to_s })
  end

  def send_invoice_email(invoice_id)
    post('/order/send-email.json', { id: invoice_id })
  end

  def get_invoice_pdf(invoice_id)
    uri = URI("#{@base_url}/order/document.json?id=#{invoice_id}")
    request = Net::HTTP::Get.new(uri)
    request.basic_auth(@api_key, '')

    Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request).body
    end
  end

  # Journal entry methods (for prepaid users)
  def create_journal_entry(debit_account_id:, credit_account_id:, amount:, description:)
    items = [
      { accountId: debit_account_id, debit: amount },
      { accountId: credit_account_id, credit: amount }
    ]

    result = post('/journal/create.json', {
                    dateAdded: Date.today.to_s,
                    items: items.to_json,
                    notes: description
                  })
    result['insertId']
  end

  def get_account_balance(account_id)
    result = get('/account/balance.json', { id: account_id.to_s })
    result['balance']&.to_f || 0.0
  end

  private

  def execute(uri, request)
    request.basic_auth(@api_key, '')

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    JSON.parse(response.body)
  end
end
