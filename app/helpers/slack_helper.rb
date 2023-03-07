# frozen_string_literal: true

# Utility methods for sending slack messages
module SlackHelper

  def self.send_message(message)
    return unless ENV['RAILS_ENV'] == 'production'

    client = Slack::Web::Client.new
    begin
      client.chat_postMessage(
        channel: ENV['SLACK_PARKIT_ADMINS_CHANNEL'],
        text: message,
        as_user: true
      )
    rescue Slack::Web::Api::Errors::ChannelNotFound => e
      Rails.logger.error(e)
    end
  end
end
