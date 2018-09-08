require 'slack-ruby-bot'
require_relative 'bungie_api'


class GunsmithBot < SlackRubyBot::Bot
  command 'help' do |client, data, _|
    output = <<HELP
To show off your weapon/armor, message the bot with your gamertag, network, and weapon/armor slot, separated by spaces. The bot will always look at the *most recently played character* on your account.
The standard usage looks like this: ```@gunsmith MyGamerTag playstation kinetic```

If you've set up your Slack profile so that your *title* ("What I Do") matches your in-game username, you can omit this: ```@gunsmith playstation helmet```

If your gamertag only exists on one network, that can be omitted as well: ```@gunsmith heavy```

*Special note to Xbox Users:*
If your gamertag has any spaces in it, these will need to be substituted with underscores (\"_\") in order for the bot to recognize the input properly.
This is only required when inputting the gamertag manually however; spaces are fine in your Slack first name.\n\n
_Keep that thing oiled, guardian._
HELP

    client.say(text: output, channel: data.channel)
  end

  command(/.*/) do |client, data, _|
    raise 'BUNGIE_API_KEY not set' unless ENV['BUNGIE_API_TOKEN']

    @bungie_api = BungieApi.new(ENV['BUNGIE_API_TOKEN'])

    # Split the input into words, and strip out the element that represents our own
    # userid (which will look something like '<@UCNTC2YH0>')
    args = data.text.split(/\s+/).grep_v(/^<@[A-Z0-9]+>$/)

    case args.length
      when 1
        # If they didn't provide a gamertag, use the first name of the Slack
        # user. If it's not set, use their title ("What I do")
        requested_gamertag = client.store.users[data.user][:profile][:title] || client.store.users[data.user][:name]
        requested_platform = nil
        requested_slot     = args[0]
      when 2
        requested_gamertag = args[0]
        requested_platform = nil
        requested_slot     = args[1]
      when 3
        requested_gamertag = args[0]
        requested_platform = args[1]
        requested_slot     = args[2]
      else
        GunsmithBot.print_usage(client, data)
        break
    end


    bucket_id = BungieApi.get_bucket_id(requested_slot)
    unless bucket_id
      GunsmithBot.print_usage(client, data)
      break
    end

    user_info = @bungie_api.search_user(requested_gamertag, requested_platform)
    unless user_info
      GunsmithBot.print_usage(client, data)
      break
    end

    character = @bungie_api.active_char_with_equipment(user_info['membershipType'], user_info['membershipId'])
    unless character
      GunsmithBot.print_usage(client, data)
      break
    end

    requested_item = character.dig('items').find {|item| item.dig('bucketHash') == bucket_id}


    ### TODO -- figure out why we return nothing if we don't use breakpoints˚
    ### TODO -- load perks
    ### TODO -- load icon (from vlad's manifest?)
    ### TODO -- format into attachment



    # item_hash = @bungie_api.get_item_hash_for_char_and_bucket(char_hash, bucket_hash)

    # @trials_report_api.load_manifest

    client.say(text: requested_item, channel: data.channel)
  end

  def self.print_usage(client, data)
    output = "Usage: @gunsmith <gamertag> <platform> <slot>\nPlease use the 'help' command for more info."
    client.say(text: output, channel: data.channel)
  end
end

GunsmithBot.run
