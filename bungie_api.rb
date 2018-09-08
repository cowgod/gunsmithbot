require 'httparty'
require 'uri'
require 'time'


class BungieApi
  include HTTParty
  base_uri 'https://www.bungie.net/Platform/'


  COMPONENTS = {
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

  # http://api.trialsofthenine.com/manifest/items/1518042134,1887808042,1891561814,2824453288,3609169817,3211001969,1245809813,1069887756,3773306894,4222882592,806017499,3635991036,1460578930,1409726984,3183180185
  ITEM_BUCKET_IDS = {
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
  }.freeze


  def initialize(api_key)
    @options = { headers: { 'X-API-Key' => api_key } }
  end

  # def questions
  #   self.class.get("/2.2/questions", @options)
  # end
  # 
  # def users
  #   self.class.get("/2.2/users", @options)
  # end

  def search_user(gamertag)
    response = self.class.get("/Destiny2/SearchDestinyPlayer/-1/#{URI.escape(gamertag.to_s)}/", @options)
    response ? response.parsed_response['Response'][0] : nil

    # response.parsed_response['Response'][0]['displayName']
    # response.parsed_response['Response'][0]['membershipId']
  end


  # def active_char_id(user_info)
  #   response = self.class.get(
  #     "/Destiny2/#{URI.escape(user_info['membershipType'].to_s)}/Profile/#{URI.escape(user_info['membershipId'].to_s)}/",
  #     @options.merge(
  #       query: {
  #         components: COMPONENTS[:Characters]
  #       }
  #     )
  #   )
  #
  #   return nil unless response.parsed_response['Response']['characters']
  #
  #   active_hash        = nil
  #   latest_time_played = 0
  #
  #   response.parsed_response['Response']['characters']['data'].each_pair do |hash, character|
  #     # TODO - how to compare dateLastPlayed? format is 2018-08-27T03:05:32Z
  #     if character && Time.parse(character['dateLastPlayed']) > latest_time_played
  #       active_hash = hash
  #     end
  #   end
  #
  #   active_hash
  # end


  def active_char_with_equipment(membership_type, membership_id)
    response = self.class.get(
      "/Destiny2/#{URI.escape(membership_type.to_s)}/Profile/#{URI.escape(membership_id.to_s)}/",
      @options.merge(
        query: {
          components: [COMPONENTS[:Characters], COMPONENTS[:CharacterEquipment]].join(',')
        }
      )
    )

    return nil unless response.parsed_response['Response']['characters']

    latest_time_played = 0
    active_char        = nil

    response.parsed_response['Response']['characters']['data'].each_pair do |_, character|
      if character && Time.parse(character['dateLastPlayed']) > latest_time_played
        active_char = character
      end
    end

    active_char['items'] = response.parsed_response['Response']['characterEquipment']['data'][active_char['characterId']]['items']

    active_char
  end


  # def get_item_hash_for_char_and_bucket(char_hash, bucket_hash)
  #   response = self.class.get(
  #     "/Destiny2/#{URI.escape(user_info['membershipType'].to_s)}/Profile/#{URI.escape(user_info['membershipId'].to_s)}/",
  #     @options.merge(
  #       query: {
  #         components: COMPONENTS[:CharacterEquipment]
  #       }
  #     )
  #   )
  #
  #   return nil unless response.parsed_response['Response']['characters']
  #
  #   active_hash        = nil
  #   latest_time_played = 0
  #
  #   response.parsed_response['Response']['characters']['data'].each_pair do |hash, character|
  #     # TODO - how to compare dateLastPlayed? format is 2018-08-27T03:05:32Z
  #     if character && Time.parse(character['dateLastPlayed']) > latest_time_played
  #       active_hash = hash
  #     end
  #   end
  #
  #   active_hash
  # end


  def self.get_bucket_id(bucket_name)
    case bucket_name.strip.downcase
      when 'primary', 'kinetic' then
        ITEM_BUCKET_IDS[:KINETIC_WEAPON]
      when 'special', 'secondary', 'energy' then
        ITEM_BUCKET_IDS[:ENERGY_WEAPON]
      when 'heavy', 'power' then
        ITEM_BUCKET_IDS[:HEAVY_WEAPON]
      when 'ghost' then
        ITEM_BUCKET_IDS[:GHOST]
      when 'head', 'helmet' then
        ITEM_BUCKET_IDS[:HEAD]
      when 'arm', 'arms', 'gloves', 'gauntlets' then
        ITEM_BUCKET_IDS[:ARMS]
      when 'chest' then
        ITEM_BUCKET_IDS[:CHEST]
      when 'leg', 'legs', 'boots', 'greaves' then
        ITEM_BUCKET_IDS[:LEGS]
      when 'class', 'mark', 'bond', 'cape', 'cloak' then
        ITEM_BUCKET_IDS[:CLASS_ITEM]
      else
        null
    end
  end


end