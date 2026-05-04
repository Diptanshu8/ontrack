class RecurringExpense < ApplicationRecord
  FREQUENCIES = %w[monthly weekly yearly].freeze

  belongs_to :user, touch: :data_updated_at
  belongs_to :category

  validates_presence_of :description, :amount, :category_id, :next_due_date, :frequency
  validates :amount,    numericality: { only_integer: true, greater_than: 0 }
  validates :frequency, inclusion: { in: FREQUENCIES }

  def advance_next_due_date!
    new_date = case frequency
               when "monthly" then next_due_date.next_month
               when "weekly"  then next_due_date + 7.days
               when "yearly"  then next_due_date.next_year
               end
    update!(next_due_date: new_date)
  end
end
