# frozen_string_literal: true

require 'net/http'
require 'json'

class CashctrlClient
  attr_reader :base_url

  def initialize
    config = Rails.application.config.cashctrl
    @org = config[:org]
    @api_key = config[:api_key]
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

  private

  def execute(uri, request)
    request.basic_auth(@api_key, '')

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    JSON.parse(response.body)
  end
end
