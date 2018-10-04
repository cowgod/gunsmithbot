require 'httparty'
require 'uri'
require 'time'
require 'tempfile'
require 'sqlite3'
require 'zip'

require_relative 'bungie_manifest'


require 'pp'


class BungieApi
  include HTTParty
  base_uri 'https://www.bungie.net/Platform/'


  COMPONENTS       = {
    None: 0,

    # Profiles is the most basic component, only relevant when calling GetProfile. This returns basic information about the profile, which is almost nothing: a list of characterIds, some information about the last time you logged in, and that most sobering statistic: how long you've played.
    Profiles: 100,

    # Only applicable for GetProfile, this will return information about receipts for refundable vendor items.
    VendorReceipts: 101,

    # Asking for this will get you the profile-level inventories, such as your Vault buckets (yeah, the Vault is really inventory buckets located on your Profile)
    ProfileInventories: 102,

    # This will get you a summary of items on your Profile that we consider to be "currencies", such as Glimmer. I mean, if there's Glimmer in Destiny 2. I didn't say there was Glimmer.
    ProfileCurrencies: 103,

    # This will get you any progression-related information that exists on a Profile-wide level, across all characters.
    ProfileProgression: 104,

    # This will get you summary info about each of the characters in the profile.
    Characters: 200,

    # This will get you information about any non-equipped items on the character or character(s) in question, if you're allowed to see it. You have to either be authenticated as that user, or that user must allow anonymous viewing of their non-equipped items in Bungie.Net settings to actually get results.
    CharacterInventories: 201,

    # This will get you information about the progression (faction, experience, etc... "levels") relevant to each character, if you are the currently authenticated user or the user has elected to allow anonymous viewing of its progression info.
    CharacterProgressions: 202,

    # This will get you just enough information to be able to render the character in 3D if you have written a 3D rendering library for Destiny Characters, or "borrowed" ours. It's okay, I won't tell anyone if you're using it. I'm no snitch. (actually, we don't care if you use it - go to town)
    CharacterRenderData: 203,

    # This will return info about activities that a user can see and gating on it, if you are the currently authenticated user or the user has elected to allow anonymous viewing of its progression info. Note that the data returned by this can be unfortunately problematic and relatively unreliable in some cases. We'll eventually work on making it more consistently reliable.
    CharacterActivities: 204,

    # This will return info about the equipped items on the character(s). Everyone can see this.
    CharacterEquipment: 205,

    # This will return basic info about instanced items - whether they can be equipped, their tracked status, and some info commonly needed in many places (current damage type, primary stat value, etc)
    ItemInstances: 300,

    # Items can have Objectives (DestinyObjectiveDefinition) bound to them. If they do, this will return info for items that have such bound objectives.
    ItemObjectives: 301,

    # Items can have perks (DestinyPerkDefinition). If they do, this will return info for what perks are active on items.
    ItemPerks: 302,

    # If you just want to render the weapon, this is just enough info to do that rendering.
    ItemRenderData: 303,

    # Items can have stats, like rate of fire. Asking for this component will return requested item's stats if they have stats.
    ItemStats: 304,

    # Items can have sockets, where plugs can be inserted. Asking for this component will return all info relevant to the sockets on items that have them.
    ItemSockets: 305,

    # Items can have talent grids, though that matters a lot less frequently than it used to. Asking for this component will return all relevant info about activated Nodes and Steps on this talent grid, like the good ol' days.
    ItemTalentGrids: 306,

    # Items that *aren't* instanced still have important information you need to know: how much of it you have, the itemHash so you can look up their DestinyInventoryItemDefinition, whether they're locked, etc... Both instanced and non-instanced items will have these properties. You will get this automatically with Inventory components - you only need to pass this when calling GetItem on a specific item.
    ItemCommonData: 307,

    # Items that are "Plugs" can be inserted into sockets. This returns statuses about those plugs and why they can/can't be inserted. I hear you giggling, there's nothing funny about inserting plugs. Get your head out of the gutter and pay attention!
    ItemPlugStates: 308,

    # When obtaining vendor information, this will return summary information about the Vendor or Vendors being returned.
    Vendors: 400,

    # When obtaining vendor information, this will return information about the categories of items provided by the Vendor.
    VendorCategories: 401,

    # When obtaining vendor information, this will return the information about items being sold by the Vendor.
    VendorSales: 402,

    # Asking for this component will return you the account's Kiosk statuses: that is, what items have been filled out/acquired. But only if you are the currently authenticated user or the user has elected to allow anonymous viewing of its progression info.
    Kiosks: 500,

    # A "shortcut" component that will give you all of the item hashes/quantities of items that the requested character can use to determine if an action (purchasing, socket insertion) has the required currency. (recall that all currencies are just items, and that some vendor purchases require items that you might not traditionally consider to be a "currency", like plugs/mods!)
    CurrencyLookups: 600,

    # Returns summary status information about all "Presentation Nodes". See DestinyPresentationNodeDefinition for more details, but the gist is that these are entities used by the game UI to bucket Collectibles and Records into a hierarchy of categories. You may ask for and use this data if you want to perform similar bucketing in your own UI: or you can skip it and roll your own.
    PresentationNodes: 700,

    # Returns summary status information about all "Collectibles". These are records of what items you've discovered while playing Destiny, and some other basic information. For detailed information, you will have to call a separate endpoint devoted to the purpose.
    Collectibles: 800,

    # Returns summary status information about all "Records" (also known in the game as "Triumphs". I know, it's confusing because there's also "Moments of Triumph" that will themselves be represented as "Triumphs.")
    Records: 900,
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
    SUBCLASS:       3284755031,
  }.freeze
  MEMBERSHIP_TYPES = {
    None:          0,
    TigerXbox:     1,
    TigerPsn:      2,
    TigerBlizzard: 4,
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
    vehicle_mods_2:    4265082475,
  }.freeze

  # Used in formatting the attachment
  DAMAGE_COLOR = {
    kinetic: '#d9d9d9',
    arc:     '#80b3ff',
    solar:   '#e68a00',
    void:    '#400080'
  }.freeze


  def initialize(api_key)
    puts 'Initializing Bungie API... Done.'
    @options = { headers: { 'X-API-Key' => api_key } }
    initialize_manifest
  end

  def search_user(requested_gamertag, requested_platform = nil)
    # Transform the requested platform into a numeric ID
    membership_type_id = BungieApi.get_membership_type_id(requested_platform) || -1

    url      = "/Destiny2/SearchDestinyPlayer/#{URI.escape(membership_type_id.to_s)}/#{URI.escape(requested_gamertag.to_s)}/"
    response = self.class.get(url, @options)

    user = response ? response&.parsed_response&.dig('Response', 0) : nil

    unless user
      # Try again after replacing underscores with spaces, for XBox GamerTags
      requested_gamertag.tr!('_', ' ')

      url      = "/Destiny2/SearchDestinyPlayer/#{URI.escape(membership_type_id.to_s)}/#{URI.escape(requested_gamertag.to_s)}/"
      response = self.class.get(url, @options)

      user = response ? response.parsed_response['Response'][0] : nil
    end

    user
  end

  def active_char_with_equipment(membership_type, membership_id)
    url      = "/Destiny2/#{URI.escape(membership_type.to_s)}/Profile/#{URI.escape(membership_id.to_s)}/"
    response = self.class.get(
      url,
      @options.merge(
        query: {
          components: [COMPONENTS[:Characters], COMPONENTS[:CharacterEquipment]].join(',')
        }
      )
    )

    parsed_response = response.parsed_response['Response']
    return nil unless parsed_response

    latest_time_played = Time.new(1980, 1, 1)
    active_char        = nil

    parsed_response.dig('characters', 'data').each_pair do |_, character|
      if character && Time.parse(character.dig('dateLastPlayed')) > latest_time_played
        active_char        = character
        latest_time_played = Time.parse(character.dig('dateLastPlayed'))
      end
    end

    return nil unless active_char

    character_id         = active_char.dig('characterId')
    active_char['items'] = parsed_response.dig('characterEquipment', 'data', character_id, 'items')

    active_char
  end

  def item_details(membership_type, membership_id, item_instance_id)
    url      = "/Destiny2/#{URI.escape(membership_type.to_s)}/Profile/#{URI.escape(membership_id.to_s)}/Item/#{URI.escape(item_instance_id.to_s)}/"
    response = self.class.get(
      url,
      @options.merge(
        query: {
          components: [
                        COMPONENTS[:ItemInstances],
                        COMPONENTS[:ItemPerks],
                        COMPONENTS[:ItemStats],

                        COMPONENTS[:ItemSockets],
                        COMPONENTS[:ItemCommonData],
                        COMPONENTS[:ItemPlugStates],
                      ].join(',')
        }
      )
    )

    item_instance = response.parsed_response['Response']
    return nil unless item_instance

    item_hash = item_instance.dig('item', 'data', 'itemHash').to_s
    return nil unless item_hash

    item = @manifest.lookup_item(item_hash)

    item_details = {
      hash:             item_hash,
      item_instance_id: item_instance.dig('item', 'data', 'itemInstanceId'),
      damage_type:      (DAMAGE_TYPES.key(item_instance.dig('instance', 'data', 'damageType')) || 'Unknown').to_s,
      power_level:      item_instance.dig('instance', 'data', 'primaryStat', 'value'),
      name:             item.dig('displayProperties', 'name'),
      description:      item.dig('displayProperties', 'description'),
      icon:             item.dig('displayProperties', 'icon'),
      has_icon:         item.dig('displayProperties', 'hasIcon'),
      tier:             item.dig('inventory', 'tierTypeName'),
      type:             item.dig('itemTypeDisplayName'),
      type_and_tier:    item.dig('itemTypeAndTierDisplayName'),
    }

    item_details[:perk_sockets] = []

    item&.dig('sockets', 'socketCategories')&.each do |category|
      category&.dig('socketIndexes')&.each do |socket_index|
        ### Manifest data:
        # socket_entry = item.dig('sockets', 'socketEntries')[socket_index]

        ### Item instance data:
        socket_entry = item_instance&.dig('sockets', 'data', 'sockets')&.dig(socket_index)
        next unless socket_entry

        case SOCKET_CATEGORY_IDS.key(category.dig('socketCategoryHash'))
          when :weapon_perks, :armor_perks

            perk_socket = []

            if socket_entry&.dig('reusablePlugs')
              # If the socket supports multiple reusablePlugs, display them all, and mark which is currently selected
              socket_entry&.dig('reusablePlugs')&.each do |plug|
                plug_item = @manifest.lookup_item(plug&.dig('plugItemHash'))
                next unless plug_item

                perk = {
                  hash:        plug_item.dig('hash').to_s,
                  name:        plug_item.dig('displayProperties', 'name'),
                  description: plug_item.dig('displayProperties', 'description'),
                  icon:        plug_item.dig('displayProperties', 'icon'),
                  has_icon:    plug_item.dig('displayProperties', 'hasIcon'),
                  selected:    (plug_item.dig('hash').to_s == socket_entry.dig('plugHash').to_s)
                }

                perk_socket.push perk
              end
            else
              # Otherwise, just display the fixed plug that's in the socket
              plug_item = @manifest.lookup_item(socket_entry&.dig('plugHash'))
              if plug_item
                perk = {
                  hash:        plug_item.dig('hash').to_s,
                  name:        plug_item.dig('displayProperties', 'name'),
                  description: plug_item.dig('displayProperties', 'description'),
                  icon:        plug_item.dig('displayProperties', 'icon'),
                  has_icon:    plug_item.dig('displayProperties', 'hasIcon'),
                  selected:    true
                }

                perk_socket.push perk
              end
            end

            item_details[:perk_sockets].push perk_socket unless perk_socket.empty?


          when :weapon_mods, :armor_mods

            plug_item = @manifest.lookup_item(socket_entry&.dig('plugHash'))
            next unless plug_item && plug_item&.dig('plug')

            case plug_item&.dig('plug', 'plugCategoryIdentifier')
              #v400.weapon.mod_empty
              when 'v400.weapon.mod_guns', 'enhancements.universal'
                next if plug_item&.dig('displayProperties', 'name') == 'Empty Mod Socket'
                # next unless plug_item&.dig('investmentStats')&.first

                item_details[:mod] = {
                  hash:        plug_item.dig('hash').to_s,
                  name:        plug_item.dig('displayProperties', 'name'),
                  description: plug_item.dig('displayProperties', 'description'),
                  icon:        plug_item.dig('displayProperties', 'icon'),
                  has_icon:    plug_item.dig('displayProperties', 'hasIcon')
                }

              when /v400\.plugs\.(weapons|armor)\.masterworks\./
                affected_stat = plug_item.dig('investmentStats')&.first
                stat_details  = @manifest.lookup_stat(affected_stat&.dig('statTypeHash'))

                item_details[:masterwork] = {
                  hash:          plug_item.dig('hash').to_s,
                  name:          plug_item.dig('displayProperties', 'name'),
                  description:   plug_item.dig('displayProperties', 'description'),
                  icon:          plug_item.dig('displayProperties', 'icon'),
                  has_icon:      plug_item.dig('displayProperties', 'hasIcon'),
                  affected_stat: stat_details&.dig('displayProperties', 'name'),
                  value:         affected_stat&.dig('value')
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


    # parsed_response['perks']['data']['perks']


    item_details
  end


  def self.get_membership_type_id(membership_type)
    case membership_type.to_s.strip.downcase
      when 'playstation', 'ps4', 'ps3', 'ps'
        MEMBERSHIP_TYPES[:TigerPsn]
      when 'xbox', 'xb1', 'xb'
        MEMBERSHIP_TYPES[:TigerXbox]
      when 'battlenet', 'bnet', 'blizzard', 'blizard', 'pc'
        MEMBERSHIP_TYPES[:TigerBlizzard]
      else
        nil
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
      else
        nil
    end
  end

  def self.get_bucket_id(bucket_name)
    case bucket_name.to_s.strip.downcase
      when 'primary', 'kinetic'
        ITEM_BUCKET_IDS[:KINETIC_WEAPON]
      when 'special', 'secondary', 'energy'
        ITEM_BUCKET_IDS[:ENERGY_WEAPON]
      when 'heavy', 'power'
        ITEM_BUCKET_IDS[:HEAVY_WEAPON]
      when 'ghost'
        ITEM_BUCKET_IDS[:GHOST]
      when 'head', 'helmet', 'helm'
        ITEM_BUCKET_IDS[:HEAD]
      when 'arm', 'arms', 'gloves', 'gauntlets', 'hands'
        ITEM_BUCKET_IDS[:ARMS]
      when 'chest'
        ITEM_BUCKET_IDS[:CHEST]
      when 'leg', 'legs', 'boots', 'greaves', 'pants'
        ITEM_BUCKET_IDS[:LEGS]
      when 'class', 'mark', 'bond', 'cape', 'cloak', 'towel'
        ITEM_BUCKET_IDS[:CLASS_ITEM]
      when 'ship'
        ITEM_BUCKET_IDS[:SHIP]
      when 'sparrow'
        ITEM_BUCKET_IDS[:SPARROW]
      when 'emblem'
        ITEM_BUCKET_IDS[:EMBLEM]
      else
        nil
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
      else
        nil
    end
  end


  def self.get_hex_color_for_damage_type(damage_type)
    damage_type_key = damage_type.downcase.to_sym
    DAMAGE_COLOR[damage_type_key] || DAMAGE_COLOR[:kinetic]
  end


  private

  def initialize_manifest
    response = self.class.get('/Destiny2/Manifest/', @options)

    parsed_response = response.parsed_response['Response']
    raise 'Invalid manifest URL received' unless parsed_response

    @manifest = BungieManifest.new 'https://www.bungie.net' + parsed_response.dig('mobileWorldContentPaths', 'en')
  end
end