
class CreateUsers < ActiveRecord::Migration
  def self.up
    create_table :users do |t|
      t.column :lock_version     , :integer, :null => false, :default => 0
      t.column :access_key_id    , :string , :null => false
      t.column :secret_access_key, :string , :null => false
      t.column :display_name     , :string , :null => false 
    end
    add_index :users, [:access_key_id], :unique => true
    add_index :users, [:display_name], :unique => true
  end

  def self.down
    drop_table :users
  end
end

