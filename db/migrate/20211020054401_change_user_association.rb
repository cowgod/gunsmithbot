class ChangeUserAssociation < ActiveRecord::Migration[6.1]
  def change


    # Add bungie_user_id column to slack_users table
    change_table :slack_users do |t|
      t.references :bungie_user, foreign_key: true
    end


    # Associate each Slack user with its associated Bungie user
    Slack::SlackUser.all.each do |user|
      user.bungie_user = user&.bungie_membership&.bungie_user
      user.save
    end


    # Get rid of the unused bungie_membership_id column
    change_table :slack_users do |t|
      t.remove :bungie_membership_id
    end


    # Add bungie_user_id column to discord_users table
    change_table :discord_users do |t|
      t.references :bungie_user, foreign_key: true
    end


    # Associate each Discord user with its associated Bungie user
    Discord::DiscordUser.all.each do |user|
      user.bungie_user = user&.bungie_membership&.bungie_user
      user.save
    end


    # Get rid of the unused bungie_membership_id column
    change_table :discord_users do |t|
      t.remove :bungie_membership_id
    end


  end
end
