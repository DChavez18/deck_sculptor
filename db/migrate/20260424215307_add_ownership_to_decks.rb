class AddOwnershipToDecks < ActiveRecord::Migration[8.1]
  def change
    add_column :decks, :user_id, :integer
    add_column :decks, :anonymous_session_token, :string
    add_index :decks, :user_id
    add_index :decks, :anonymous_session_token
  end
end
