class CreateDiscordUserServers < ActiveRecord::Migration[6.1]
  def change
    create_table :discord_servers do |t|
      t.bigint :server_id, null: false
      t.string :name, null: false

      t.timestamps
    end


    create_table :discord_memberships do |t|
      t.references :discord_user, null: false, foreign_key: true
      t.references :discord_server, null: false, foreign_key: true

      t.boolean :notify_twitch_clips, null: false

      t.timestamps
    end

    add_index :discord_memberships, %i[discord_user_id discord_server_id], unique: true, name: :idx__disc_memberships__user_id__server_id
  end
end
