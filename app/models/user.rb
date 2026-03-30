class User < ApplicationRecord
  has_many :expenses
  has_many :categories
  has_many :savings_goals
  has_many :savings_contributions

  validates_uniqueness_of :login_id, allow_nil: true

  def password=(value)
    super(BCrypt::Password.create(value))
  end

  def username=(value)
    super(BCrypt::Password.create(value))
  end
end
