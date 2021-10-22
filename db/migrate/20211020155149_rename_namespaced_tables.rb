class RenameNamespacedTables < ActiveRecord::Migration[6.1]
  def change
    rename_column :bungie_characters, :bungie_membership_id, :membership_id
    rename_column :slack_users, :slack_team_id, :team_id
  end
end
