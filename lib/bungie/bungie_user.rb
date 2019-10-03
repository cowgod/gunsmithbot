# frozen_string_literal: true

module Bungie
  # Represent a Bungie.net membership
  class BungieMembership < ActiveRecord::Base
    has_many :bungie_memberships

  end
end
