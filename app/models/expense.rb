class Expense < ApplicationRecord
  validates_presence_of :description, :amount, :category_id, :paid_at

  belongs_to :category
  belongs_to :user
  has_one :savings_contribution, foreign_key: :expense_id, dependent: :destroy
end
