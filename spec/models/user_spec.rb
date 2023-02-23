# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  context 'validation' do
    it 'fails creating a user with no attributes set' do
      user = User.new
      errors = user.errors

      expect(user.valid?).to eql(false)
      expect(user.save).to eql(false)

      expect(errors.size).to eql(3)

      expect(errors.objects.first.attribute).to eql(:email)
      expect(errors.objects.second.attribute).to eql(:username)

      expect(errors.objects.first.full_message).to eql('Email is invalid')
      expect(errors.objects.second.full_message).to eql("Username can't be blank")
    end

    it 'fails creating a user with invalid email' do
      user = User.new(
        username: Faker::Internet.username,
        first_name: Faker::Name.first_name,
        last_name: Faker::Name.last_name,
        email: 'invalid-email'
      )
      errors = user.errors

      expect(user.valid?).to eql(false)
      expect(user.save).to eql(false)
      expect(errors.size).to eql(1)
      expect(errors.first.attribute).to eql(:email)
      expect(errors.first.full_message).to eql('Email is invalid')
    end

    it 'fails setting invalid role' do
      user = User.create!(
        username: Faker::Internet.username,
        first_name: Faker::Name.first_name,
        last_name: Faker::Name.last_name,
        email: Faker::Internet.email
      )

      expect do
        user.update!({ role: 'invalid' })
      end.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  context 'creation' do
    it 'successfully assigns valid roles' do
      user = User.create({
                           username: Faker::Internet.username,
                           email: Faker::Internet.email,
                           first_name: Faker::Name.first_name,
                           last_name: Faker::Name.last_name
                         })
      # default role
      expect(user.user?).to eql(true)
      expect(user.admin?).to eql(false)
      expect(user.led_matrix?).to eql(false)

      user.role = 'admin'
      expect(user.user?).to eql(false)
      expect(user.admin?).to eql(true)
      expect(user.led_matrix?).to eql(false)

      user.role = 'led_matrix'
      expect(user.user?).to eql(false)
      expect(user.admin?).to eql(false)
      expect(user.led_matrix?).to eql(true)

      user.role = 'user'
      expect(user.user?).to eql(true)
      expect(user.admin?).to eql(false)
      expect(user.led_matrix?).to eql(false)

      user.admin!
      expect(user.user?).to eql(false)
      expect(user.admin?).to eql(true)
      expect(user.led_matrix?).to eql(false)

      user.led_matrix!
      expect(user.user?).to eql(false)
      expect(user.admin?).to eql(false)
      expect(user.led_matrix?).to eql(true)

      user.user!
      expect(user.user?).to eql(true)
      expect(user.admin?).to eql(false)
      expect(user.led_matrix?).to eql(false)
    end

    it 'properly creates user with expected attributes' do
      expected_attributes = %w[
        id
        email
        username
        role
        encrypted_password
        remember_created_at
        sign_in_count
        current_sign_in_at
        last_sign_in_at
        current_sign_in_ip
        last_sign_in_ip
        disabled
        first_name
        last_name
        preferred_language
        created_at
        updated_at
        provider
        uid
      ]

      username = Faker::Internet.username
      email = Faker::Internet.email
      first_name = Faker::Name.first_name
      last_name = Faker::Name.last_name

      user = User.create(
        username:,
        email:,
        first_name:,
        last_name:
      )

      actual_attributes = user.attributes.map { |attribute| attribute[0] }

      expect(actual_attributes).to eql(expected_attributes)

      expect(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.match?(user.id)).to eql(true)
      expect(user.email).to eql(email)
      expect(user.username).to eql(username)
      expect(user.role).to eql('user')
      expect(user.user?).to eql(true)
      expect(user.admin?).to eql(false)
      expect(user.led_matrix?).to eql(false)
      expect(user.encrypted_password).to be_nil
      expect(user.remember_created_at).to be_nil
      expect(user.sign_in_count).to eql(0)
      expect(user.current_sign_in_at).to be_nil
      expect(user.last_sign_in_at).to be_nil
      expect(user.current_sign_in_ip).to be_nil
      expect(user.last_sign_in_ip).to be_nil
      expect(user.disabled).to eql(false)
      expect(user.first_name).to eql(first_name)
      expect(user.last_name).to eql(last_name)
      expect(user.preferred_language).to eql('en')
      expect(user.created_at.respond_to?(:strftime)).to eql(true)
      expect(user.updated_at.respond_to?(:strftime)).to eql(true)
    end
  end
end
