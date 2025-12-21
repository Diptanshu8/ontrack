class AddUserIdToExpensesAndCategories < ActiveRecord::Migration[6.1]
  def up
    add_reference :expenses, :user, index: true
    add_reference :categories, :user, index: true
    
    # Backfill existing data to the first user
    # We use raw SQL to avoid model validation issues during migration
    first_user = User.order(:id).first
    if first_user
      say "Assigning existing data to User ##{first_user.id}"
      update("UPDATE expenses SET user_id = #{first_user.id}")
      update("UPDATE categories SET user_id = #{first_user.id}")
    else
      say "No users found. Existing data (if any) will have NULL user_id."
    end
  end

  def down
    remove_reference :expenses, :user
    remove_reference :categories, :user
  end
end