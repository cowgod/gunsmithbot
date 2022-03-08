# frozen_string_literal: true

require 'singleton'
require 'httparty'
require 'cgi'
require 'time'
require 'tempfile'
require 'sqlite3'
require 'zip'
require 'date'

require_relative '../concerns/retryable'

require_relative 'manifest'

require 'pp'

module Bungie
  # Class to encapsulate communication with the Bungie Destiny 2 API
  class Api
    include Singleton
    include HTTParty
    include Retryable

    base_uri 'https://www.bungie.net/Platform/'


    attr_reader :manifest


    SUCCESS_CODE = 200

    COMPONENTS       = {
      None: 0,

      # Profiles is the most basic component, only relevant when calling
      # GetProfile. This returns basic information about the profile, which is
      # almost nothing: a list of characterIds, some information about the last
      # time you logged in, and that most sobering statistic: how long you've
      # played.
      Profiles: 100,

      # Only applicable for GetProfile, this will return information about
      # receipts for refundable vendor items.
      VendorReceipts: 101,

      # Asking for this will get you the profile-level inventories, such as your
      # Vault buckets (yeah, the Vault is really inventory buckets located on your
      # Profile)
      ProfileInventories: 102,

      # This will get you a summary of items on your Profile that we consider to
      # be "currencies", such as Glimmer. I mean, if there's Glimmer in Destiny 2.
      # I didn't say there was Glimmer.
      ProfileCurrencies: 103,

      # This will get you any progression-related information that exists on a
      # Profile-wide level, across all characters.
      ProfileProgression: 104,

      # This will get you information about the silver that this profile has on every platform on which it plays.
      # You may only request this component for the logged in user's Profile, and will not recieve it if you request it for another Profile.
      PlatformSilver: 105,

      # This will get you summary info about each of the characters in the
      # profile.
      Characters: 200,

      # This will get you information about any non-equipped items on the
      # character or character(s) in question, if you're allowed to see it. You
      # have to either be authenticated as that user, or that user must allow
      # anonymous viewing of their non-equipped items in Bungie.Net settings to
      # actually get results.
      CharacterInventories: 201,

      # This will get you information about the progression (faction, experience,
      # etc... "levels") relevant to each character, if you are the currently
      # authenticated user or the user has elected to allow anonymous viewing of
      # its progression info.
      CharacterProgressions: 202,

      # This will get you just enough information to be able to render the
      # character in 3D if you have written a 3D rendering library for Destiny
      # Characters, or "borrowed" ours. It's okay, I won't tell anyone if you're
      # using it. I'm no snitch. (actually, we don't care if you use it - go to
      # town)
      CharacterRenderData: 203,

      # This will return info about activities that a user can see and gating on
      # it, if you are the currently authenticated user or the user has elected
      # to allow anonymous viewing of its progression info. Note that the data
      # returned by this can be unfortunately problematic and relatively
      # unreliable in some cases. We'll eventually work on making it more
      # consistently reliable.
      CharacterActivities: 204,

      # This will return info about the equipped items on the character(s).
      # Everyone can see this.
      CharacterEquipment: 205,

      # This will return basic info about instanced items - whether they can be
      # equipped, their tracked status, and some info commonly needed in many
      # places (current damage type, primary stat value, etc)
      ItemInstances: 300,

      # Items can have Objectives (DestinyObjectiveDefinition) bound to them. If
      # they do, this will return info for items that have such bound objectives.
      ItemObjectives: 301,

      # Items can have perks (DestinyPerkDefinition). If they do, this will return
      # info for what perks are active on items.
      ItemPerks: 302,

      # If you just want to render the weapon, this is just enough info to do that
      # rendering.
      ItemRenderData: 303,

      # Items can have stats, like rate of fire. Asking for this component will
      # return requested item's stats if they have stats.
      ItemStats: 304,

      # Items can have sockets, where plugs can be inserted. Asking for this
      # component will return all info relevant to the sockets on items that have
      # them.
      ItemSockets: 305,

      # Items can have talent grids, though that matters a lot less frequently
      # than it used to. Asking for this component will return all relevant info
      # about activated Nodes and Steps on this talent grid, like the good ol'
      # days.
      ItemTalentGrids: 306,

      # Items that *aren't* instanced still have important information you need
      # to know: how much of it you have, the itemHash so you can look up their
      # DestinyInventoryItemDefinition, whether they're locked, etc... Both
      # instanced and non-instanced items will have these properties. You will
      # get this automatically with Inventory components - you only need to pass
      # this when calling GetItem on a specific item.
      ItemCommonData: 307,

      # Items that are "Plugs" can be inserted into sockets. This returns statuses
      # about those plugs and why they can/can't be inserted. I hear you giggling,
      # there's nothing funny about inserting plugs. Get your head out of the
      # gutter and pay attention!
      ItemPlugStates: 308,

      # Sometimes, plugs have objectives on them. This data can get really large, so
      # we split it into its own component. Please, don't grab it unless you need it.
      ItemPlugObjectives: 309,

      # Sometimes, designers create thousands of reusable plugs and suddenly your
      # response sizes are almost 3 MB, and something has to give.
      # Reusable Plugs were split off as their own component, away from ItemSockets,
      # as a result of the Plug changes in Shadowkeep that made plug data infeasibly
      # large for the most common use cases.
      # Request this component if and only if you need to know what plugs *could* be
      # inserted into a socket, and need to know it before "drilling" into the details
      # of an item in your application (for instance, if you 're doing some sort of
      # interesting sorting or aggregation based on available plugs.
      # When you get this, you will also need to combine it with "Plug Sets" data if
      # you want a full picture of all of the available plugs : this component will
      # only return plugs that have state data that is per - item.See Plug Sets for
      # available plugs that have Character, Profile, or no state - specific
      # restrictions.
      ItemReusablePlugs: 310,

      # When obtaining vendor information, this will return summary information
      # about the Vendor or Vendors being returned.
      Vendors: 400,

      # When obtaining vendor information, this will return information about the
      # categories of items provided by the Vendor.
      VendorCategories: 401,

      # When obtaining vendor information, this will return the information about
      # items being sold by the Vendor.
      VendorSales: 402,

      # Asking for this component will return you the account's Kiosk statuses:
      # that is, what items have been filled out/acquired. But only if you are
      # the currently authenticated user or the user has elected to allow
      # anonymous viewing of its progression info.
      Kiosks: 500,

      # A "shortcut" component that will give you all of the item
      # hashes/quantities of items that the requested character can use to
      # determine if an action (purchasing, socket insertion) has the required
      # currency. (recall that all currencies are just items, and that some vendor
      # purchases require items that you might not traditionally consider to be a
      # "currency", like plugs/mods!)
      CurrencyLookups: 600,

      # Returns summary status information about all "Presentation Nodes". See
      # DestinyPresentationNodeDefinition for more details, but the gist is that
      # these are entities used by the game UI to bucket Collectibles and Records
      # into a hierarchy of categories. You may ask for and use this data if you
      # want to perform similar bucketing in your own UI: or you can skip it and
      # roll your own.
      PresentationNodes: 700,

      # Returns summary status information about all "Collectibles". These are
      # records of what items you've discovered while playing Destiny, and some
      # other basic information. For detailed information, you will have to call
      # a separate endpoint devoted to the purpose.
      Collectibles: 800,

      # Returns summary status information about all "Records" (also known in the
      # game as "Triumphs". I know, it's confusing because there's also "Moments
      # of Triumph" that will themselves be represented as "Triumphs.")
      Records: 900,

      # Returns information that Bungie considers to be "Transitory": data that may
      # change too frequently or come from a non-authoritative source such that we
      # don't consider the data to be fully trustworthy, but that might prove useful
      # for some limited use cases. We can provide no guarantee of timeliness nor
      # consistency for this data: buyer beware with the Transitory component.
      Transitory: 1000
    }.freeze
    ITEM_BUCKET_IDS  = {
      KINETIC_WEAPON: 1498876634,
      ENERGY_WEAPON:  2465295065,
      HEAVY_WEAPON:   953998645,
      GHOST:          4023194814,
      HEAD:           3448274439,
      ARMS:           3551918588,
      CHEST:          14239492,
      LEGS:           20886954,
      CLASS_ITEM:     1585787867,
      SHIP:           284967655,
      SPARROW:        2025709351,
      EMBLEM:         4274335291,

      CLAN_BANNER:    4292445962,
      SUBCLASS:       3284755031
    }.freeze
    MEMBERSHIP_TYPES = {
      None:          0,
      TigerXbox:     1,
      TigerPsn:      2,
      TigerSteam:    3,
      TigerBlizzard: 4,
      TigerStadia:   5,
      TigerDemon:    10,
      BungieNext:    254,
      All:           -1
    }.freeze
    DAMAGE_TYPES     = {
      None:    0,
      Kinetic: 1,
      Arc:     2,
      Thermal: 3,
      Void:    4,
      Raid:    5,
      Stasis:  6
    }.freeze

    # DestinyUnlockValueUIStyle
    UI_STYLES = {
      # Generally, Automatic means "Just show the number"
      Automatic: 0,

      # Show the number as a fractional value. For this to make sense, the value being displayed should have a
      # comparable upper bound, like the progress to the next level of a Progression.
      Fraction: 1,

      # Show the number as a checkbox. 0 Will mean unchecked, any other value will mean checked.
      Checkbox: 2,

      # Show the number as a percentage. For this to make sense, the value being displayed should have a comparable
      # upper bound, like the progress to the next level of a Progression.
      Percentage: 3,

      # Show the number as a date and time. The number will be the number of seconds since the Unix Epoch (January 1st,
      # 1970 at midnight UTC). It'll be up to you to convert this into a date and time format understandable to the user
      # in their time zone.
      DateTime: 4,

      # Show the number as a floating point value that represents a fraction, where 0 is min and 1 is max. For this to
      # make sense, the value being displayed should have a comparable upper bound, like the progress to the next level
      # of a Progression.
      FractionFloat: 5,

      # Show the number as a straight-up integer.
      Integer: 6,

      # Show the number as a time duration. The value will be returned as seconds.
      TimeDuration: 7,

      # Don't bother showing the value at all, it's not easily human-interpretable, and used for some internal purpose.
      Hidden: 8,

      # Example: "1.5x"
      Multiplier: 9,

      # Show the value as a series of green pips, like the wins in a Trials of Osiris score card.
      GreenPips: 10,

      # Show the value as a series of red pips, like the losses in a Trials of Osiris score card.
      RedPips: 11,

      # Show the value as a percentage. For example: "51%" - Does no division, only appends '%'
      ExplicitPercentage: 12,

      # Show the value as a floating-point number. For example: "4.52" NOTE: Passed along from Investment as whole
      # number with last two digits as decimal values (452 -> 4.52)
      RawFloat: 13,

      # Show the value as a level and a reward.
      LevelAndReward: 14,
    }.freeze

    # The value of the uiCategoryStyle for socketCategories that we want to
    # display (this corresponds to 'WEAPON PERKS' and 'ARMOR PERKS')
    SOCKET_CATEGORY_IDS = {
      weapon_perks:      4241085061,
      weapon_mods:       2685412949,
      armor_perks:       2518356196,
      armor_mods:        590099826,
      ghost_shell_perks: 3301318876,
      ghost_shell_mods:  3379164649,
      vehicle_perks:     2278110604,
      vehicle_mods_1:    4243480345,
      vehicle_mods_2:    4265082475
    }.freeze

    # Used in formatting the attachment
    DAMAGE_COLOR = {
      kinetic: '#d9d9d9',
      arc:     '#72bde3',
      thermal: '#e68a00',
      void:    '#400080',
      stasis:  '#5a88f7'
    }.freeze

    # Max possible energy that armor can have
    MAX_ENERGY = 10

    ACTIVITY_MODES = {
      none:                      0,
      story:                     2,
      strike:                    3,
      raid:                      4,
      all_pvp:                   5,
      patrol:                    6,
      all_pve:                   7,
      reserved9:                 9,
      control:                   10,
      reserved11:                11,
      clash:                     12,
      reserved13:                13,
      crimson_doubles:           15,
      nightfall:                 16,
      heroic_nightfall:          17,
      all_strikes:               18,
      iron_banner:               19,
      reserved20:                20,
      reserved21:                21,
      reserved22:                22,
      reserved24:                24,
      all_mayhem:                25,
      reserved26:                26,
      reserved27:                27,
      reserved28:                28,
      reserved29:                29,
      reserved30:                30,
      supremacy:                 31,
      private_matches_all:       32,
      survival:                  37,
      countdown:                 38,
      trials_of_the_nine:        39,
      social:                    40,
      trials_countdown:          41,
      trials_survival:           42,
      iron_banner_control:       43,
      iron_banner_clash:         44,
      iron_banner_supremacy:     45,
      scored_nightfall:          46,
      scored_heroic_nightfall:   47,
      rumble:                    48,
      all_doubles:               49,
      doubles:                   50,
      private_matches_clash:     51,
      private_matches_control:   52,
      private_matches_supremacy: 53,
      private_matches_countdown: 54,
      private_matches_survival:  55,
      private_matches_mayhem:    56,
      private_matches_rumble:    57,
      heroic_adventure:          58,
      showdown:                  59,
      lockdown:                  60,
      scorched:                  61,
      scorched_team:             62,
      gambit:                    63,
      all_pve_competitive:       64,
      breakthrough:              65,
      black_armory_run:          66,
      salvage:                   67,
      iron_banner_salvage:       68,
      pvp_competitive:           69,
      pvp_quickplay:             70,
      clash_quickplay:           71,
      clash_competitive:         72,
      control_quickplay:         73,
      control_competitive:       74,
      gambit_prime:              75,
      reckoning:                 76,
      menagerie:                 77,
      vex_offensive:             78,
      nightmare_hunt:            79,
      elimination:               80,
      momentum:                  81,
      dungeon:                   82,
      sundial:                   83,
      trials_of_osiris:          84
    }.freeze


    def initialize
      @api_key = ENV['BUNGIE_API_TOKEN'].presence || $config&.dig('api_keys', 'bungie')

      raise 'Bungie API key not set' unless @api_key

      Cowgod::Logger.log "#{self.class}.#{__method__} - Initializing Bungie API... Done."

      @options = { headers: { 'X-API-Key' => @api_key } }

      initialize_manifest
    end


    # Load the Bungie.net account for a given Bungie.net membership ID
    def get_bungie_user_for_membership_id(membership_id)
      # If they didn't give us a membership_id to search, there's nothing we can do
      return nil unless membership_id

      url = "/User/GetBungieNetUserById/#{membership_id.to_s.uri_encode}/"

      Cowgod::Logger.log "#{self.class}.#{__method__} - #{url}"

      response = with_retry do
        self.class.get(url, @options)
      end
      raise QueryError, 'API request failed' unless response && response.code == SUCCESS_CODE

      response.parsed_response&.dig('Response') || []
    end


    # Load all platform memberships for a given platform membership ID, plus the Bungie.net account
    def get_memberships_for_membership_id(membership_id)
      # If they didn't give us a membership_id to search, there's nothing we can do
      return nil unless membership_id

      # Now that crossplay is in effect, we always want to specify "all" for the platform
      membership_type_id = -1

      url = "/User/GetMembershipsById/#{membership_id.to_s.uri_encode}/#{membership_type_id.to_s.uri_encode}/"

      Cowgod::Logger.log "#{self.class}.#{__method__} - #{url}"

      response = with_retry do
        self.class.get(url, @options)
      end
      raise QueryError, 'API request failed' unless response && response.code == SUCCESS_CODE

      response.parsed_response&.dig('Response') || []
    end


    # Find all platform accounts for a given Bungie name (display_name#1234)
    def get_memberships_for_bungie_name(requested_bungie_name)
      # If they didn't give us a Bungie Name to search, there's nothing we can do
      return nil unless requested_bungie_name

      # Now that crossplay is in effect, we always want to specify "all" for the platform
      membership_type_id = -1

      url = "/Destiny2/SearchDestinyPlayer/#{membership_type_id.to_s.uri_encode}/#{requested_bungie_name.to_s.uri_encode}/"

      Cowgod::Logger.log "#{self.class}.#{__method__} - #{url}"

      response = with_retry do
        self.class.get(url, @options)
      end
      raise QueryError, 'API request failed' unless response && response.code == SUCCESS_CODE

      response.parsed_response&.dig('Response') || []
    end


    def get_characters_for_membership(membership_type, membership_id, include_equipment: false)
      url = "/Destiny2/#{membership_type.to_s.uri_encode}/Profile/#{membership_id.to_s.uri_encode}/"

      desired_components = [COMPONENTS[:Characters]]
      desired_components << COMPONENTS[:CharacterEquipment] if include_equipment

      query_options = {
        components: desired_components.join(',')
      }

      Cowgod::Logger.log "#{self.class}.#{__method__} - #{url} - #{JSON.pretty_generate(query_options)}"

      response = with_retry do
        self.class.get(
          url,
          @options.merge(
            query: query_options
          )
        )
      end
      raise QueryError, 'API request failed' unless response && response.code == SUCCESS_CODE

      characters = response.parsed_response['Response']&.dig('characters', 'data')
      return nil unless characters


      # The API already returns these in a hash with the characterId as the
      # key, so no additional conversion is necessary


      if include_equipment
        characters.each_key do |character_id|
          characters[character_id]['items'] = response.parsed_response['Response']&.dig('characterEquipment', 'data', character_id, 'items')
        end
      end

      characters
    end


    def get_active_character_for_membership(membership_type, membership_id, include_equipment: false)
      characters = get_characters_for_membership(membership_type, membership_id, include_equipment: include_equipment)
      return nil unless characters

      latest_time_played = Time.new(1980, 1, 1)
      active_character   = nil

      characters.each_pair do |_, character|
        if character && Time.parse(character['dateLastPlayed']) > latest_time_played
          active_character   = character
          latest_time_played = Time.parse(character['dateLastPlayed'])
        end
      end

      active_character
    end


    def get_character(membership_type, membership_id, character_id, include_equipment: false)
      return nil unless membership_type && membership_id && character_id


      url = "/Destiny2/#{membership_type.to_s.uri_encode}/Profile/#{membership_id.to_s.uri_encode}/Character/#{character_id}/"

      desired_components = [COMPONENTS[:Characters]]
      desired_components << COMPONENTS[:CharacterEquipment] if include_equipment


      Cowgod::Logger.log "#{self.class}.#{__method__} - #{url}"

      response = with_retry do
        self.class.get(
          url,
          @options.merge(
            query: {
              components: desired_components.join(',')
            }
          )
        )
      end
      raise QueryError, 'API request failed' unless response && response.code == SUCCESS_CODE

      character = response.parsed_response['Response']&.dig('character', 'data')
      return nil unless character


      if include_equipment
        character['items'] = response.parsed_response['Response']&.dig('equipment', 'data', 'items')
      end

      character
    end


    def item_details(membership_type, membership_id, item_instance_id)
      url = "/Destiny2/#{membership_type.to_s.uri_encode}/Profile/#{membership_id.to_s.uri_encode}/Item/#{item_instance_id.to_s.uri_encode}/"

      query_options = {
        components: [
                      COMPONENTS[:ItemInstances],
                      COMPONENTS[:ItemPerks],
                      COMPONENTS[:ItemStats],

                      COMPONENTS[:ItemSockets],
                      COMPONENTS[:ItemCommonData],
                      COMPONENTS[:ItemPlugStates],
                      COMPONENTS[:ItemPlugObjectives],
                      COMPONENTS[:ItemReusablePlugs]
                    ].join(',')
      }

      Cowgod::Logger.log "#{self.class}.#{__method__} - #{url} - #{JSON.pretty_generate(query_options)}"

      response = with_retry do
        self.class.get(
          url,
          @options.merge(
            query: query_options
          )
        )
      end
      raise QueryError, 'API request failed' unless response && response.code == SUCCESS_CODE

      item_instance = response.parsed_response['Response']
      return nil unless item_instance

      item_hash = item_instance.dig('item', 'data', 'itemHash').to_s
      return nil unless item_hash

      item_definition = @manifest.lookup_item(item_hash)

      item_details = {
        hash:             item_hash,
        item_instance_id: item_instance.dig('item', 'data', 'itemInstanceId'),
        damage_type:      (DAMAGE_TYPES.key(item_instance.dig('instance', 'data', 'damageType')) || 'Unknown').to_s,
        power_level:      item_instance.dig('instance', 'data', 'primaryStat', 'value'),
        name:             item_definition.dig('displayProperties', 'name'),
        description:      item_definition.dig('displayProperties', 'description'),
        tier:             item_definition.dig('inventory', 'tierTypeName'),
        type:             item_definition['itemTypeDisplayName'],
        type_and_tier:    item_definition['itemTypeAndTierDisplayName'],
        objectives:       []
      }


      # If the item has an override style (i.e. an applied ornament), use that icon instead
      if item_instance.dig('item', 'data', 'overrideStyleItemHash')
        override_item           = @manifest.lookup_item(item_instance.dig('item', 'data', 'overrideStyleItemHash'))
        item_details[:icon]     = override_item&.dig('displayProperties', 'icon') || item_definition.dig('displayProperties', 'icon')
        item_details[:has_icon] = override_item&.dig('displayProperties', 'hasIcon') || item_definition.dig('displayProperties', 'hasIcon')
      else
        item_details[:icon]     = item_definition.dig('displayProperties', 'icon')
        item_details[:has_icon] = item_definition.dig('displayProperties', 'hasIcon')
      end


      item_details[:perk_sockets] = []

      # Item is Armor 2.0 if it has an 'energy' attribute
      item_details[:armor2_0] = !!item_instance.dig('instance', 'data', 'energy')

      if item_details[:armor2_0]
        energy_type = @manifest.lookup_energy_type(item_instance.dig('instance', 'data', 'energy', 'energyTypeHash'))

        item_details[:energy_type]     = energy_type.dig('displayProperties', 'name')
        item_details[:energy_used]     = item_instance.dig('instance', 'data', 'energy', 'energyUsed')
        item_details[:energy_capacity] = item_instance.dig('instance', 'data', 'energy', 'energyCapacity')
      end


      item_definition.dig('sockets', 'socketCategories')&.each do |category|
        category&.dig('socketIndexes')&.each do |socket_index|
          ### Manifest data:
          # socket_definition = item_definition.dig('sockets', 'socketEntries')[socket_index]

          ### Item instance data:
          socket_instance = item_instance.dig('sockets', 'data', 'sockets')&.dig(socket_index)
          next unless socket_instance


          ### Load any objectives (e.g. masterwork kill trackers) for the plug inserted in this socket
          item_instance.dig('plugObjectives', 'data', 'objectivesPerPlug', socket_instance.dig('plugHash').to_s)
            &.select { |objective| objective&.dig('visible') }
            &.each do |objective|
            objective_definition = @manifest.lookup_objective(objective&.dig('objectiveHash'))

            # If the kill counter is active, add it to the item as a whole
            if objective&.dig('complete')
              item_details[:objectives] += [{
                                              label: objective_definition&.dig('progressDescription'),
                                              value: Bungie::Api.format_objective_value(objective&.dig('progress'), objective_definition&.dig('completedValueStyle'))
                                            }]
            end
          end


          case SOCKET_CATEGORY_IDS.key(category['socketCategoryHash'])
          when :weapon_perks, :armor_perks
            # If this socket isn't marked as visible, we can skip it
            next unless socket_instance.dig('isVisible')

            perk_socket = []

            if item_instance.dig('reusablePlugs', 'data', 'plugs', socket_index.to_s)
              # If the socket supports multiple reusablePlugs, display them all, and mark which is currently selected
              item_instance.dig('reusablePlugs', 'data', 'plugs', socket_index.to_s).each do |plug|

                plug_definition = @manifest.lookup_item(plug&.dig('plugItemHash'))
                next unless plug_definition

                perk = {
                  hash:        plug_definition['hash'].to_s,
                  name:        plug_definition.dig('displayProperties', 'name'),
                  description: plug_definition.dig('displayProperties', 'description'),
                  icon:        plug_definition.dig('displayProperties', 'icon'),
                  has_icon:    plug_definition.dig('displayProperties', 'hasIcon'),
                  selected:    (plug_definition['hash'].to_s == socket_instance.dig('plugHash').to_s)
                }

                perk_socket.push perk
              end
            else
              # Otherwise, just display the fixed plug that's in the socket
              plug_definition = @manifest.lookup_item(socket_instance.dig('plugHash'))
              if plug_definition
                perk = {
                  hash:        plug_definition['hash'].to_s,
                  name:        plug_definition.dig('displayProperties', 'name'),
                  description: plug_definition.dig('displayProperties', 'description'),
                  icon:        plug_definition.dig('displayProperties', 'icon'),
                  has_icon:    plug_definition.dig('displayProperties', 'hasIcon'),
                  selected:    true
                }

                perk_socket.push perk
              end
            end

            item_details[:perk_sockets].push perk_socket unless perk_socket.empty?

          when :weapon_mods, :armor_mods
            plug_definition = @manifest.lookup_item(socket_instance&.dig('plugHash'))
            next unless plug_definition && plug_definition&.dig('plug')

            case plug_definition&.dig('plug', 'plugCategoryIdentifier')
            when /^enhancements\./
              # enhancements.v2_general
              # enhancements.v2_arms
              # enhancements.v2_chest
              # enhancements.v2_legs
              # enhancements.v2_class_item
              # enhancements.v2_general --- Empty Mod Socket
              # enhancements.season_maverick --- Empty Mod Socket
              # enhancements.season_v470 --- Empty Mod Socket
              # TODO - Maybe just show it all them rather than filtering by identifier, there's so many options

              # If the socket supports multiple reusablePlugs, display them all, and mark which is currently selected
              perk = {
                hash:        plug_definition['hash'].to_s,
                name:        plug_definition.dig('displayProperties', 'name'),
                description: plug_definition.dig('displayProperties', 'description'),
                icon:        plug_definition.dig('displayProperties', 'icon'),
                has_icon:    plug_definition.dig('displayProperties', 'hasIcon'),
                selected:    (plug_definition['hash'].to_s == socket_instance&.dig('plugHash').to_s)
              }

              item_details[:perk_sockets].push [perk]


              #item_details[:mod] = {
              #  hash:        plug_definition.dig('hash').to_s,
              #  name:        plug_definition.dig('displayProperties', 'name'),
              #  description: plug_definition.dig('displayProperties', 'description'),
              #  icon:        plug_definition.dig('displayProperties', 'icon'),
              #  has_icon:    plug_definition.dig('displayProperties', 'hasIcon')
              #}


              # v400.weapon.mod_empty
            when /v400\.weapon\.mod_/
              next if plug_definition&.dig('displayProperties', 'name') == 'Empty Mod Socket'

              # next unless plug_item&.dig('investmentStats')&.first

              item_details[:mod] = {
                hash:        plug_definition['hash'].to_s,
                name:        plug_definition.dig('displayProperties', 'name'),
                description: plug_definition.dig('displayProperties', 'description'),
                icon:        plug_definition.dig('displayProperties', 'icon'),
                has_icon:    plug_definition.dig('displayProperties', 'hasIcon')
              }

            when /v400\.plugs\.(weapons|armor)\.masterworks\./
              affected_stat = plug_definition['investmentStats']&.first
              stat_details  = @manifest.lookup_stat(affected_stat&.dig('statTypeHash'))

              damage_resistance_type = case stat_details&.dig('displayProperties', 'name')
              when /Arc Damage Resistance/i
                DAMAGE_TYPES[:Arc]
              when /Solar Damage Resistance/i
                DAMAGE_TYPES[:Thermal]
              when /Void Damage Resistance/i
                DAMAGE_TYPES[:Void]
              end

              damage_resistance_type = (DAMAGE_TYPES.key(damage_resistance_type) || 'Unknown').to_s if damage_resistance_type

              item_details[:masterwork] = {
                hash:                   plug_definition['hash'].to_s,
                name:                   plug_definition.dig('displayProperties', 'name'),
                description:            plug_definition.dig('displayProperties', 'description'),
                icon:                   plug_definition.dig('displayProperties', 'icon'),
                has_icon:               plug_definition.dig('displayProperties', 'hasIcon'),
                affected_stat:          stat_details&.dig('displayProperties', 'name'),
                value:                  affected_stat&.dig('value'),
                damage_resistance_type: damage_resistance_type
              }
            end
          end
        end
      end

      item_details[:stats] = []

      item_instance&.dig('stats', 'data', 'stats')&.each_value do |stat|
        next unless stat&.dig('statHash')

        stat_details = @manifest.lookup_stat(stat&.dig('statHash'))

        next unless stat_details

        item_details[:stats].push(
          hash:        stat&.dig('statHash').to_s,
          name:        stat_details.dig('displayProperties', 'name'),
          description: stat_details.dig('displayProperties', 'description'),
          icon:        stat_details.dig('displayProperties', 'icon'),
          has_icon:    stat_details.dig('displayProperties', 'hasIcon'),
          value:       stat&.dig('value')
        )
      end

      item_details
    end


    # Get activities for a character
    # https://bungie-net.github.io/multi/operation_get_Destiny2-GetActivityHistory.html#operation_get_Destiny2-GetActivityHistory
    def get_activities_for_character(membership_type_id, membership_id, character_id, num_activities: nil, page_number: nil, mode: nil)
      # If they didn't provide all required values, there's nothing we can do
      return nil unless membership_type_id && membership_id && character_id


      url = "/Destiny2/#{membership_type_id.to_s.uri_encode}/Account/#{membership_id.to_s.uri_encode}/Character/#{character_id.to_s.uri_encode}/Stats/Activities/"

      query_options         = {}
      query_options[:page]  = page_number if page_number
      query_options[:count] = num_activities if num_activities
      query_options[:mode]  = mode if mode

      Cowgod::Logger.log "#{self.class}.#{__method__} - #{url} - #{JSON.pretty_generate(query_options)}"

      response = with_retry do
        self.class.get(
          url,
          @options.merge(
            query: query_options
          )
        )
      end
      raise QueryError, 'API request failed' unless response && response.code == SUCCESS_CODE

      activities = response.parsed_response&.dig('Response', 'activities') || []


      # Map the rows into a hash by their associated instance ID
      activities.map { |activity| [activity.dig('activityDetails', 'instanceId').to_i, activity] }.to_h
    end


    # Get PGCR for an activity
    # https://bungie-net.github.io/multi/operation_get_Destiny2-GetPostGameCarnageReport.html#operation_get_Destiny2-GetPostGameCarnageReport
    def get_pgcr_for_activity(activity_id)
      # If they didn't give us an activity_id to search, there's nothing we can do
      return nil unless activity_id

      url = "/Destiny2/Stats/PostGameCarnageReport/#{activity_id.to_s.uri_encode}/"


      Cowgod::Logger.log "#{self.class}.#{__method__} - #{url}"

      response = with_retry do
        self.class.get(url, @options)
      end
      raise QueryError, 'API request failed' unless response && response.code == SUCCESS_CODE


      response.parsed_response['Response'] || {}
    end


    # ### UNSUPPORTED ENDPOINT, DON'T USE
    # def get_user_for_id(id)
    #   url = "/User/GetBungieAccount/#{id.to_s.uri_encode}/254/"
    #
    #   Cowgod::Logger.log "#{self.class}.#{__method__} - #{url}"
    #
    #   response = with_retry do
    #     self.class.get(url, @options)
    #   end
    #   raise QueryError, 'API request failed' unless response && response.code == SUCCESS_CODE
    #
    #   response.parsed_response['Response']
    # end


    # def get_xxxx
    #   'https://www.bungie.net/Platform/User/15274884/Partnerships/'
    #
    #   url = "/Destiny2/#{membership_type.to_s.uri_encode}/Profile/#{membership_id.to_s.uri_encode}/Item/#{item_instance_id.to_s.uri_encode}/"
    #
    #   Cowgod::Logger.log "#{self.class}.#{__method__} - #{url}"
    #
    #   response = self.class.get(
    #     url,
    #     @options.merge(
    #       query: {
    #         components: [
    #                       COMPONENTS[:ItemInstances],
    #                       COMPONENTS[:ItemPerks],
    #                       COMPONENTS[:ItemStats],
    #
    #                       COMPONENTS[:ItemSockets],
    #                       COMPONENTS[:ItemCommonData],
    #                       COMPONENTS[:ItemPlugStates]
    #                     ].join(',')
    #       }
    #     )
    #   )
    #   raise QueryError, 'API request failed' unless response.code == SUCCESS_CODE
    #
    #   item_instance = response.parsed_response['Response']
    #
    # end


    def self.get_membership_type_id(membership_type)
      case membership_type.to_s.strip.downcase
      when 'playstation', 'ps4', 'ps3', 'ps'
        MEMBERSHIP_TYPES[:TigerPsn]
      when 'xbox', 'xb1', 'xb'
        MEMBERSHIP_TYPES[:TigerXbox]
      when 'steam', 'valve', 'computer', 'pc'
        MEMBERSHIP_TYPES[:TigerSteam]
      when 'battlenet', 'bnet', 'blizzard', 'blizard'
        MEMBERSHIP_TYPES[:TigerBlizzard]
      when 'stadia', 'google', 'browser'
        MEMBERSHIP_TYPES[:TigerStadia]
      end
    end


    def self.get_platform_code(membership_type_id)
      case membership_type_id.to_i
      when MEMBERSHIP_TYPES[:TigerPsn]
        'playstation'
      when MEMBERSHIP_TYPES[:TigerXbox]
        'xbox'
      when MEMBERSHIP_TYPES[:TigerBlizzard]
        'battlenet'
      when MEMBERSHIP_TYPES[:TigerSteam]
        'steam'
      when MEMBERSHIP_TYPES[:TigerStadia]
        'stadia'
      end
    end


    def self.get_bucket_id(bucket)
      # If they've passed us an actual value or key, use it directly
      return bucket if ITEM_BUCKET_IDS.value?(bucket)
      return ITEM_BUCKET_IDS[bucket] if ITEM_BUCKET_IDS.key?(bucket)

      case bucket.to_s.strip.downcase
      when 'primary', 'kinetic'
        ITEM_BUCKET_IDS[:KINETIC_WEAPON]
      when 'special', 'secondary', 'energy'
        ITEM_BUCKET_IDS[:ENERGY_WEAPON]
      when 'heavy', 'power'
        ITEM_BUCKET_IDS[:HEAVY_WEAPON]
      when 'ghost'
        ITEM_BUCKET_IDS[:GHOST]
      when 'head', 'helmet', 'helm', 'mask', 'hat'
        ITEM_BUCKET_IDS[:HEAD]
      when 'arm', 'arms', 'glove', 'gloves', 'gauntlet', 'gauntlets', 'hand', 'hands'
        ITEM_BUCKET_IDS[:ARMS]
      when 'chest'
        ITEM_BUCKET_IDS[:CHEST]
      when 'leg', 'legs', 'boot', 'boots', 'greaves', 'pant', 'pants'
        ITEM_BUCKET_IDS[:LEGS]
      when 'class', 'mark', 'bond', 'cape', 'cloak', 'towel'
        ITEM_BUCKET_IDS[:CLASS_ITEM]
      when 'ship'
        ITEM_BUCKET_IDS[:SHIP]
      when 'sparrow'
        ITEM_BUCKET_IDS[:SPARROW]
      when 'emblem', 'brag', 'humblebrag'
        ITEM_BUCKET_IDS[:EMBLEM]
      end
    end


    def self.get_bucket_code(bucket_id)
      case bucket_id.to_i
      when ITEM_BUCKET_IDS[:KINETIC_WEAPON]
        'kinetic'
      when ITEM_BUCKET_IDS[:ENERGY_WEAPON]
        'energy'
      when ITEM_BUCKET_IDS[:HEAVY_WEAPON]
        'power'
      when ITEM_BUCKET_IDS[:GHOST]
        'ghost'
      when ITEM_BUCKET_IDS[:HEAD]
        'helmet'
      when ITEM_BUCKET_IDS[:ARMS]
        'gloves'
      when ITEM_BUCKET_IDS[:CHEST]
        'chest'
      when ITEM_BUCKET_IDS[:LEGS]
        'boots'
      when ITEM_BUCKET_IDS[:CLASS_ITEM]
        'class'
      when ITEM_BUCKET_IDS[:SHIP]
        'ship'
      when ITEM_BUCKET_IDS[:SPARROW]
        'sparrow'
      when ITEM_BUCKET_IDS[:EMBLEM]
        'emblem'
      end
    end


    def self.get_bucket_name(bucket_code)
      normalized_bucket_code = get_bucket_code(ITEM_BUCKET_IDS[bucket_code.to_sym])
      return bucket_code.to_s.capitalize unless normalized_bucket_code

      normalized_bucket_code.to_s.gsub(/\w+/, &:capitalize)
    end


    def self.get_hex_color_for_damage_type(damage_type)
      damage_type_key = damage_type.downcase.to_sym
      DAMAGE_COLOR[damage_type_key] || DAMAGE_COLOR[:kinetic]
    end


    def self.format_objective_value(value, ui_style)
      case ui_style
      when self::UI_STYLES[:DateTime]
        # Show the number as a date and time. The number will be the number of seconds since the Unix Epoch (January 1st,
        # 1970 at midnight UTC). It'll be up to you to convert this into a date and time format understandable to the user
        # in their time zone.
        Time.at(value).to_datetime.strftime("%Y-%m-%d")
      else
        value&.to_formatted_s
      end
    end


    private


    def initialize_manifest
      url = '/Destiny2/Manifest/'

      Cowgod::Logger.log "#{self.class}.#{__method__} - #{url}"

      response = with_retry do
        self.class.get(url, @options)
      end
      raise QueryError, 'API request failed' unless response && response.code == SUCCESS_CODE

      parsed_response = response.parsed_response['Response']
      raise 'Invalid manifest URL received' unless parsed_response

      @manifest = Bungie::Manifest.new "https://www.bungie.net#{parsed_response.dig('mobileWorldContentPaths', 'en')}"
    end
  end
end
