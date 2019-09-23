# frozen_string_literal: true

require_relative '../environment'

$gunsmith_bot = Gunsmith::Bot.new

bot = Gunsmith::DiscordBot.new
bot.run

