class ExpertAssignment < ApplicationRecord
  belongs_to :conversation
  belongs_to :expert, class_name: "User"

  STATUSES = %w[active resolved].freeze

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :assigned_at, presence: true
end
