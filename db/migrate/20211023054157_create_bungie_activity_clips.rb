class CreateBungieActivityClips < ActiveRecord::Migration[6.1]
  def change
    create_table :bungie_activity_clips do |t|
      t.references :bungie_activity, null: false, foreign_key: { on_delete: :cascade }
      t.references :twitch_video, null: false, foreign_key: { on_delete: :cascade }
      t.datetime :reported_at
      t.timestamps
    end
  end
end
