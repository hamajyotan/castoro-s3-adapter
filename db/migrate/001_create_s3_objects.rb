
class CreateS3Objects < ActiveRecord::Migration
  def self.up
    create_table :s3_objects do |t|
      t.column :basket_type, :integer, :null => false
      t.column :path       , :string , :null => false
      t.column :basket_id  , :integer, :null => false
      t.column :basket_rev , :integer, :null => false, :default => 1
    end
    add_index :s3_objects, [:basket_type, :path], :unique => true
  end

  def self.down
    drop_table :s3_objects
  end
end

