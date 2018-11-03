require 'discordrb'
require_relative 'gunsmith_bot'
require_relative 'query_error'

require_relative '../lib/monkey_patches'

require 'pp'


class GunsmithBotDiscord < Discordrb::Bot
  BOT_NAME     = 'Banshee-44'.freeze
  BOT_ICON_URL = 'http://binrock.net/banshee44.png'.freeze
  BOT_USERNAME = (ENV['GUNSMITH_BOT_USERNAME'] || 'gunsmithbot')


  def initialize(prefix: '!')
    raise 'DISCORD_API_KEY not set' unless ENV['DISCORD_API_TOKEN'].present?

    @prefix = prefix
    @bot    = Discordrb::Commands::CommandBot.new token: ENV['DISCORD_API_TOKEN'], prefix: @prefix, name: BOT_NAME


    # Here we output the invite URL to the console so the bot account can be invited to the channel. This only has to be
    # done once, afterwards, you can remove this part if you want
    # puts "This bot's invite URL is #{@bot.invite_url}."
    # puts 'Click on it to invite it to your server.'

    # @bot.message(with_text: 'Ping!') do |event|
    #   event.respond 'Pong!'
    # end


    @bot.command :help do
      <<HELP
To show off your weapon/armor, message the bot with your gamertag, network, and weapon/armor slot, separated by spaces. The bot will always look at the *most recently played character* on your account.
The standard usage looks like this: ```#{@prefix}show MyGamerTag playstation kinetic```

If your gamertag is the same as your Discord username, you can omit this: ```#{@prefix}show playstation helmet```

If your gamertag only exists on one network, that can be omitted as well: ```#{@prefix}show heavy```

*Special note to Xbox Users:*
If your gamertag has any spaces in it, these will need to be substituted with underscores (\"_\") in order for the bot to recognize the input properly.
This is only required when inputting the gamertag manually however; spaces are fine in your Slack title.\n\n
_Keep that thing oiled, guardian._
HELP
    end

    @bot.command :show do |event, *args|
      results = nil

      # Make it look like we're typing
      event&.channel&.start_typing

      begin
        case args.length
          when 1
            # If they didn't provide a gamertag, use the first name of the Slack
            # user. If it's not set, use their title ("What I do")

            # TODO - figure out what field we can use in Discord for this
            # requested_gamertag = client.store.users[data.user][:profile][:title] || client.store.users[data.user][:name]
            requested_gamertag = event.user.name
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
            raise QueryError, 'Wrong number of arguments.'
        end


        if requested_slot.strip.downcase == 'loadout'
          results = $gunsmith_bot.query_loadout(requested_gamertag, requested_platform)
          break if results.blank?

          loadout_response(event, results)
        else
          results = $gunsmith_bot.query(requested_gamertag, requested_platform, requested_slot)
          break if results.blank?

          single_slot_response(event, results)
        end
      rescue QueryError => message
        print_usage(event: event, additional_message: message)
      end

      nil
    end
  end

  def single_slot_response(event, results)
    # Prepare output
    destiny_tracker_url = "https://db.destinytracker.com/d2/en/items/#{URI.encode(results[:item][:hash])}"
    icon_url            = results[:item][:has_icon] ? "https://www.bungie.net#{URI.encode(results[:item][:icon])}" : nil


    message_text = "<@#{event&.user&.id}>: "
    message_text += "`#{results[:gamertag]} #{results[:platform]} #{results[:slot]}`\n"

    if results[:gamertag_suggestions].present?
      message_text += 'Gamertag Suggestions: '

      message_text += results[:gamertag_suggestions]
        .take(5)
        .map { |gamertag| "`#{gamertag}`" }
        .join(', ')
    end

    message_text.strip!


    attachment_title = results[:item][:name]
    attachment_text  = "#{results[:item][:type_and_tier]} - #{results[:item][:power_level]} PL\n#{results[:item][:description]}"


    attachment_fields = []

    # Perks
    field_text = results[:item][:perk_sockets]
      .map do |perk_socket|
      perk_socket.map do |perk|
        perk[:selected] ? "**#{perk[:name]}**" : perk[:name]
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


    event&.channel&.send_embed(message_text) do |embed|
      embed.title       = attachment_title
      embed.description = attachment_text
      embed.color       = BungieApi.get_hex_color_for_damage_type(results[:item][:damage_type])
      embed.url         = destiny_tracker_url
      embed.thumbnail   = Discordrb::Webhooks::EmbedImage.new(url: icon_url)
      embed.footer      = Discordrb::Webhooks::EmbedFooter.new(text: attachment_footer, icon_url: BOT_ICON_URL)
      embed.timestamp   = Time.now

      attachment_fields.each do |field|
        new_field          = {}
        new_field[:name]   = field.dig(:title) || '.'
        new_field[:value]  = field.dig(:value) || '.'
        new_field[:inline] = !!field.dig(:short)

        embed.add_field(new_field)
      end
    end

    nil
  end

  def loadout_response(event, results)
    # Prepare output

    message_text = "<@#{event&.user&.id}>: "
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


    event&.channel&.send_message(message_text)

    attachments.each do |attachment|
      event&.channel&.send_embed do |embed|
        embed.title       = attachment[:title]
        # embed.description = attachment_text
        embed.color     = BungieApi.get_hex_color_for_damage_type(attachment[:color])
        embed.url       = attachment[:title_link]
        embed.thumbnail = Discordrb::Webhooks::EmbedImage.new(url: attachment[:thumb_url])
        # embed.footer    = Discordrb::Webhooks::EmbedFooter.new(text: attachment_footer, icon_url: BOT_ICON_URL)
        # embed.timestamp = Time.now

        attachment[:fields].each do |field|
          new_field          = {}
          new_field[:name]   = field.dig(:title) || '.'
          new_field[:value]  = field.dig(:value) || '.'
          new_field[:inline] = !!field.dig(:short)

          embed.add_field(new_field)
        end
      end
    end

    nil
  end

  def run
    @bot.run
  end

  def print_usage(event:, additional_message:)
    # Be sure we have a webhook connection available to respond with
    # return unless @webhook_clients[event&.channel&.id].present?

    output = ''

    output += "<@#{event&.user&.id}>: " unless event&.user.blank?
    output += additional_message.to_s unless additional_message.blank?
    output += "\n"

    output += "Usage: #{@prefix}show <gamertag> <platform> <slot>\n"
    output += "Please use the 'help' command for more info."

    output.strip!

    event&.channel&.send_message output
  end
end


$gunsmith_bot = GunsmithBot.new
bot           = GunsmithBotDiscord.new
bot.run

