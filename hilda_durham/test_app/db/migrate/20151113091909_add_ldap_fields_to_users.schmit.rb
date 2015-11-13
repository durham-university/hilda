# This migration comes from schmit (originally 20150923083640)
class AddLdapFieldsToUsers < ActiveRecord::Migration
  def change
    add_column :users, :username, :string
    add_column :users, :display_name, :string
    add_column :users, :department, :string
    add_index :users, :username, unique: true    
  end
end
