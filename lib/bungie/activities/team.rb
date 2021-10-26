# frozen_string_literal: true

module Bungie
  module Activities
    # Represent a team in a Destiny activity
    class Team < ActiveRecord::Base
      belongs_to :activity, class_name: 'Bungie::Activities::Activity', foreign_key: 'bungie_activity_id'
      has_many :players, class_name: 'Bungie::Activities::Player', foreign_key: 'bungie_activity_team_id'
    end
  end
end

