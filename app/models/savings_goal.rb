class SavingsGoal < ApplicationRecord
  belongs_to :user, touch: :data_updated_at
  has_many :savings_contributions, dependent: :destroy

  validates_presence_of :name, :target_amount, :color
  validates :name, uniqueness: { scope: :user_id, message: "already exists" }
  validates :target_amount, numericality: { greater_than: 0 }
  validates :color, format: { with: /\A#[0-9A-Fa-f]{6}\z/ }

  def current_amount
    savings_contributions.sum(:amount)
  end
end
