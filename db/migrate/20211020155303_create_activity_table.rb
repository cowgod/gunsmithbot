class CreateActivityTable < ActiveRecord::Migration[6.1]
  def change
    create_table :bungie_activities do |t|
      t.datetime :started_at, null: false
      t.integer :duration, null: false
      t.bigint :instance_id, null: false
      t.bigint :reference_id
      t.bigint :director_activity_hash
      t.integer :mode, null: false
      t.string :modes
      t.boolean :is_private, null: false, default: false

      t.datetime :scanned_at

      t.timestamps
    end


    create_table :bungie_activity_teams do |t|
      t.references :bungie_activity, null: false, foreign_key: { on_delete: :cascade }
      t.integer :team_id, null: false
      t.string :team_name
      t.integer :standing
      t.decimal :score

      t.timestamps
    end


    create_table :bungie_activity_players do |t|
      t.references :bungie_activity, null: false, foreign_key: { on_delete: :cascade }
      t.references :bungie_activity_team, foreign_key: { on_delete: :cascade }
      t.references :bungie_character, foreign_key: { on_delete: :cascade }
      t.integer :standing
      t.decimal :score

      t.timestamps
    end


  end
end
