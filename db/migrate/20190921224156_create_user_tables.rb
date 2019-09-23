# frozen_string_literal: true

class CreateUserTables < ActiveRecord::Migration[6.0]
  def change
    create_table :bungie_users do |t|
      t.string :membership_id
      t.integer :membership_type
      t.string :display_name

      t.timestamps
    end

    add_index :bungie_users, [:membership_id], unique: true


    create_table :slack_teams do |t|
      t.string :team_id
      t.string :name
      t.string :domain

      t.timestamps
    end

    add_index :slack_teams, [:team_id], unique: true


    create_table :slack_users do |t|
      t.references :slack_team, foreign_key: true, null: false
      t.string :user_id
      t.references :bungie_user, foreign_key: true, null: true

      t.timestamps
    end

    add_index :slack_users, %i[slack_team_id user_id], unique: true


    create_table :discord_users do |t|
      t.string :user_id
      t.references :bungie_user, foreign_key: true, null: false

      t.timestamps
    end

    add_index :discord_users, [:user_id], unique: true

  end
end
