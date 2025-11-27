class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.bigint :sender_id, null: false
      t.string :sender_role, null: false
      t.text :content, null: false
      t.boolean :is_read, null: false, default: false

      t.timestamps
    end

    add_index :messages, :sender_id
    add_foreign_key :messages, :users, column: :sender_id
  end
end
