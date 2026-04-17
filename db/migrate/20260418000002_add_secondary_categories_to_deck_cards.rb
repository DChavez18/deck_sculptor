class AddSecondaryCategoriesToDeckCards < ActiveRecord::Migration[8.0]
  def change
    add_column :deck_cards, :secondary_categories, :string, default: ""
  end
end
