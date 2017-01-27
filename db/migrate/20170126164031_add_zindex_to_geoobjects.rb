class AddZindexToGeoobjects < ActiveRecord::Migration[5.0]
  def change
    add_column :geoobjects, :zindex, :integer
  end
end
