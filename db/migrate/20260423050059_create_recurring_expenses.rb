class CreateRecurringExpenses < ActiveRecord::Migration[6.1]
  def change
    create_table :recurring_expenses do |t|
      t.bigint  :user_id,       null: false
      t.bigint  :category_id,   null: false
      t.text    :description,   null: false
      t.integer :amount,        null: false
      t.string  :frequency,     null: false
      t.date    :next_due_date, null: false
      t.boolean :active,        null: false, default: true

      t.timestamps
    end

    add_index :recurring_expenses, :user_id
    add_index :recurring_expenses, :next_due_date
  end
end
