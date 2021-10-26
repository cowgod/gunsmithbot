#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../environment'


##### STILL TO DO:
# - Implement command to let users set `find_twitch_clips` field true or false


Cowgod::Logger.log 'Reporting new clips...'

Bungie::Activities::Clip.pending_notification.each do |clip|
  clip.notify if clip&.tracked_players
end

Cowgod::Logger.log 'Done reporting new clips.'
