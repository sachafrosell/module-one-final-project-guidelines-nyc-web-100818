class CreateEvents < ActiveRecord::Migration[5.0]
  def change
    create_table :events do |t|
      t.string :event_title
      t.integer :user_id
      t.integer :venue_id
      t.string :event_id
    end
  end
end
