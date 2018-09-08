require 'slack-ruby-bot'
require_relative 'bungie_api'
require_relative 'trials_report_api'


class GunsmithBot < SlackRubyBot::Bot


  help do
    title 'Gunsmith Bot'
    desc 'Shows off your weapons/armor'

    command '!showoff' do
      desc "To show off your weapon/armor, message the bot with your gamertag, network, and weapon/armor slot, separated by spaces. The bot will always look at the *most recently played character* on your account.
    The standard usage looks like this: ```!showoff MyGamerTag playstation kinetic```

    If you've set up your Slack profile so that your *first name* matches your in-game username, you can omit this: ```!showoff playstation helmet```

    If your gamertag only exists on one network, that can be omitted as well: ```!showoff heavy```

    *Special note to Xbox Users:*
    If your gamertag has any spaces in it, these will need to be substituted with underscores (\"_\") in order for the bot to recognize the input properly.
    This is only required when inputting the gamertag manually however; spaces are fine in your Slack first name.\n\n
    _Keep that thing oiled, guardian._"
    end
  end


  command '!showoff' do |client, data, match|
    raise 'BUNGIE_API_KEY not set' unless ENV['BUNGIE_API_TOKEN']

    @bungie_api = BungieApi.new(ENV['BUNGIE_API_TOKEN'])
    @trials_report_api = TrialsReportApi.new

    args = data.text.split(/\s+/).grep_v('!showoff')

    # The slot name is always the last argument
    bucket_hash = BungieApi.get_bucket_id(args.last)

    user_info = @bungie_api.search_user(args[0])
    character = @bungie_api.active_char_with_equipment(user_info['membershipType'], user_info['membershipId'])

    # item_hash = @bungie_api.get_item_hash_for_char_and_bucket(char_hash, bucket_hash)

    # @trials_report_api.load_manifest

    client.say(text: character, channel: data.channel)
  end
end

GunsmithBot.run
