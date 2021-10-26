#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../environment'


##### STILL TO DO:
# - Implement command to let users set `find_twitch_clips` field true or false
# - Implement regular process in bot to check for new, unreported match_clips, and report them in each configured channel (how do we handle this? Each user may want it in one or more locations. Same user might be in several discord servers and several slack servers)


Cowgod::Logger.log 'Reporting new clips...'

Bungie::Activities::Clip.pending_notification.each do |clip|
  clip.notify if clip&.tracked_players
end

Cowgod::Logger.log 'Done reporting new clips.'
