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

bungie_membership = Bungie::BungieMembership.search_membership_by_bungie_name('cowgod77')

puts bungie_membership

# user                   = Discord::DiscordUser.find_or_create_by(user_id: event.message.author.id)
#
# user              = Discord::DiscordUser.find_by(user_id: event.message.author.id)
#
# character = bungie_membership.load_active_character_with_equipment
#
# results[:item] = Bungie::Api.instance.item_details(bungie_membership.membership_type, bungie_membership.membership_id, requested_item['itemInstanceId'])
