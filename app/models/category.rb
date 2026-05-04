class Category < ApplicationRecord
  validates_presence_of :name, :color

  belongs_to :user, touch: :data_updated_at
  has_many :expenses

  default_scope { order(rank: :asc, id: :asc) }
end
