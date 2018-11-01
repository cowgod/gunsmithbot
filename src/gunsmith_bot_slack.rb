require 'slack-ruby-bot'
require_relative 'gunsmith_bot'
require_relative 'query_error'

require_relative '../lib/monkey_patches'


class GunsmithBotSlack < SlackRubyBot::Bot
  BOT_NAME     = 'Banshee-44'.freeze
  BOT_ICON_URL = 'http://binrock.net/banshee44.png'.freeze
  BOT_USERNAME = (ENV['GUNSMITH_BOT_USERNAME'] || 'gunsmithbot')


  command 'help' do |client, data, _|
    output = <<~HELP
      To show off your weapon/armor, message the bot with your gamertag, network, and weapon/armor slot, separated by spaces. The bot will always look at the *most recently played character* on your account.
      The standard usage looks like this: ```@#{BOT_USERNAME} MyGamerTag playstation kinetic```
      
      If you've set up your Slack profile so that your *title* ("What I Do") matches your in-game username, you can omit this: ```@#{BOT_USERNAME} playstation helmet```
      
      If your gamertag only exists on one network, that can be omitted as well: ```@#{BOT_USERNAME} heavy```
      
      Alternatively, instead of a specific slot, you can say `loadout`, and you'll get a complete summary of every weapon and armor piece currently equipped.
      
      The full list of supported slots is:```#{BungieApi::ITEM_BUCKET_IDS.values.map {|bucket_id| BungieApi.get_bucket_code(bucket_id)}.reject(&:blank?).join(', ')}, loadout```
      
      *Special note to Xbox Users:*
      If your gamertag has any spaces in it, these will need to be substituted with underscores (`_`) in order for the bot to recognize the input properly.
      This is only required when inputting the gamertag manually however; spaces are fine in your Slack title.
      
      _Keep that thing oiled, guardian._
    HELP

    client.say(text: output, channel: data.channel)
  end

  command(/.*/) do |client, data, _|
    results = nil

    # Make it look like we're typing
    client.typing(channel: data.channel)

    begin
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
          raise ArgumentError, 'Wrong number of arguments.'
      end


      if requested_slot.strip.downcase == 'loadout'
        results = $gunsmith_bot.query_loadout(requested_gamertag, requested_platform)
        break if results.blank?

        loadout_response(client, data, results)
      else
        results = $gunsmith_bot.query(requested_gamertag, requested_platform, requested_slot)
        break if results.blank?

        single_slot_response(client, data, results)
      end
    rescue QueryError => message
      print_usage(client, data, message)
    end
  end


  def self.single_slot_response(client, data, results)
    # Prepare output
    destiny_tracker_url = "https://db.destinytracker.com/d2/en/items/#{URI.encode(results[:item][:hash])}"
    icon_url            = results[:item][:has_icon] ? "https://www.bungie.net/#{URI.encode(results[:item][:icon])}" : nil


    message_text = ''
    message_text += "<@#{data&.user}>: " unless data&.user&.blank?
    message_text += "`#{results[:gamertag]} #{results[:platform]} #{results[:slot]}`\n"

    unless results[:gamertag_suggestions]&.blank?
      message_text += 'Gamertag Suggestions: '

      message_text += results[:gamertag_suggestions]
        .take(5)
        .map { |gamertag| "`#{gamertag}`" }
        .join(', ')
    end

    message_text.strip!


    attachment_title    = results[:item][:name]
    attachment_text     = "#{results[:item][:type_and_tier]} - #{results[:item][:power_level]} PL\n#{results[:item][:description]}"
    attachment_fallback = "#{results[:item][:name]} - #{results[:item][:type_and_tier]} - #{results[:item][:power_level]} PL - #{results[:item][:description]}"
    attachment_color    = BungieApi.get_hex_color_for_damage_type(results[:item].dig(:masterwork, :damage_resistance_type) || results[:item].dig(:damage_type))

    attachment_fields = []

    # Perks
    field_text = results[:item][:perk_sockets]
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
                               title: 'Perks',
                               value: field_text,
                               short: false
                             })
    end


    # Masterwork / Mod
    attachment_fields.push({
                             title: 'Masterwork',
                             value: results[:item][:masterwork] ? "#{results[:item][:masterwork][:affected_stat]} - #{results[:item][:masterwork][:value]}" : 'n/a',
                             short: true
                           })

    attachment_fields.push({
                             title: 'Mod',
                             ### TODO -- get rid of description?
                             value: results[:item][:mod] ? results[:item][:mod][:name].to_s : 'n/a',
                             short: true
                           })


    # Stats
    stat_abbreviations = {
      'Rounds Per Minute' => 'RPM',
      'Reload Speed'      => 'Reload',
      # 'Magazine' => 'Mag'
    }

    attachment_footer = results[:item][:stats]
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
                       color:       attachment_color,
                       title:       attachment_title,
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


  def self.loadout_response(client, data, results)
    # Prepare output

    message_text = ''
    message_text += "<@#{data&.user}>: " unless data&.user&.blank?
    message_text += "`#{results[:gamertag]} #{results[:platform]} loadout`\n"

    unless results[:gamertag_suggestions]&.blank?
      message_text += 'Gamertag Suggestions: '

      message_text += results[:gamertag_suggestions]
        .take(5)
        .map { |gamertag| "`#{gamertag}`" }
        .join(', ')
    end

    message_text += "\n#{results&.dig(:slots, :SUBCLASS, :name)}"

    message_text.strip!


    attachments = []

    results[:slots].each do |slot, item|
      destiny_tracker_url = "https://db.destinytracker.com/d2/en/items/#{URI.encode(item[:hash])}"
      icon_url            = item[:has_icon] ? "https://www.bungie.net/#{URI.encode(item[:icon])}" : nil

      # attachment_title    = results[:item][:name]
      # attachment_text     = "#{results[:item][:type_and_tier]} - #{results[:item][:power_level]} PL\n#{results[:item][:description]}"
      # attachment_fallback = "#{results[:item][:name]} - #{results[:item][:type_and_tier]} - #{results[:item][:power_level]} PL - #{results[:item][:description]}"

      attachment_fields = []

      next unless %i[KINETIC_WEAPON ENERGY_WEAPON HEAVY_WEAPON HEAD ARMS CHEST LEGS CLASS_ITEM].include?(slot)

      attachment_title = "[#{BungieApi.get_bucket_name(slot)}]: #{item[:name]} (#{item[:type_and_tier]} - #{item[:power_level]} PL)"

      attachment_color = BungieApi.get_hex_color_for_damage_type(item.dig(:masterwork, :damage_resistance_type) || item.dig(:damage_type))

      field_text = '- Perks: '

      field_text += item[:perk_sockets]
        .map do |perk_socket|
        perk_socket
          .select { |perk| perk[:selected] }
          .map { |perk| perk[:name] }
          .join(', ')
      end
        .join(', ')

      if item[:masterwork]
        field_text += "\n- Masterwork: #{item[:masterwork][:affected_stat]} - #{item[:masterwork][:value]}"
      end

      if item[:mod]
        field_text += "\n- Mod: #{item[:mod][:name]}"
      end

      next if field_text.blank? || field_text == '- Perks: '

      attachment_fields.push({
                               # title: field_title,
                               value: field_text,
                               short: false
                             })

      attachments.push(
        {
          color:      attachment_color,
          title:      attachment_title,
          title_link: destiny_tracker_url,
          thumb_url:  icon_url,
          # text:       attachment_text,
          # fallback:    attachment_fallback,
          fields: attachment_fields,
          # footer_icon: BOT_ICON_URL,
          # footer:      BOT_NAME,
          # footer: attachment_footer,
          # ts:        Time.now.to_i,
          mrkdwn_in: ['fields']
        }
      )
    end


    # attachment_footer = 'No stats, but it sure looks pretty' if attachment_footer.blank?


    client.web_client.chat_postMessage(
      channel:     data.channel,
      as_user:     true,
      text:        message_text,
      attachments: attachments.to_json
    )
  end


  def self.print_usage(client, data, additional_message = nil)
    output = ''

    output += "<@#{data&.user}>: " unless data&.user&.blank?
    output += additional_message.to_s unless additional_message&.blank?
    output += "\n"

    output += "Usage: @#{BOT_USERNAME} <gamertag> <platform> <slot>\n"
    output += "Please use the 'help' command for more info."

    output.strip!

    client.say(text: output, channel: data.channel)
  end
end


$gunsmith_bot = GunsmithBot.new

GunsmithBotSlack.run
