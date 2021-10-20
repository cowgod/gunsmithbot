# frozen_string_literal: true

class SupportTwitchReporting < ActiveRecord::Migration[6.1]
  def change
    create_table :twitch_users do |t|
      t.integer :user_id
      t.string :login_name
      t.string :display_name
      t.string :broadcaster_type
      t.string :description
      t.string :profile_image_url
      t.string :offline_image_url
      t.integer :view_count
      t.datetime :channel_created_at

      t.timestamps
    end


    create_table :twitch_videos do |t|
      t.references :twitch_user, foreign_key: true

      t.integer :video_id
      t.integer :stream_id
      t.string :title
      t.string :description
      t.datetime :started_at
      t.datetime :published_at
      t.string :url
      t.string :thumbnail_url
      t.string :viewable
      t.integer :view_count
      t.string :language
      t.string :type
      t.integer :duration
    end


    change_table :bungie_users do |t|
      t.references :twitch_user, foreign_key: true
      t.boolean :find_twitch_streams, null: false, default: false
    end


    # create_table :activity_clips do |t|
    #   t.references :membership_id
    #
    #   t.timestamps
    # end


    # create_table :post_game_carnage_reports do |t|
    #
    #   t.timestamps
    # end

  end
end
