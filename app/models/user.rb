class User < ApplicationRecord
  has_many :expenses
  has_many :categories
  has_many :savings_goals
  has_many :savings_contributions
  has_many :recurring_expenses

  validates_uniqueness_of :login_id, allow_nil: true

  # data_updated_at is the iOS cache-invalidation token. Children touch it via
  # `belongs_to :user, touch: :data_updated_at`. User-level data columns
  # (currently `monthly_goal`) need their own bump since touch chains run
  # child→parent only.
  before_create :init_data_updated_at
  after_update  :bump_data_updated_at_if_data_changed

  def password=(value)
    super(BCrypt::Password.create(value))
  end

  def username=(value)
    super(BCrypt::Password.create(value))
  end

  private

  def init_data_updated_at
    self.data_updated_at ||= Time.current
  end

  # Bump on changes to data-bearing User columns. Skip auth/session columns
  # (password, username, login_id) — those don't change what the iOS app shows.
  # update_column intentionally bypasses ALL callbacks (not just this one) —
  # safe here because data_updated_at has no validations and no other observers.
  def bump_data_updated_at_if_data_changed
    update_column(:data_updated_at, Time.current) if saved_change_to_monthly_goal?
  end
end
