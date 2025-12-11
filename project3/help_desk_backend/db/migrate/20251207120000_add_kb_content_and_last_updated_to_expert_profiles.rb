class AddKbContentAndLastUpdatedToExpertProfiles < ActiveRecord::Migration[7.1]
  def change
    add_column :expert_profiles, :kb_content, :text
    add_column :expert_profiles, :last_updated, :datetime
  end
end
