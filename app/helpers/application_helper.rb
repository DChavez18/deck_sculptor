module ApplicationHelper
  def filter_tags_for(card, reasons)
    tags = []
    text = card["oracle_text"].to_s
    type = card["type_line"].to_s

    draw_match = text.match?(/draw (?:a|\d+|x) cards?/i) ||
                 text.match?(/scry \d+/i) ||
                 text.match?(/surveil \d+/i)
    opponent_draw = text.match?(/each (?:opponent|player) draws/i)
    tags << "draw" if draw_match && !opponent_draw

    ramp_text = text.match?(/add \{|search your library for a (?:basic )?land|land card/i)
    tags << "ramp" if ramp_text && !type.include?("Land")

    tags << "removal" if text.match?(/destroy|exile|sacrifice|return target/i)
    tags << "wipe"    if text.match?(/destroy all|exile all|deals \d+ damage to each creature|deals x damage to each/i)
    tags << "land"    if type.include?("Land")
    tags << "combo"   if reasons.include?("Combo piece")
    tags.join(" ")
  end
end
