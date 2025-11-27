class Message < ApplicationRecord
  ROLES = %w[initiator expert].freeze

  belongs_to :conversation
  belongs_to :sender, class_name: "User"

  validates :content, presence: true
  validates :sender_role, presence: true, inclusion: { in: ROLES }
end
