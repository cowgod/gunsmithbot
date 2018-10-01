require 'discordrb'
require 'discordrb/webhooks'
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
    raise 'WEBHOOK_URL not set' unless ENV['WEBHOOK_URL'].present?

    @prefix = prefix

    @bot            = Discordrb::Commands::CommandBot.new token: ENV['DISCORD_API_TOKEN'], prefix: @prefix, name: BOT_NAME
    @webhook_client = Discordrb::Webhooks::Client.new(url: ENV['WEBHOOK_URL'])


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
      # Commands send whatever is returned from the block to the channel. This allows for compact commands like this,
      # but you have to be aware of this so you don't accidentally return something you didn't intend to.
      # To prevent the return value to be sent to the channel, you can just return `nil`.
      # event.user.name


      results = nil

      begin
        # Split the input into words, and strip out the element that represents our own
        # userid (which will look something like '<@UCNTC2YH0>')
        # args = args.grep_v(/^<@[A-Z0-9]+>$/)
        #
        # args = args.grep_v('!show')

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


        results = $gunsmith_bot.query(requested_gamertag, requested_platform, requested_slot)
      rescue QueryError => message
        print_usage(user: event&.user, additional_message: message)
      end

      break if results.blank?


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

      @webhook_client.execute do |builder|
        builder.content = message_text
        builder.add_embed do |embed|
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
      end

      nil
    end
  end

  def run
    @bot.run
  end

  def print_usage(user:, additional_message:)
    output = ''

    output += "<@#{user&.id}>: " unless user.blank?
    output += additional_message.to_s unless additional_message.blank?
    output += "\n"

    output += "Usage: #{@prefix}show <gamertag> <platform> <slot>\n"
    output += "Please use the 'help' command for more info."

    output.strip!

    @webhook_client.execute do |builder|
      builder.content = output
    end
  end
end


$gunsmith_bot = GunsmithBot.new
bot = GunsmithBotDiscord.new
bot.run
