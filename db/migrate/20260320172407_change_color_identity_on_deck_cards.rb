class ChangeColorIdentityOnDeckCards < ActiveRecord::Migration[8.0]
  def change
    change_column :deck_cards, :color_identity, :string, default: nil
  end
end
