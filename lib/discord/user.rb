# frozen_string_literal: true


module Discord
  # Represent a Discord user
  class User < ActiveRecord::Base
    belongs_to :bungie_user, class_name: 'Bungie::User', optional: true
  end
end
