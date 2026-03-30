class CreateSavingsContributions < ActiveRecord::Migration[6.1]
  def change
    create_table :savings_contributions do |t|
      t.bigint  :savings_goal_id, null: false
      t.bigint  :user_id,         null: false
      t.integer :amount,          null: false
      t.text    :note
      t.date    :contributed_on,  null: false

      t.timestamps
    end
    add_index :savings_contributions, :savings_goal_id
    add_index :savings_contributions, :user_id
    add_index :savings_contributions, :contributed_on
  end
end
