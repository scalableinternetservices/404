class ExpertProfile < ApplicationRecord
  belongs_to :user
  # Provide an application-level default for convenience
  attribute :knowledge_base_links, :json, default: []
end
