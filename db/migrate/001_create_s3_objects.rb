
class CreateS3Objects < ActiveRecord::Migration
  def self.up
    create_table :s3_objects do |t|
      t.column :lock_version , :integer , :null => false, :default => 0
      t.column :basket_type  , :integer , :null => false
      t.column :path         , :string  , :null => false
      t.column :basket_rev   , :integer , :null => false, :default => 1
      t.column :object       , :blob
    end
    add_index :s3_objects, [:basket_type, :path], :unique => true
  end

  def self.down
    drop_table :s3_objects
  end
end

