require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#filter_tags_for" do
    def card(oracle_text:, type_line: "Instant")
      { "oracle_text" => oracle_text, "type_line" => type_line }
    end

    # Card Draw
    context "draw tag" do
      it "does NOT tag opponent draw effects" do
        c = card(oracle_text: "Each opponent draws 2 cards.")
        expect(helper.filter_tags_for(c, [])).not_to include("draw")
      end

      it "DOES tag a card that draws for the controller" do
        c = card(oracle_text: "Draw 2 cards.")
        expect(helper.filter_tags_for(c, [])).to include("draw")
      end

      it "tags scry effects" do
        c = card(oracle_text: "Scry 2.")
        expect(helper.filter_tags_for(c, [])).to include("draw")
      end

      it "tags surveil effects" do
        c = card(oracle_text: "Surveil 1.")
        expect(helper.filter_tags_for(c, [])).to include("draw")
      end
    end

    # Ramp
    context "ramp tag" do
      it "does NOT tag fetch lands (type_line includes Land)" do
        c = card(
          oracle_text: "Search your library for a land card, put it into play.",
          type_line: "Land — Fetch"
        )
        expect(helper.filter_tags_for(c, [])).not_to include("ramp")
      end

      it "DOES tag a non-land with library search for basic land" do
        c = card(
          oracle_text: "Search your library for a basic land card and put it onto the battlefield.",
          type_line: "Sorcery"
        )
        expect(helper.filter_tags_for(c, [])).to include("ramp")
      end
    end

    # Board Wipes
    context "wipe tag" do
      it "does NOT tag pump effects that affect each creature" do
        c = card(oracle_text: "Each creature gets +1/+1 until end of turn.")
        expect(helper.filter_tags_for(c, [])).not_to include("wipe")
      end

      it "DOES tag destroy all creatures" do
        c = card(oracle_text: "Destroy all creatures.")
        expect(helper.filter_tags_for(c, [])).to include("wipe")
      end

      it "DOES tag exile all creatures" do
        c = card(oracle_text: "Exile all creatures.")
        expect(helper.filter_tags_for(c, [])).to include("wipe")
      end

      it "DOES tag fixed damage to each creature" do
        c = card(oracle_text: "Deals 3 damage to each creature.")
        expect(helper.filter_tags_for(c, [])).to include("wipe")
      end
    end
  end
end
