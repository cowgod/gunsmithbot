# frozen_string_literal: true


module Slack
  # Represent a Slack user
  class User < ActiveRecord::Base
    belongs_to :team
    belongs_to :bungie_user, class_name: 'Bungie::User', optional: true
  end
end
