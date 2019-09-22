# frozen_string_literal: true

require_relative '../../environment'
require_relative 'bot'

$gunsmith_bot = Gunsmith::Bot.new

Gunsmith::Slack::Bot.run
