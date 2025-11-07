class AddUniqueIndexToExpertProfiles < ActiveRecord::Migration[8.1]
  def change
    unique_index_name = "unique_expert_profiles_on_user_id"
    add_index :expert_profiles, :user_id, unique: true, name: unique_index_name unless index_exists?(:expert_profiles, :user_id, name: unique_index_name)
  end
end
