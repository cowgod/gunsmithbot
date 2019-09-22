# require_relative '../lib/gunsmith/slack/bot'
# require_relative '../lib/gunsmith/bot'
require_relative '../../environment'
require_relative 'bot'

$gunsmith_bot = Gunsmith::Bot.new

Gunsmith::Slack::Bot.run
