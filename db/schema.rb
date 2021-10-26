# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2021_10_26_140300) do

  create_table "bungie_activities", charset: "utf8", force: :cascade do |t|
    t.datetime "started_at", null: false
    t.integer "duration", null: false
    t.bigint "instance_id", null: false
    t.bigint "reference_id"
    t.bigint "director_activity_hash"
    t.integer "mode", null: false
    t.string "modes"
    t.boolean "is_private", default: false, null: false
    t.datetime "scanned_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["instance_id"], name: "index_bungie_activities_on_instance_id", unique: true
  end

  create_table "bungie_activity_clips", charset: "utf8", force: :cascade do |t|
    t.bigint "bungie_activity_id", null: false
    t.bigint "twitch_video_id", null: false
    t.datetime "notified_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["bungie_activity_id", "twitch_video_id"], name: "idx__bng_act_clips__activity_id__twitch_video_id", unique: true
    t.index ["bungie_activity_id"], name: "index_bungie_activity_clips_on_bungie_activity_id"
    t.index ["twitch_video_id"], name: "index_bungie_activity_clips_on_twitch_video_id"
  end

  create_table "bungie_activity_players", charset: "utf8", force: :cascade do |t|
    t.bigint "bungie_activity_id", null: false
    t.bigint "bungie_activity_team_id"
    t.bigint "bungie_character_id"
    t.integer "kills", null: false
    t.integer "assists", null: false
    t.integer "deaths", null: false
    t.integer "standing"
    t.decimal "score", precision: 10
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["bungie_activity_id", "bungie_character_id"], name: "idx__bng_act_players__activity_id__character_id", unique: true
    t.index ["bungie_activity_id"], name: "index_bungie_activity_players_on_bungie_activity_id"
    t.index ["bungie_activity_team_id"], name: "index_bungie_activity_players_on_bungie_activity_team_id"
    t.index ["bungie_character_id"], name: "index_bungie_activity_players_on_bungie_character_id"
  end

  create_table "bungie_activity_teams", charset: "utf8", force: :cascade do |t|
    t.bigint "bungie_activity_id", null: false
    t.integer "team_id", null: false
    t.string "team_name"
    t.integer "standing"
    t.decimal "score", precision: 10
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["bungie_activity_id", "team_id"], name: "idx__bng_act_teams__activity_id__team_id", unique: true
    t.index ["bungie_activity_id"], name: "index_bungie_activity_teams_on_bungie_activity_id"
  end

  create_table "bungie_characters", charset: "utf8", force: :cascade do |t|
    t.bigint "bungie_membership_id", null: false
    t.bigint "character_id"
    t.string "race_hash"
    t.string "race_name"
    t.string "class_hash"
    t.string "class_name"
    t.string "gender_hash"
    t.string "gender_name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["bungie_membership_id"], name: "index_bungie_characters_on_bungie_membership_id"
    t.index ["character_id"], name: "index_bungie_characters_on_character_id", unique: true
  end

  create_table "bungie_memberships", charset: "utf8", force: :cascade do |t|
    t.string "membership_id"
    t.integer "membership_type"
    t.string "display_name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "bungie_user_id"
    t.index ["bungie_user_id"], name: "index_bungie_memberships_on_bungie_user_id"
    t.index ["membership_id"], name: "index_bungie_memberships_on_membership_id", unique: true
  end

  create_table "bungie_users", charset: "utf8", force: :cascade do |t|
    t.bigint "twitch_user_id"
    t.string "membership_id"
    t.string "unique_name"
    t.string "display_name"
    t.string "normalized_name"
    t.string "psn_display_name"
    t.string "xbox_display_name"
    t.string "blizzard_display_name"
    t.string "steam_display_name"
    t.string "stadia_display_name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "twitch_display_name"
    t.string "bungie_display_name"
    t.string "bungie_display_name_code"
    t.string "about"
    t.datetime "first_accessed_at"
    t.datetime "last_updated_at"
    t.boolean "find_twitch_clips", default: false, null: false
    t.index ["membership_id"], name: "index_bungie_users_on_membership_id", unique: true
    t.index ["twitch_user_id"], name: "index_bungie_users_on_twitch_user_id"
  end

  create_table "discord_memberships", charset: "utf8", force: :cascade do |t|
    t.bigint "discord_user_id", null: false
    t.bigint "discord_server_id", null: false
    t.boolean "notify_twitch_clips", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["discord_server_id"], name: "index_discord_memberships_on_discord_server_id"
    t.index ["discord_user_id", "discord_server_id"], name: "idx__disc_memberships__user_id__server_id", unique: true
    t.index ["discord_user_id"], name: "index_discord_memberships_on_discord_user_id"
  end

  create_table "discord_servers", charset: "utf8", force: :cascade do |t|
    t.bigint "server_id", null: false
    t.string "name", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "discord_users", charset: "utf8", force: :cascade do |t|
    t.string "user_id"
    t.bigint "bungie_user_id"
    t.string "username"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["bungie_user_id"], name: "fk_discord_bungie_user"
    t.index ["user_id"], name: "index_discord_users_on_user_id", unique: true
  end

  create_table "slack_teams", charset: "utf8", force: :cascade do |t|
    t.string "team_id"
    t.string "name"
    t.string "domain"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["team_id"], name: "index_slack_teams_on_team_id", unique: true
  end

  create_table "slack_users", charset: "utf8", force: :cascade do |t|
    t.bigint "team_id", null: false
    t.string "user_id"
    t.bigint "bungie_user_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["bungie_user_id"], name: "fk_slack_bungie_user"
    t.index ["team_id", "user_id"], name: "index_slack_users_on_team_id_and_user_id", unique: true
    t.index ["team_id"], name: "index_slack_users_on_team_id"
  end

  create_table "twitch_users", charset: "utf8", force: :cascade do |t|
    t.bigint "user_id"
    t.string "login_name"
    t.string "display_name"
    t.string "broadcaster_type"
    t.text "description"
    t.string "profile_image_url"
    t.string "offline_image_url"
    t.integer "view_count"
    t.datetime "channel_created_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["user_id"], name: "index_twitch_users_on_user_id", unique: true
  end

  create_table "twitch_videos", charset: "utf8", force: :cascade do |t|
    t.bigint "twitch_user_id"
    t.bigint "video_id"
    t.bigint "stream_id"
    t.string "title"
    t.text "description"
    t.datetime "started_at"
    t.datetime "published_at"
    t.string "url"
    t.string "thumbnail_url"
    t.string "viewable"
    t.integer "view_count"
    t.string "language"
    t.string "video_type"
    t.integer "duration"
    t.index ["twitch_user_id"], name: "index_twitch_videos_on_twitch_user_id"
    t.index ["video_id"], name: "index_twitch_videos_on_video_id", unique: true
  end

  add_foreign_key "bungie_activity_clips", "bungie_activities", on_delete: :cascade
  add_foreign_key "bungie_activity_clips", "twitch_videos", on_delete: :cascade
  add_foreign_key "bungie_activity_players", "bungie_activities", on_delete: :cascade
  add_foreign_key "bungie_activity_players", "bungie_activity_teams", on_delete: :cascade
  add_foreign_key "bungie_activity_players", "bungie_characters", on_delete: :cascade
  add_foreign_key "bungie_activity_teams", "bungie_activities", on_delete: :cascade
  add_foreign_key "bungie_characters", "bungie_memberships"
  add_foreign_key "bungie_memberships", "bungie_users"
  add_foreign_key "bungie_users", "twitch_users"
  add_foreign_key "discord_memberships", "discord_servers"
  add_foreign_key "discord_memberships", "discord_users"
  add_foreign_key "discord_users", "bungie_users", name: "fk_discord_bungie_user"
  add_foreign_key "slack_users", "bungie_users", name: "fk_slack_bungie_user"
  add_foreign_key "slack_users", "slack_teams", column: "team_id"
  add_foreign_key "twitch_videos", "twitch_users"
end
