# frozen_string_literal: true


module Slack
  # Represent a Slack team
  class Team < ActiveRecord::Base
    has_many :users
  end
end
