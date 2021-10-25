# frozen_string_literal: true
require 'slack-ruby-bot'


module Gunsmith
  # Wrapper for GunsmithBot class, to adapt it to usage in Slack
  class SlackBot < SlackRubyBot::Bot
    BANSHEE_BOT_NAME     = 'Banshee-44'
    BANSHEE_BOT_ICON_URL = 'https://i.imgur.com/bYLc6Hn.png'
    BANSHEE_BOT_USERNAME = (ENV['GUNSMITH_BOT_USERNAME'] || 'banshee-44')

    SAINT_BOT_NAME     = 'Saint-14'
    SAINT_BOT_ICON_URL = 'https://i.imgur.com/t0xjaer.png'
    # SAINT_BOT_USERNAME = (ENV['GUNSMITH_BOT_USERNAME'] || 'banshee-44')

    IGNORED_CHANNELS = [
      'C13V2MUBA' # FPVChat #gaming
    ].freeze


    command 'help' do |client, data, _|
      output = <<~HELP
        To show off your weapon/armor, message the bot with your Bungie Name and weapon/armor slot, separated by spaces. The bot will always look at the *most recently played character* on your account.
        The standard usage looks like this:

        ```@#{BANSHEE_BOT_USERNAME} <bungie_name> <slot>```

        For example:

        ```@#{BANSHEE_BOT_USERNAME} MyBungieName#1234 kinetic```

        If you've registered with the bot (`@#{BANSHEE_BOT_USERNAME} register <bungie_name>`) then you can simply list the slot to display:

        ```@#{BANSHEE_BOT_USERNAME} kinetic```

        In addition to requesting a specific slot, you can say `weapons`, `armor`, or `loadout`, and you'll get a complete summary of every currently equipped weapon, armor piece, or both.

        The full list of supported slots is:```#{Bungie::Api::ITEM_BUCKET_IDS.values.map { |bucket_id| Bungie::Api.get_bucket_code(bucket_id) }.reject(&:blank?).join(', ')}, weapons, armor, loadout```

        GitHub Repository: #{Gunsmith::Bot::BOT_GITHUB_URL}

        _Keep that thing oiled, guardian._
      HELP


      # Respond via DM
      client.web_client.chat_postMessage(
        channel: data.user,
        as_user: true,
        text:    output
      )
    end


    command 'register' do |client, data, _|
      # Don't respond in ignored channels
      next if IGNORED_CHANNELS.include? data.channel


      # Make it look like we're typing
      client.typing(channel: data.channel)

      # Start out our response by tagging the user that messaged us
      message_text = ''
      message_text += "<@#{data.user}>: " unless data.user&.blank?

      # Split the input into words, and strip out the element that represents
      # our own userid (which will look something like '<@UCNTC2YH0>')
      args = data.text&.split(/\s+/)&.grep_v(/^<@[A-Z0-9]+>$/)

      # Grab all parameters and combine them as one string
      requested_bungie_name = args[1..].join(' ')

      unless requested_bungie_name
        message_text += "Usage: `@#{BANSHEE_BOT_USERNAME} register <bungie_name>`"
        client.say(text: message_text, channel: data.channel)
        next
      end


      bungie_membership = if requested_bungie_name.positive_integer?
        Bungie::Membership.load_by_id(requested_bungie_name)
      else
        Bungie::Membership.load_by_bungie_name(requested_bungie_name)
      end

      # If we didn't find a membership, print an error
      unless bungie_membership
        print_user_not_found_message(client, data, requested_bungie_name)
        next
      end

      ## Fixup the DB record. If it's missing the Bungie User, fetch it and save it
      unless bungie_membership.bungie_user
        bungie_membership.bungie_user = Bungie::User.load_by_destiny_membership_id(bungie_membership.membership_id)
        bungie_membership.save
      end


      team = load_and_update_team(client.team.id, client.team.name, client.team.domain)

      # Associate the specified Bungie.net user with the Slack user who made the request
      user             = Slack::User.find_or_initialize_by(team: team, user_id: data.user)
      user.bungie_user = bungie_membership.bungie_user
      user.save


      message_text += "Successfully registered you with Bungie Name `#{bungie_membership.bungie_name}`."

      client.say(text: message_text, channel: data.channel)
    end


    command(/.*/) do |client, data, _|
      # Don't respond in ignored channels
      next if IGNORED_CHANNELS.include? data.channel


      # Make it look like we're typing
      client.typing(channel: data.channel)

      begin
        bungie_membership = nil


        # Split the input into words, and strip out the element that represents our own
        # userid (which will look something like '<@UCNTC2YH0>')
        args = data.text.split(/\s+/).grep_v(/^<@[A-Z0-9]+>$/)

        case args.length
        when 1
          requested_bungie_name = nil
          requested_slot        = args[0]

          # If they just provided a slot, see if they're registered with us
          team              = Slack::Team.find_by(team_id: client.team.id)
          user              = Slack::User.find_by(team: team, user_id: data.user)
          bungie_membership = user&.bungie_user&.memberships&.first
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
            # Otherwise, try to search for them by display name. This will only work if it's unique
            Bungie::Membership.load_by_bungie_name(requested_bungie_name)
          end
        end

        # If we still didn't find it, print an error
        unless bungie_membership
          print_unregistered_user_message(client, data)
          next
        end

        unless requested_slot
          print_usage(client, data)
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

          loadout_response(client, data, results, loadout_type)
        else
          results = Gunsmith::Bot.instance.query(bungie_membership, requested_slot)
          next if results.blank?

          single_slot_response(client, data, results)
        end
      rescue QueryError => e
        print_usage(client, data, e)
      end
    end


    def self.single_slot_response(client, data, results)
      # Prepare output
      destiny_tracker_url = "https://db.destinytracker.com/d2/en/items/#{results[:item][:hash].uri_encode}"
      icon_url            = results[:item][:has_icon] ? "https://www.bungie.net/#{results[:item][:icon]}" : nil

      message_text = ''
      message_text += "<@#{data&.user}>: " unless data&.user&.blank?
      message_text += "`#{results[:bungie_membership].bungie_name} #{results[:slot]}`\n"

      # if results[:gamertag_suggestions]&.present?
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
      attachment_text += "#{results[:item][:type_and_tier]} - *#{results[:item][:power_level]} PL*"
      attachment_text += results[:item]&.dig(:objectives)
        &.map { |objective| "\n- _#{objective&.dig(:label)}_: *#{objective&.dig(:value)&.to_formatted_s}*" }
        &.join(', ').to_s
      attachment_text += "\n#{results[:item][:description]}\n"
      attachment_text.strip!

      attachment_fallback = attachment_text.gsub(/\n/, ' - ')

      attachment_color = Bungie::Api.get_hex_color_for_damage_type(results[:item].dig(:masterwork, :damage_resistance_type) || results[:item].dig(:damage_type))

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
        attachment_fields.push(
          title: 'Perks',
          value: field_text,
          short: false
        )
      end


      if results[:item][:armor2_0]
        # Instead of masterwork/mod, show the energy level
        attachment_fields.push(
          title: 'Element',
          value: results[:item][:energy_type],
          short: true
        )

        attachment_fields.push(
          title: 'Energy',
          value: "#{results[:item][:energy_capacity]} / #{Bungie::Api::MAX_ENERGY} (#{results[:item][:energy_used]} used)",
          short: true
        )
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
        attachment_fields.push(
          title: 'Masterwork',
          value: masterwork,
          short: true
        )

        attachment_fields.push(
          title: 'Mod',
          ### TODO -- get rid of description?
          value: results[:item][:mod] ? results[:item][:mod][:name].to_s : 'n/a',
          short: true
        )
      end

      # Stats
      stat_abbreviations = {
        'Rounds Per Minute' => 'RPM',
        'Reload Speed'      => 'Reload'
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
                         footer_icon: BANSHEE_BOT_ICON_URL,
                         # footer:      BOT_NAME,
                         footer: attachment_footer,
                         # ts:          Time.now.to_i,
                         mrkdwn_in: ['fields']
                       }
                     ].to_json
      )
    end


    def self.loadout_response(client, data, results, type = :full)
      # Prepare output

      canonical_loadout_type = case type
      when :weapons
        'weapons'
      when :armor
        'armor'
      else
        'loadout'
      end

      message_text = ''
      message_text += "<@#{data&.user}>: " unless data&.user&.blank?
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

        # attachment_title    = results[:item][:name]
        # attachment_text     = "#{results[:item][:type_and_tier]} - #{results[:item][:power_level]} PL\n#{results[:item][:description]}"
        # attachment_fallback = "#{results[:item][:name]} - #{results[:item][:type_and_tier]} - #{results[:item][:power_level]} PL - #{results[:item][:description]}"

        attachment_fields = []

        # If they requested a more limited loadout like 'weapons' or 'armor', then filter the fields we're returning
        next unless slots_to_query.include?(slot)

        # Even if they requested a full loadout, we don't care about certain fields like emblems
        next unless %i[KINETIC_WEAPON ENERGY_WEAPON HEAVY_WEAPON HEAD ARMS CHEST LEGS CLASS_ITEM].include?(slot)

        attachment_title = "[#{Bungie::Api.get_bucket_name(slot)}]: #{item[:name]} (#{item[:type_and_tier]} - #{item[:power_level]} PL)"

        attachment_color = Bungie::Api.get_hex_color_for_damage_type(item.dig(:masterwork, :damage_resistance_type) || item.dig(:damage_type))

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

        attachment_fields.push(
          # title: field_title,
          value: field_text,
          short: false
        )

        attachments.push(
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

      output += "Usage: @#{BANSHEE_BOT_USERNAME} <bungie_name> <slot>\n"
      output += "Please use the 'help' command for more info."

      output.strip!

      client.say(text: output, channel: data.channel)
    end



    def self.print_unregistered_user_message(client, data)
      output = ''

      output += "<@#{data&.user}>: " unless data&.user&.blank?

      output += "Memory's not what it used to be. Who're you again?\n"
      output += "Use `@#{BANSHEE_BOT_USERNAME} register <bungie_name>` to register your Bungie.net profile.\n"
      output += "Use the 'help' command for more info."

      output.strip!

      client.say(text: output, channel: data.channel)
    end


    def self.print_user_not_found_message(client, data, requested_bungie_name)
      output = ''

      output += "<@#{data&.user}>: " unless data&.user&.blank?

      output += "Couldn't find a user for Bungie Name '#{requested_bungie_name}'."
      output += "Use the 'help' command for more info."

      output.strip!

      client.say(text: output, channel: data.channel)
    end


    def self.load_and_update_team(team_id, name, domain)
      # If the team doesn't already exist, create it
      team        = Slack::Team.find_or_initialize_by(team_id: team_id)
      team.name   = name
      team.domain = domain
      team.save
      team
    end
  end
end

