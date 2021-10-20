class CreateActivityTable < ActiveRecord::Migration[6.1]
  def change
    create_table :bungie_activities do |t|
      t.datetime :started_at
      t.integer :duration
      t.integer :instance_id
      t.integer :mode
      t.boolean :is_private, null: false, default: false

      t.timestamps
    end


    create_table :bungie_activity_teams do |t|
      t.references :bungie_activity, foreign_key: { on_delete: :cascade }
      t.integer :team_id
      t.string :team_name
      t.integer :standing
      t.decimal :score

      t.timestamps
    end


    create_table :bungie_activity_players do |t|
      t.references :bungie_activity, foreign_key: { on_delete: :cascade }
      t.references :bungie_character, foreign_key: { on_delete: :cascade }
      t.references :bungie_activity_team, foreign_key: { on_delete: :cascade }
      t.integer :standing
      t.decimal :score


      t.timestamps
    end


  end
end
