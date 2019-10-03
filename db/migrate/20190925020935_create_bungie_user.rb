class CreateBungieUser < ActiveRecord::Migration[6.0]
  def change
    create_table :bungie_users do |t|
      t.string :membership_id
      t.string :unique_name
      t.string :display_name
      t.string :normalized_name
      t.string :psn_display_name
      t.string :xbox_display_name
      t.string :blizzard_display_name
      t.string :steam_display_name
      t.string :stadia_display_name

      t.timestamps
    end

    add_index :bungie_users, [:membership_id], unique: true


    change_table :bungie_memberships do |t|
      t.references :bungie_user, foreign_key: true, null: true
    end
  end
end
