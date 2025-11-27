class User < ApplicationRecord
  has_secure_password

  has_one :expert_profile, dependent: :destroy
  has_many :initiated_conversations, class_name: "Conversation", foreign_key: :initiator_id, dependent: :nullify
  has_many :assigned_conversations, class_name: "Conversation", foreign_key: :assigned_expert_id, dependent: :nullify
  has_many :messages, foreign_key: :sender_id, dependent: :nullify

  validates :username, presence: true, uniqueness: true
  validates :password, length: { minimum: 5 }, if: -> { password.present? }
end
