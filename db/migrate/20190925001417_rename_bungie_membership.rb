class RenameBungieMembership < ActiveRecord::Migration[6.0]
  def change
    rename_table :bungie_users, :bungie_memberships

    rename_column :bungie_characters, :bungie_user_id, :bungie_membership_id
    rename_column :discord_users, :bungie_user_id, :bungie_membership_id
    rename_column :slack_users, :bungie_user_id, :bungie_membership_id
  end
end
