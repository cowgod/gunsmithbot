#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../environment'


##### STILL TO DO:
# - Implement command to let users set `find_twitch_clips` field true or false


Cowgod::Logger.log 'Reporting new clips...'

Bungie::Activities::Clip.pending_notification.each do |clip|
  # While we get up and running, only notify clips for the last few weeks
  next unless clip&.activity&.started_at && clip.activity.started_at > Time.new(2021, 10, 1)

  clip.notify if clip&.tracked_players
end

Cowgod::Logger.log 'Done reporting new clips.'
