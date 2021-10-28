#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../environment'


Cowgod::Logger.log 'Reporting new clips...'

Bungie::Activities::Clip.pending_announcement.each do |clip|
  clip.announce if clip&.tracked_players
end

Cowgod::Logger.log 'Done reporting new clips.'
