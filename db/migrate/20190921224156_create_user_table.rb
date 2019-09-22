# frozen_string_literal: true

class CreateUserTable < ActiveRecord::Migration[6.0]
  def change
    create_table :users do |t|
      t.integer :type
      t.integer :team_id
      t.integer :user_id
      t.string :username
      t.string :bungie_membership_id

      t.timestamps
    end
  end
end
