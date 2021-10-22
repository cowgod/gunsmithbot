class TweakColumnTypes < ActiveRecord::Migration[6.1]
  def up
    change_column :bungie_characters, :character_id, :bigint

    rename_column :bungie_characters, :membership_id, :bungie_membership_id
  end


  def down
    change_column :bungie_characters, :character_id, :string

    rename_column :bungie_characters, :bungie_membership_id, :membership_id
  end
end
