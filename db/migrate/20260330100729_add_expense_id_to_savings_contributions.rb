class AddExpenseIdToSavingsContributions < ActiveRecord::Migration[6.1]
  def change
    add_column :savings_contributions, :expense_id, :bigint
  end
end
