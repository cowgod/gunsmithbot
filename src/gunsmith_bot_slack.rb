require_relative '../lib/gunsmith/slack/bot'
require_relative '../lib/gunsmith/bot'

$gunsmith_bot = Gunsmith::Bot.new

Gunsmith::Slack::Bot.run
