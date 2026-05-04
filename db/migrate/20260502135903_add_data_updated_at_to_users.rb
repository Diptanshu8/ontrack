class AddDataUpdatedAtToUsers < ActiveRecord::Migration[6.1]
  # Cache-invalidation token — bumped via `belongs_to :user, touch: :data_updated_at`
  # whenever the user's expenses, categories, recurring expenses, savings goals, or
  # savings contributions change. The iOS app probes this on cold launch to decide
  # whether to re-download data it already has cached.
  def up
    add_column :users, :data_updated_at, :datetime
    User.update_all("data_updated_at = COALESCE(updated_at, NOW())")
  end

  def down
    remove_column :users, :data_updated_at
  end
end
