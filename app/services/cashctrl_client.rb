# frozen_string_literal: true

require 'net/http'
require 'json'

class CashctrlClient
  attr_reader :base_url

  def initialize
    config = Rails.application.config.cashctrl
    @org = config[:org]
    @api_key = config[:api_key]
    @invoice_category_id = config[:invoice_category_id]
    @sales_account_id = config[:sales_account_id]
    @tax_id = config[:tax_id]
    @artikel = config[:artikel]
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

  def create_person(first_name:, last_name:, email:, address: nil, zip: nil, city: nil, country: nil)
    address_data = {
      type: 'MAIN',
      email: email,
      address: address,
      zip: zip,
      city: city,
      country: country
    }.compact

    result = post('/person/create.json', {
                    firstName: first_name,
                    lastName: last_name,
                    addresses: [address_data].to_json
                  })
    result['insertId']
  end

  def find_or_create_person(user)
    person = find_person_by_email(user.email)
    return person['id'] if person

    create_person(
      first_name: user.first_name,
      last_name: user.last_name,
      email: user.email,
      address: user.respond_to?(:full_address_line) ? user.full_address_line : nil,
      zip: user.respond_to?(:postal_code) ? user.postal_code : nil,
      city: user.respond_to?(:city) ? user.city : nil,
      country: user.respond_to?(:country_code) ? user.country_code : nil
    )
  end

  def update_person(user)
    address_data = {
      type: 'MAIN',
      address: user.full_address_line.presence,
      zip: user.postal_code,
      city: user.city,
      country: user.country_code
    }.compact

    post('/person/update.json', {
      id: user.cashctrl_person_id,
      firstName: user.first_name,
      lastName: user.last_name,
      addresses: [address_data].to_json
    })
  end

  # Invoice methods
  def create_invoice(person_id:, due_days:, date:, items:)
    items_json = items.map do |item|
      {
        accountId: @sales_account_id,
        taxId: @tax_id,
        articleNr: item[:artikel_nr],
        name: item[:name],
        unitPrice: item[:unit_price],
        quantity: item[:quantity] || 1
      }
    end

    result = post('/order/create.json', {
                    associateId: person_id,
                    categoryId: @invoice_category_id,
                    date: date.to_s,
                    dueDays: due_days,
                    items: items_json.to_json
                  })
    result['insertId']
  end

  # Create invoice with custom line items (for top-up invoices)
  def create_custom_invoice(person_id:, due_days:, date:, items:)
    items_json = items.map do |item|
      {
        accountId: @sales_account_id,
        taxId: @tax_id,
        name: item[:name],
        unitPrice: item[:unit_price],
        quantity: item[:quantity] || 1
      }
    end

    result = post('/order/create.json', {
                    associateId: person_id,
                    categoryId: @invoice_category_id,
                    date: date.to_s,
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
