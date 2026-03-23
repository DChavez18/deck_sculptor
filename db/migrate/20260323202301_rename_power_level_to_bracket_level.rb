class RenamePowerLevelToBracketLevel < ActiveRecord::Migration[8.1]
  def change
    rename_column :decks, :power_level, :bracket_level
    change_column_default :decks, :bracket_level, from: 5, to: 3
  end
end
