# This migration comes from trifle (originally 20150923092933)
class AddRolesToUsers < ActiveRecord::Migration
  def change
    add_column :users, :roles, :string
  end
end
