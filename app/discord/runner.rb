# require_relative '../lib/gunsmith/discord/bot'
# require_relative '../lib/gunsmith/bot'
require_relative '../../environment'
require_relative 'bot'

$gunsmith_bot = Gunsmith::Bot.new

bot = Gunsmith::Discord::Bot.new
bot.run

