class ExpandBungieUserAboutField < ActiveRecord::Migration[6.1]
  def up
    change_column :bungie_users, :about, :text
  end


  def down
    # Reverting will fail if there's data in the DB, due to data exceeding the column size
    # change_column :bungie_users, :about, :string
  end
end
