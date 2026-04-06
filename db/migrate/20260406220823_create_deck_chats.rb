class CreateDeckChats < ActiveRecord::Migration[8.1]
  def change
    create_table :deck_chats do |t|
      t.references :deck, null: false, foreign_key: true
      t.string :role, null: false
      t.text :content, null: false

      t.timestamps
    end
  end
end
