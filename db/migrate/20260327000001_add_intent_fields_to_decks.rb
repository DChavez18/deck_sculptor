class AddIntentFieldsToDecks < ActiveRecord::Migration[8.1]
  def change
    add_column :decks, :win_condition, :string
    add_column :decks, :budget, :string
    add_column :decks, :themes, :text
    add_column :decks, :intent_completed, :boolean, default: false
  end
end
