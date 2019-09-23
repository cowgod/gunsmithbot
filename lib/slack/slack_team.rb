# frozen_string_literal: true

require_relative 'slack_user'

module Slack
  # Represent a Slack team
  class SlackTeam < ActiveRecord::Base
    has_many :slack_users
  end
end
