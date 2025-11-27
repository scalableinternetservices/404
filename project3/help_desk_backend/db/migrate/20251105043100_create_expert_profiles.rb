class CreateExpertProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :expert_profiles do |t|
      t.references :user, null: false, foreign_key: true
      t.text :bio

      t.timestamps
    end
  end
end
