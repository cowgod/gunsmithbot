class ModifyBungieUser < ActiveRecord::Migration[6.1]
  def change
    change_table :bungie_users do |t|
      t.string :twitch_display_name
      t.string :bungie_display_name
      t.string :bungie_display_name_code
      t.string :about
      t.datetime :first_accessed_at
      t.datetime :last_updated_at


      # "about" : "I want to hug every puppy and eat every pudding",
      #   "firstAccess" : "2015-09-25T12:39:54.415Z",
      #   "lastUpdate" : "2021-08-26T19:18:29.961Z",
    end

  end
end
