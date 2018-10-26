class CreateVenues < ActiveRecord::Migration[5.0]
  def change
    create_table :venues do |t|
      t.string :venue_name
      t.string :coordinates
    end
  end
end
