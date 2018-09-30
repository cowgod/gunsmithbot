require 'slack-ruby-bot'
require_relative 'bungie_api'
require_relative 'trials_report_api'

require 'pp'


class GunsmithBot < SlackRubyBot::Bot
  BOT_NAME     = 'Banshee-44'.freeze
  BOT_ICON_URL = 'http://binrock.net/banshee44.png'.freeze
  BOT_USERNAME = (ENV['GUNSMITH_BOT_USERNAME'] || 'gunsmithbot').freeze

  # Used in formatting the attachment
  DAMAGE_COLOR = {
    kinetic: '#d9d9d9',
    arc:     '#80b3ff',
    solar:   '#e68a00',
    void:    '#400080'
  }.freeze


  command 'help' do |client, data, _|
    output = <<HELP
To show off your weapon/armor, message the bot with your gamertag, network, and weapon/armor slot, separated by spaces. The bot will always look at the *most recently played character* on your account.
The standard usage looks like this: ```@#{BOT_USERNAME} MyGamerTag playstation kinetic```

If you've set up your Slack profile so that your *title* ("What I Do") matches your in-game username, you can omit this: ```@#{BOT_USERNAME} playstation helmet```

If your gamertag only exists on one network, that can be omitted as well: ```@#{BOT_USERNAME} heavy```

*Special note to Xbox Users:*
If your gamertag has any spaces in it, these will need to be substituted with underscores (\"_\") in order for the bot to recognize the input properly.
This is only required when inputting the gamertag manually however; spaces are fine in your Slack title.\n\n
_Keep that thing oiled, guardian._
HELP

    client.say(text: output, channel: data.channel)
  end

  command(/.*/) do |client, data, _|
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
        GunsmithBot.print_usage(client, data, 'Wrong number of arguments.')
        break
    end


    bucket_id = BungieApi.get_bucket_id(requested_slot)
    unless bucket_id
      GunsmithBot.print_usage(client, data, "Couldn't find the requested slot.")
      break
    end

    final_slot = BungieApi.get_bucket_code(bucket_id)

    gamertag_suggestions = []

    user_info = $bungie_api.search_user(requested_gamertag, requested_platform)

    unless user_info
      search_results = TrialsReportApi.search_user(requested_gamertag, requested_platform)

      unless search_results&.first
        GunsmithBot.print_usage(client, data, "Couldn't find the requested user.")
        break
      end

      user_info            = $bungie_api.search_user(search_results&.first&.dig('displayName'), requested_platform)
      gamertag_suggestions = search_results.map { |result| result&.dig('displayName') }
    end

    unless user_info
      GunsmithBot.print_usage(client, data, "Couldn't find the requested user.")
      break
    end

    final_gamertag = user_info&.dig('displayName')
    final_platform = BungieApi.get_platform_code(user_info&.dig('membershipType'))

    character = $bungie_api.active_char_with_equipment(user_info['membershipType'], user_info['membershipId'])
    unless character
      GunsmithBot.print_usage(client, data, "Couldn't find the most recently used character for the requested user.")
      break
    end

    requested_item = character.dig('items').find { |item| item.dig('bucketHash') == bucket_id }
    unless requested_item
      GunsmithBot.print_usage(client, data, "Couldn't find the requested item or armor piece.")
      break
    end

    item = $bungie_api.item_details(user_info['membershipType'], user_info['membershipId'], requested_item['itemInstanceId'])
    unless item
      GunsmithBot.print_usage(client, data, "Couldn't load info for the requested item or armor piece.")
      break
    end


    # Prepare output
    destiny_tracker_url = "https://db.destinytracker.com/d2/en/items/#{URI.encode(item[:hash])}"
    icon_url            = item[:has_icon] ? "https://www.bungie.net/#{URI.encode(item[:icon])}" : nil


    message_text = ''
    message_text += "<@#{data&.user}>: " unless data&.user&.blank?
    message_text += "`#{final_gamertag} #{final_platform} #{final_slot}`\n"

    unless gamertag_suggestions&.blank?
      message_text += 'Gamertag Suggestions: '

      message_text += gamertag_suggestions
        .take(5)
        .map { |gamertag| "`#{gamertag}`" }
        .join(', ')
    end

    message_text.strip!


    attachment_text     = "#{item[:type_and_tier]} - #{item[:power_level]} PL\n#{item[:description]}"
    attachment_fallback = "#{item[:name]} - #{item[:type_and_tier]} - #{item[:power_level]} PL - #{item[:description]}"

    attachment_fields = []

    # Perks
    field_text = item[:perk_sockets]
      .map do |perk_socket|
      perk_socket.map do |perk|
        perk[:selected] ? "*#{perk[:name]}*" : perk[:name]
      end
        .join(' | ')
    end
      .map { |line| "- #{line}" }
      .join("\n")

    unless field_text.blank?
      attachment_fields.push({
                               value: '----------------------------',
                               short: false
                             })

      attachment_fields.push({
                               title: 'Perks',
                               value: field_text,
                               short: false
                             })
    end


    # Masterwork / Mod
    attachment_fields.push({
                             value: '----------------------------',
                             short: false
                           })

    attachment_fields.push({
                             title: 'Masterwork',
                             value: item[:masterwork] ? "#{item[:masterwork][:affected_stat]} - #{item[:masterwork][:value]}" : 'n/a',
                             short: true
                           })

    attachment_fields.push({
                             title: 'Mod',
                             ### TODO -- get rid of description?
                             value: item[:mod] ? item[:mod][:name].to_s : 'n/a',
                             short: true
                           })


    # Stats
    stat_abbreviations = {
      'Rounds Per Minute' => 'RPM',
      'Reload Speed'      => 'Reload',
      # 'Magazine' => 'Mag'
    }

    attachment_footer = item[:stats]
      .each { |stat| stat[:name].to_s.gsub!(/^(#{stat_abbreviations.keys.join('|')})$/, stat_abbreviations) }
      .map { |stat| "#{stat[:name]}: #{stat[:value]}" }
      .join(', ')

    attachment_footer = 'No stats, but it sure looks pretty' if attachment_footer.blank?


    client.web_client.chat_postMessage(
      channel:     data.channel,
      as_user:     true,
      text:        message_text,
      attachments: [
                     {
                       color:       get_hex_color_for_damage_type(item[:damage_type]),
                       title:       item[:name],
                       title_link:  destiny_tracker_url,
                       thumb_url:   icon_url,
                       text:        attachment_text,
                       fallback:    attachment_fallback,
                       fields:      attachment_fields,
                       footer_icon: BOT_ICON_URL,
                       # footer:      BOT_NAME,
                       footer: attachment_footer,
                       # ts:          Time.now.to_i,
                       mrkdwn_in: ['fields']
                     }
                   ].to_json
    )
  end

  def self.print_usage(client, data, additional_message = nil)
    output = ''

    output += "<@#{data&.user}>: " unless data&.user&.blank?
    output += "#{additional_message}" unless additional_message&.blank?
    output += "\n"

    output += "Usage: @#{BOT_USERNAME} <gamertag> <platform> <slot>\n"
    output += "Please use the 'help' command for more info."

    output.strip!

    client.say(text: output, channel: data.channel)
  end

  def self.get_hex_color_for_damage_type(damage_type)
    damage_type_key = damage_type.downcase.to_sym
    DAMAGE_COLOR[damage_type_key] || DAMAGE_COLOR[:kinetic]
  end
end


raise 'BUNGIE_API_KEY not set' unless ENV['BUNGIE_API_TOKEN']
$bungie_api = BungieApi.new(ENV['BUNGIE_API_TOKEN'])

GunsmithBot.run
