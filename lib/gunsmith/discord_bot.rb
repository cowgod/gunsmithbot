# frozen_string_literal: true
require 'discordrb'
require 'discordrb/webhooks'

require 'pp'


module Gunsmith
  # Wrapper for GunsmithBot class, to adapt it to usage in Discord
  class DiscordBot < Discordrb::Bot
    DISCORD_CLIENT_ID = 496066614614294529

    BANSHEE_BOT_NAME     = 'Banshee-44'
    BANSHEE_BOT_ICON_URL = 'https://i.imgur.com/bYLc6Hn.png'
    BANSHEE_BOT_USERNAME = (ENV['GUNSMITH_BOT_USERNAME'] || 'banshee-44')

    SAINT_BOT_NAME     = 'Saint-14'
    SAINT_BOT_ICON_URL = 'https://i.imgur.com/t0xjaer.png'
    # SAINT_BOT_USERNAME = (ENV['GUNSMITH_BOT_USERNAME'] || 'banshee-44')

    attr_reader :bot


    def initialize
      raise 'DISCORD_API_KEY not set' unless ENV['DISCORD_API_TOKEN'].present?

      @bot = Discordrb::Bot.new token: ENV['DISCORD_API_TOKEN'], name: BANSHEE_BOT_NAME, client_id: DISCORD_CLIENT_ID


      # Here we output the invite URL to the console so the bot account can be invited to the channel. This only has to be
      # done once, afterwards, you can remove this part if you want
      Cowgod::Logger.log "#{self.class}.#{__method__} - This bot's invite URL is #{@bot.invite_url}"
      Cowgod::Logger.log "#{self.class}.#{__method__} - Click on it to invite it to your server."


      @bot.mention do |event|
        # Make it look like we're typing
        event&.channel&.start_typing


        # Split the input into words, and strip out the element that represents
        # our own userid (which will look something like '<@!UCNTC2YH0>')
        args = event.message.content&.split(/\s+/)&.grep_v(/^<@[A-Z0-9!]+>$/)


        case args[0].downcase
        when 'help'

          output = <<HELP
            To show off your weapon/armor, message the bot with your Bungie Name and weapon/armor slot, separated by spaces. The bot will always look at the *most recently played character* on your account.
            The standard usage looks like this:

            ```@#{BANSHEE_BOT_USERNAME} <bungie_name> <slot>```

            For example:

            ```@#{BANSHEE_BOT_USERNAME} MyBungieName#1234 kinetic```

            If you've registered with the bot (`@#{BANSHEE_BOT_USERNAME} register <bungie_name>`) then you can simply list the slot to display:

            ```@#{BANSHEE_BOT_USERNAME} kinetic```

            In addition to requesting a specific slot, you can say `weapons`, `armor`, or `loadout`, and you'll get a complete summary of every currently equipped weapon, armor piece, or both.

            The full list of supported slots is:```#{Bungie::Api::ITEM_BUCKET_IDS.values.map { |bucket_id| Bungie::Api.get_bucket_code(bucket_id) }.reject(&:blank?).join(', ')}, weapons, armor, loadout```

            To enable or disable reporting of your Twitch clips (if configured on this server), use the following command:

            ```@#{BANSHEE_BOT_USERNAME} twitch <off|on>```

            The Twitch Clip setting is per-server, and it applies to the server in which you message the bot with the command. 

            GitHub Repository: #{Gunsmith::Bot::BOT_GITHUB_URL}

            _Keep that thing oiled, guardian._
HELP


          # Respond via DM
          event.user.pm output
          next


        when 'register'

          # Start out our response by tagging the user that messaged us
          message_text = ''
          message_text += "#{event.user&.mention}: " unless event.user.blank?

          requested_bungie_name = args[1]

          unless requested_bungie_name
            message_text += "Usage: `@#{BANSHEE_BOT_USERNAME} register <bungie_name>`"
            event.channel&.send_message message_text
            next
          end


          bungie_membership = if requested_bungie_name.positive_integer?
            # If they provided a numeric bungie.net membership ID, look them up by that
            Bungie::Membership.load_by_id(requested_bungie_name)
          else
            # Otherwise, try to search for them by Bungie Name
            Bungie::Membership.load_by_bungie_name(requested_bungie_name)
          end

          # If we didn't find a membership, print an error
          unless bungie_membership
            print_user_not_found_message(event: event, requested_bungie_name: requested_bungie_name)
            break
          end


          # Associate the specified Bungie.net membership with the Discord user who made the request
          discord_user             = Discord::User.find_or_initialize_by(user_id: event&.message&.author&.id)
          discord_user.username    = event&.message&.author&.username
          discord_user.bungie_user = bungie_membership.bungie_user
          discord_user.save

          discord_server      = Discord::Server.find_or_initialize_by(server_id: event&.message&.server&.id)
          discord_server.name = event&.message&.server&.name
          discord_server.save

          discord_membership                     = Discord::Membership.find_or_initialize_by(user: discord_user, server: discord_server)
          discord_membership.notify_twitch_clips = true
          discord_membership.save


          message_text += "Successfully registered you with Bungie Name `#{bungie_membership.bungie_name}`."

          message_text.strip!

          event.channel&.send_message message_text


        when 'twitch', 'twitchclips', 'twitch_clips', 'clips'

          # Let's save info about the user, server, and membership, even if we don't know their Bungie account
          discord_user          = Discord::User.find_or_initialize_by(user_id: event&.message&.author&.id)
          discord_user.username = event&.message&.author&.username
          discord_user.save

          discord_server      = Discord::Server.find_or_initialize_by(server_id: event&.message&.server&.id)
          discord_server.name = event&.message&.server&.name
          discord_server.save

          discord_membership                     = Discord::Membership.find_or_initialize_by(user: discord_user, server: discord_server)
          discord_membership.notify_twitch_clips = false
          discord_membership.save


          unless discord_user.bungie_user
            print_unregistered_user_message(event: event)
            next
          end


          # Set the 'notify_twitch_clips' setting for the user who called us
          discord_membership.notify_twitch_clips = !(args[1]&.match?(/no|false|off|0|cancel/i))
          discord_membership.save


          # Reply to the user that messaged us
          message_text = "#{event.user&.mention}: " unless event.user.blank?
          message_text += "Successfully set your Twitch Clips preference for the '#{discord_server.name}' server to: `#{discord_membership.notify_twitch_clips ? 'ON' : 'OFF'}`."

          event.channel&.send_message message_text.strip


        else

          begin
            bungie_membership = nil


            case args.length
            when 1
              requested_bungie_name = nil
              requested_slot        = args[0]

              # If they just provided a slot, see if they're registered with us
              discord_user      = Discord::User.find_by(user_id: event.message.author.id)
              bungie_membership = discord_user&.bungie_user&.memberships&.first
            when 2..Float::INFINITY
              # Grab everything but the last argument as the Bungie Name
              requested_bungie_name = args[0..-2].join(' ')
              requested_slot        = args[-1]
            else
              raise ArgumentError, 'Wrong number of arguments.'
            end


            # If they aren't registered with us, see if we can find the user in the API
            if !bungie_membership && requested_bungie_name
              bungie_membership = if requested_bungie_name.positive_integer?
                # If they provided a numeric bungie.net membership ID, look them up by that
                Bungie::Membership.load_by_id(requested_bungie_name)
              else
                # Otherwise, try to search for them by Bungie Name
                Bungie::Membership.load_by_bungie_name(requested_bungie_name)
              end
            end

            # If we still didn't find it, print an error
            unless bungie_membership
              print_unregistered_user_message(event: event)
              next
            end

            unless requested_slot
              print_usage(event: event, additional_message: message)
              next
            end


            ## Fixup the DB record. If it's missing the Bungie User, fetch it and save it
            unless bungie_membership.bungie_user
              bungie_membership.bungie_user = Bungie::User.load_by_destiny_membership_id(bungie_membership.membership_id)
              bungie_membership.save
            end


            case requested_slot.strip.downcase
            when 'loadout', 'weapons', 'weapon', 'guns', 'gun', 'armor'
              loadout_type = case requested_slot.strip.downcase
              when 'weapons', 'weapon', 'guns', 'gun'
                :weapons
              when 'armor'
                :armor
              else
                :full
              end

              results = Gunsmith::Bot.instance.query_loadout(bungie_membership, loadout_type)
              next if results.blank?

              loadout_response(event, results, loadout_type)
            else
              results = Gunsmith::Bot.instance.query(bungie_membership, requested_slot)
              next if results.blank?

              single_slot_response(event, results)
            end
          rescue QueryError => e
            print_usage(event: event, additional_message: e)
          end

        end

        nil
      end
    end


    def single_slot_response(event, results)
      # Prepare output
      destiny_tracker_url = "https://db.destinytracker.com/d2/en/items/#{results[:item][:hash].uri_encode}"
      icon_url            = results[:item][:has_icon] ? "https://www.bungie.net#{results[:item][:icon]}" : nil


      message_text = "#{event&.user&.mention}: "
      message_text += "`#{results[:bungie_membership].bungie_name} #{results[:slot]}`\n"

      # if results[:gamertag_suggestions].present?
      #   message_text += 'Gamertag Suggestions: '
      #
      #   message_text += results[:gamertag_suggestions]
      #     .take(5)
      #     .map { |gamertag| "`#{gamertag}`" }
      #     .join(', ')
      # end

      message_text.strip!


      attachment_title = results[:item][:name]

      attachment_text = ''
      attachment_text += "#{results[:item][:type_and_tier]} - **#{results[:item][:power_level]} PL**"
      attachment_text += results[:item]&.dig(:objectives)
        &.map { |objective| "\n- _#{objective&.dig(:label)}_: **#{objective&.dig(:value)&.to_formatted_s}**" }
        &.join(', ').to_s
      attachment_text += "\n#{results[:item][:description]}\n"
      attachment_text.strip!


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

      if results[:item][:armor2_0]
        # Instead of masterwork/mod, show the energy level
        attachment_fields.push({
                                 title: 'Element',
                                 value: results[:item][:energy_type],
                                 short: true
                               })

        attachment_fields.push({
                                 title: 'Energy',
                                 value: "#{results[:item][:energy_capacity]} / #{Bungie::Api::MAX_ENERGY} (#{results[:item][:energy_used]} used)",
                                 short: true
                               })
      else
        # Masterwork / Mod
        masterwork = 'n/a'
        if results[:item][:masterwork]
          masterwork = if results&.dig(:item, :masterwork, :affected_stat)
            "#{results[:item][:masterwork][:affected_stat]} - #{results[:item][:masterwork][:value]}"
          else
            'Yes'
          end
        end
        attachment_fields.push({
                                 title: 'Masterwork',
                                 value: masterwork,
                                 short: true
                               })

        attachment_fields.push({
                                 title: 'Mod',
                                 ### TODO -- get rid of description?
                                 value: results[:item][:mod] ? results[:item][:mod][:name].to_s : 'n/a',
                                 short: true
                               })
      end


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
        embed.title       = attachment_title[0..255]
        embed.description = attachment_text[0..4095]
        embed.color       = Bungie::Api.get_hex_color_for_damage_type(results[:item][:damage_type])
        embed.url         = destiny_tracker_url
        embed.thumbnail   = Discordrb::Webhooks::EmbedImage.new(url: icon_url)
        embed.footer      = Discordrb::Webhooks::EmbedFooter.new(text: attachment_footer, icon_url: BANSHEE_BOT_ICON_URL)
        embed.timestamp   = Time.now

        attachment_fields.each do |field|
          embed.add_field(
            name:   (field[:title] || '.')[0..255],
            value:  (field[:value] || '.')[0..1023],
            inline: ActiveModel::Type::Boolean.new.cast(field[:short])
          )
        end
      end

      nil
    end


    def loadout_response(event, results, type = :full)
      # Prepare output

      canonical_loadout_type = case type
      when :weapons
        'weapons'
      when :armor
        'armor'
      else
        'loadout'
      end

      message_text = "#{event&.user&.mention}: "
      message_text += "`#{results[:bungie_membership].bungie_name} #{canonical_loadout_type}`\n"


      # if results[:gamertag_suggestions]&.present?
      #   message_text += 'Gamertag Suggestions: '
      #
      #   message_text += results[:gamertag_suggestions]
      #     .take(5)
      #     .map { |gamertag| "`#{gamertag}`" }
      #     .join(', ')
      # end

      message_text += "\n#{results&.dig(:slots, :SUBCLASS, :name)}"

      message_text.strip!


      attachments = []

      slots_to_query = Bot.slots_for_loadout_type(type)

      results[:slots].each do |slot, item|
        destiny_tracker_url = "https://db.destinytracker.com/d2/en/items/#{item[:hash].uri_encode}"
        icon_url            = item[:has_icon] ? "https://www.bungie.net/#{item[:icon]}" : nil


        attachment_fields = []

        # If they requested a more limited loadout like 'weapons' or 'armor', then filter the fields we're returning
        next unless slots_to_query.include?(slot)

        # Even if they requested a full loadout, we don't care about certain fields like emblems
        next unless %i[KINETIC_WEAPON ENERGY_WEAPON HEAVY_WEAPON HEAD ARMS CHEST LEGS CLASS_ITEM].include?(slot)

        attachment_title = "[#{Bungie::Api.get_bucket_name(slot)}]: #{item[:name]} (#{item[:type_and_tier]} - #{item[:power_level]} PL)"

        attachment_color = Bungie::Api.get_hex_color_for_damage_type(item.dig(:masterwork, :damage_resistance_type) || item[:damage_type])

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

        field_text += "\n- Mod: #{item[:mod][:name]}" if item[:mod]

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
          embed.title = attachment[:title][0..255]
          # embed.description = attachment_text[0..4095]
          embed.color     = Bungie::Api.get_hex_color_for_damage_type(attachment[:color])
          embed.url       = attachment[:title_link]
          embed.thumbnail = Discordrb::Webhooks::EmbedImage.new(url: attachment[:thumb_url])
          # embed.footer    = Discordrb::Webhooks::EmbedFooter.new(text: attachment_footer, icon_url: BOT_ICON_URL)
          # embed.timestamp = Time.now

          attachment[:fields].each do |field|
            embed.add_field(
              name:   (field[:title] || '.')[0..255],
              value:  (field[:value] || '.')[0..1023],
              inline: ActiveModel::Type::Boolean.new.cast(field[:short])
            )
          end
        end
      end

      nil
    end


    def run
      @bot.run
    end


    def print_unregistered_user_message(event:)
      # Be sure we have a webhook connection available to respond with
      # return unless @webhook_clients[event&.channel&.id].present?

      output = ''

      output += "#{event&.user&.mention}: " unless event&.user.blank?

      output += "Memory's not what it used to be. Who're you again?\n"
      output += "Use `@#{BANSHEE_BOT_USERNAME} register <bungie_name>` to register your Bungie.net profile.\n"
      output += "Use the 'help' command for more info."

      output.strip!

      event&.channel&.send_message output
    end


    def print_user_not_found_message(event:, requested_bungie_name:)
      # Be sure we have a webhook connection available to respond with
      # return unless @webhook_clients[event&.channel&.id].present?

      output = ''

      output += "#{event&.user&.mention}: " unless event&.user.blank?

      output += "Couldn't find a user for Bungie Name '#{requested_bungie_name}'."
      output += "Use the 'help' command for more info."

      output.strip!

      event&.channel&.send_message output
    end


    def print_usage(event:, additional_message:)
      # Be sure we have a webhook connection available to respond with
      # return unless @webhook_clients[event&.channel&.id].present?

      output = ''

      output += "#{event&.user&.mention}: " unless event&.user.blank?
      output += additional_message.to_s unless additional_message.blank?
      output += "\n"

      output += "Usage: `@#{BANSHEE_BOT_USERNAME} <bungie_net> <slot>`\n"
      output += "Please use the 'help' command for more info."

      output.strip!

      event&.channel&.send_message output
    end


    def self.notify_twitch_clip(clip:, webhook_url:)
      raise ArgumentError unless clip && webhook_url


      streamer_name     = clip.twitch_video&.twitch_user&.display_name || '(unknown)'
      map_name          = clip.activity&.map_name || '(unknown)'
      activity_name     = clip.activity&.activity_name || '(unknown)'
      map_thumbnail_url = clip.activity&.map_thumbnail_url
      clip_url          = clip.url


      body_username = CONFIG&.dig('twitch_clips', 'bot_name') || SAINT_BOT_NAME

      embed_title     = "#{streamer_name} played #{activity_name} on #{map_name}"
      embed_timestamp = clip.activity.started_at


      discord_users_to_mention = []
      embed_fields             = []


      clip.tracked_players&.map(&:bungie_user)&.each do |bungie_user|
        discord_users_to_mention += bungie_user.discord_users.to_a


        # Find the player that corresponds to this bungie_user
        player = clip.activity&.players&.select { |player| player.bungie_user == bungie_user }&.first
        next unless player

        field_text =
          [
            "**K:** #{player.kills}",
            "**D:** #{player.deaths}",
            "**K/D:** #{player.kd}"
          ].join(' **|** ')

        embed_fields.push({
                            name:   bungie_user.bungie_name,
                            value:  field_text,
                            inline: false
                          })
      end

      body_text = 'New Twitch clip found'
      body_text += " featuring #{discord_users_to_mention.map(&:mention).to_sentence}" if discord_users_to_mention
      body_text += ':'


      Cowgod::Logger.log "#{self.class}.#{__method__} - Notifying clip: #{embed_title} (#{embed_timestamp.getlocal.strftime('%Y-%m-%d %I:%M %P')})"

      client = Discordrb::Webhooks::Client.new(url: webhook_url)

      begin
        client.execute do |builder|
          builder.username   = body_username
          builder.avatar_url = SAINT_BOT_ICON_URL
          builder.content    = body_text

          builder.add_embed do |embed|
            embed.timestamp = embed_timestamp
            embed.title     = embed_title
            embed.url       = clip_url
            embed.thumbnail = Discordrb::Webhooks::EmbedImage.new(url: map_thumbnail_url)
            embed.fields    = embed_fields if embed_fields.size.positive?
          end
        end
      rescue RestClient::BadRequest => e
        Cowgod::Logger.log "#{self.class}.#{__method__} - ERROR: #{e}"
      end

      true
    end
  end
end



