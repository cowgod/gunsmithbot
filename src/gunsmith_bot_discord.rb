require_relative '../lib/gunsmith/discord/bot'
require_relative '../lib/gunsmith/bot'

$gunsmith_bot = Gunsmith::Bot.new

bot = Gunsmith::Discord::Bot.new
bot.run

