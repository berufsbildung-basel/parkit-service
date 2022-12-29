# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Users', type: :request do
  let!(:user) {
    User.create!(
      oktaId: Faker::Internet.unique.uuid,
      username: Faker::Internet.username,
      email: Faker::Internet.email,
      first_name: Faker::Name.first_name,
      last_name: Faker::Name.last_name
    )
  }

  describe 'POST /users' do
    it 'rejects creating a new user' do
      post api_v1_users_url

      expect(response).to have_http_status(405)

      errors = JSON.parse(response.body).deep_symbolize_keys[:errors]

      expect(errors[0][:title]).to eq('Could not create user')
    end
  end

  describe 'DELETE /users/{id}' do
    it 'rejects removing a user' do
      delete api_v1_user_url('some-id')

      expect(response).to have_http_status(405)

      errors = JSON.parse(response.body).deep_symbolize_keys[:errors]

      expect(errors[0][:title]).to eq('Could not remove user')
    end
  end

  describe 'PUT /users/{id}/change_role' do
    it 'rejects changing to invalid role' do
      put api_v1_user_change_role_url(user.id), params: {
        role: 'invalid-role'
      }

      user.reload

      expect(response).to have_http_status(400)

      errors = JSON.parse(response.body).deep_symbolize_keys[:errors]

      expect(errors[0][:title]).to eq('Invalid role')

      expect(user.role).to eq('user')
    end

    it 'changes role of user' do
      put api_v1_user_change_role_url(user.id), params: {
        role: 'admin'
      }

      user.reload

      expect(response).to have_http_status(200)
      expect(JSON.parse(response.body).deep_symbolize_keys[:role]).to eq('admin')
      expect(user.role).to eq('admin')
    end
  end

  describe 'PUT /users/{id}/disable' do
    it 'renders a successful response' do
      put api_v1_user_disable_url(user.id)

      expect(response).to have_http_status(200)
    end

    it 'renders JSON' do
      put api_v1_user_disable_url(user.id)

      expect(response.content_type).to eq('application/json; charset=utf-8')
    end

    it 'renders the index template' do
      put api_v1_user_disable_url(user.id)

      expect(response).to render_template('api/v1/users/_user')
    end

    it 'disables a user' do
      put api_v1_user_disable_url(user.id)

      user.reload

      expect(response).to have_http_status(200)
      expect(JSON.parse(response.body).deep_symbolize_keys[:disabled]).to eq(true)
      expect(user.disabled?).to eq(true)
    end
  end

  describe 'PUT /users/{id}/enable' do
    it 'renders a successful response' do
      put api_v1_user_enable_url(user.id)

      expect(response).to have_http_status(200)
    end

    it 'renders JSON' do
      put api_v1_user_enable_url(user.id)

      expect(response.content_type).to eq('application/json; charset=utf-8')
    end

    it 'renders the index template' do
      put api_v1_user_enable_url(user.id)

      expect(response).to render_template('api/v1/users/_user')
    end

    it 'enables a user' do
      user.update!(disabled: true)

      put api_v1_user_enable_url(user.id)

      user.reload

      expect(JSON.parse(response.body).deep_symbolize_keys[:disabled]).to eq(false)
      expect(user.disabled?).to eq(false)
    end
  end

  describe 'GET /users' do
    it 'renders a successful response' do
      get api_v1_users_url

      expect(response).to have_http_status(200)
    end

    it 'renders JSON' do
      get api_v1_users_url

      expect(response.content_type).to eq('application/json; charset=utf-8')
    end

    it 'renders the index template' do
      get api_v1_users_url

      expect(response).to render_template(:index)
    end

    it 'lists users' do
      expected_user = User.first

      get api_v1_users_url

      json = JSON.parse(response.body).deep_symbolize_keys

      expect(json[:users].size).to eq(1)

      expect(json[:users][0][:id]).to eq(expected_user.id)
      expect(json[:users][0][:oktaId]).to eq(expected_user.oktaId)
      expect(json[:users][0][:email]).to eq(expected_user.email)
      expect(json[:users][0][:username]).to eq(expected_user.username)
      expect(json[:users][0][:role]).to eq(expected_user.role)
    end

    it 'includes pagination' do
      get api_v1_users_url

      json = JSON.parse(response.body).deep_symbolize_keys

      expect(json[:total_count]).to eq(1)
      expect(json[:total_pages]).to eq(1)
      expect(json[:current_page]).to eq(1)
      expect(json[:limit_per_page]).to eq(25)
    end
  end

  describe 'GET /users/{id}' do
    it 'returns not found for non-existing user' do
      get api_v1_user_url('non-existing-id')

      expect(response).to have_http_status(404)

      errors = JSON.parse(response.body).deep_symbolize_keys[:errors]

      expect(errors[0][:title]).to eq('Could not find user')
    end

    it 'renders a successful response' do
      get api_v1_user_url(user.id)

      expect(response).to have_http_status(200)
    end

    it 'renders JSON' do
      get api_v1_user_url(user.id)

      expect(response.content_type).to eq('application/json; charset=utf-8')
    end

    it 'renders the show template' do
      get api_v1_user_url(user.id)

      expect(response).to render_template(:show)
    end

    it 'shows user' do
      get api_v1_user_url(user.id)

      json = JSON.parse(response.body).deep_symbolize_keys

      expect(json[:id]).to eq(user.id)
      expect(json[:oktaId]).to eq(user.oktaId)
      expect(json[:email]).to eq(user.email)
      expect(json[:username]).to eq(user.username)
      expect(json[:role]).to eq(user.role)
    end
  end

  describe 'PATCH /users/{id}' do
    it 'returns not found for non-existing user' do
      patch api_v1_user_url('non-existing-id')

      expect(response).to have_http_status(404)

      errors = JSON.parse(response.body).deep_symbolize_keys[:errors]

      expect(errors[0][:title]).to eq('Could not find user')
    end

    it 'renders a successful response' do
      patch api_v1_user_url(user.id)

      expect(response).to have_http_status(200)
    end

    it 'renders JSON' do
      patch api_v1_user_url(user.id)

      expect(response.content_type).to eq('application/json; charset=utf-8')
    end

    it 'renders the user template' do
      patch api_v1_user_url(user.id)

      expect(response).to render_template('api/v1/users/_user')
    end

    it 'updates user' do
      patch api_v1_user_url(user.id), params: {
        preferred_language: 'it'
      }

      user.reload

      json = JSON.parse(response.body).deep_symbolize_keys

      expect(json[:id]).to eq(user.id)
      expect(json[:oktaId]).to eq(user.oktaId)
      expect(json[:email]).to eq(user.email)
      expect(json[:username]).to eq(user.username)
      expect(json[:role]).to eq(user.role)
      expect(json[:preferred_language]).to eq('it')
    end

    it 'ignores updating non-permitted parameters' do
      expected_username = user.username
      patch api_v1_user_url(user.id), params: {
        username: 'new-username'
      }

      user.reload

      json = JSON.parse(response.body).deep_symbolize_keys

      expect(json[:id]).to eq(user.id)
      expect(json[:oktaId]).to eq(user.oktaId)
      expect(json[:email]).to eq(user.email)
      expect(json[:username]).to eq(expected_username)
      expect(json[:role]).to eq(user.role)
      expect(json[:preferred_language]).to eq(user.preferred_language)
    end
  end
end
