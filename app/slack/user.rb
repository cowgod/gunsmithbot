# frozen_string_literal: true


module Gunsmith
  module Slack
    # Represent a Slack user
    class User < ::ActiveRecord::Base
      attr_accessor :user_id, :team_id

    end
  end
end
