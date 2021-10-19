#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../environment'



# results = {}
#
# results[:bucket_id] = Bungie::Api.get_bucket_id(requested_slot)
# raise QueryError, "Couldn't find the requested slot." unless results[:bucket_id]
#
# results[:slot] = Bungie::Api.get_bucket_code(results[:bucket_id])
#
# results


# bungie_membership = Bungie::BungieMembership.search_membership_by_bungie_name('cowgod77#9729')
bungie_membership = Bungie::BungieMembership.search_membership_by_bungie_name('Gernader Jake#3107')

# Load twitch account
twitch_account = Twitch::Api.instance.get_twitch_user_for_display_name(bungie_membership.bungie_user.twitch_display_name)
twitch_videos = Twitch::Api.instance.get_twitch_videos_for_user_id(twitch_account['id'])


pp twitch_videos

# user                   = Discord::DiscordUser.find_or_create_by(user_id: event.message.author.id)
#
# user              = Discord::DiscordUser.find_by(user_id: event.message.author.id)
#
# character = bungie_membership.load_active_character_with_equipment
#
# results[:item] = Bungie::Api.instance.item_details(bungie_membership.membership_type, bungie_membership.membership_id, requested_item['itemInstanceId'])
