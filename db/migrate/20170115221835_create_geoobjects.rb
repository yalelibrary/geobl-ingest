class CreateGeoobjects < ActiveRecord::Migration[5.0]
  def change
    create_table :geoobjects do |t|
      t.integer :oid
      t.integer :_oid
      t.integer :level
      t.string :pid
      t.timestamp :orig_date
      t.string :test_handle
      t.string :prod_handle
      t.timestamp :last_process_start
      t.timestamp :last_process_end
      t.integer :processed_index
      t.text :error
      t.string :processed

      t.timestamps
    end
  end
end
