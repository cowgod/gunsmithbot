#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../environment'

sleep_interval = $config&.dig('twitch_clips', 'announce_interval').presence || 60


loop do
  Cowgod::Logger.log 'Announcing new clips...'

  Bungie::Activities::Clip.pending_announcement.each do |clip|
    clip.announce if clip&.tracked_players
  end

  Cowgod::Logger.log "Done announcing new clips. Sleeping #{sleep_interval} secs..."


  sleep sleep_interval
end

