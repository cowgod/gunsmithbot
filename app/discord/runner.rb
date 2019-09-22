# frozen_string_literal: true

require_relative '../../environment'
require_relative 'bot'

$gunsmith_bot = Gunsmith::Bot.new

bot = Gunsmith::Discord::Bot.new
bot.run

