class AddKnowledgeBaseLinksToExpertProfiles < ActiveRecord::Migration[8.1]
  def change

    add_column :expert_profiles, :knowledge_base_links, :json
  end
end
