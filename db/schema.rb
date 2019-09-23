# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2019_09_21_224156) do

  create_table "bungie_users", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "membership_id"
    t.integer "membership_type"
    t.string "display_name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["membership_id"], name: "index_bungie_users_on_membership_id", unique: true
  end

  create_table "discord_users", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "user_id"
    t.bigint "bungie_user_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["bungie_user_id"], name: "index_discord_users_on_bungie_user_id"
    t.index ["user_id"], name: "index_discord_users_on_user_id", unique: true
  end

  create_table "slack_teams", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "team_id"
    t.string "name"
    t.string "domain"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["team_id"], name: "index_slack_teams_on_team_id", unique: true
  end

  create_table "slack_users", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.bigint "slack_team_id", null: false
    t.string "user_id"
    t.bigint "bungie_user_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["bungie_user_id"], name: "index_slack_users_on_bungie_user_id"
    t.index ["slack_team_id", "user_id"], name: "index_slack_users_on_slack_team_id_and_user_id", unique: true
    t.index ["slack_team_id"], name: "index_slack_users_on_slack_team_id"
  end

  add_foreign_key "discord_users", "bungie_users"
  add_foreign_key "slack_users", "bungie_users"
  add_foreign_key "slack_users", "slack_teams"
end
