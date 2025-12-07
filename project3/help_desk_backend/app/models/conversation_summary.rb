class ConversationSummary < ApplicationRecord
  belongs_to :conversation

  validates :summary_text, presence: true
end
