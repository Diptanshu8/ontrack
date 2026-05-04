class SavingsContribution < ApplicationRecord
  belongs_to :savings_goal
  belongs_to :user, touch: :data_updated_at
  belongs_to :expense, optional: true

  validates_presence_of :amount, :contributed_on
  validates :amount, numericality: { greater_than: 0 }

  default_scope { order(contributed_on: :desc, id: :desc) }

  before_destroy :delete_linked_expense

  private

  def delete_linked_expense
    expense&.delete  # use delete (no callbacks) to avoid circular destroy
  end
end
