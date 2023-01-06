class ChangeUserAssociation < ActiveRecord::Migration[6.1]
  def change


    # Add bungie_user_id column to slack_users table
    add_column :slack_users, :bungie_user_id, :bigint, after: :user_id
    add_foreign_key :slack_users, :bungie_users, name: :fk_slack_bungie_user

    # Add bungie_user_id column to discord_users table
    add_column :discord_users, :bungie_user_id, :bigint, after: :user_id
    add_foreign_key :discord_users, :bungie_users, name: :fk_discord_bungie_user


    reversible do |migration|
      migration.up do
        # Associate each Slack user with its associated Bungie user
        execute <<~SQL
          UPDATE IGNORE
            slack_users SU
              INNER JOIN bungie_memberships BM ON SU.bungie_membership_id = BM.membership_id
              INNER JOIN bungie_users BU ON BM.bungie_user_id = BU.id
          SET
            SU.bungie_user_id = BU.id
          WHERE
            BU.id IS NOT NULL
          ;
        SQL

        # Associate each Discord user with its associated Bungie user
        execute <<~SQL
          UPDATE IGNORE
            discord_users DU
              INNER JOIN bungie_memberships BM ON DU.bungie_membership_id = BM.membership_id
              INNER JOIN bungie_users BU ON BM.bungie_user_id = BU.id
          SET
            DU.bungie_user_id = BU.id
          WHERE
            BU.id IS NOT NULL
          ;
        SQL
      end

      migration.down do
        # Nothing to do on the way down
      end
    end


    # Get rid of the unused bungie_membership_id column
    change_table :slack_users do |t|
	    t.remove_references :bungie_membership
    end

    # Get rid of the unused bungie_membership_id column
    change_table :discord_users do |t|
	    t.remove_references :bungie_membership
    end

  end
end
