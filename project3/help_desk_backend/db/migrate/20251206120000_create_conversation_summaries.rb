class CreateConversationSummaries < ActiveRecord::Migration[8.1]
  def change
    create_table :conversation_summaries do |t|
      t.references :conversation, null: false, foreign_key: true, index: { unique: true }
      t.text :summary_text, null: false
      t.bigint :last_message_id
      t.timestamps
    end
  end
end
