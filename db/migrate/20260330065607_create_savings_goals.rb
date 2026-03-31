class CreateSavingsGoals < ActiveRecord::Migration[6.1]
  def change
    create_table :savings_goals do |t|
      t.bigint  :user_id,       null: false
      t.text    :name,          null: false
      t.integer :target_amount, null: false
      t.string  :color,         null: false, default: "#2a9d8f"
      t.date    :deadline

      t.timestamps
    end
    add_index :savings_goals, :user_id
  end
end
