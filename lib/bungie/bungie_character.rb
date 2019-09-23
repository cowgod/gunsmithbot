# frozen_string_literal: true

module Bungie
  # Represent a Bungie.net character
  class BungieCharacter < ActiveRecord::Base
    belongs_to :bungie_user

    attr_accessor :item_rows
  end
end