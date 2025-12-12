class AddIndexToConversationsStatus < ActiveRecord::Migration[7.0]
  def change
    add_index :conversations, :status
  end
end
