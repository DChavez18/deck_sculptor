require "rails_helper"

RSpec.describe "Commanders", type: :request do
  let(:scryfall_service)  { instance_double(ScryfallService) }
  let(:edhrec_service)    { instance_double(EdhrecService) }
  let(:combo_service)     { instance_double(ComboFinderService) }

  before do
    allow(ScryfallService).to receive(:new).and_return(scryfall_service)
    allow(EdhrecService).to receive(:new).and_return(edhrec_service)
    allow(ComboFinderService).to receive(:new).and_return(combo_service)
    allow(edhrec_service).to receive(:top_cards_with_details).and_return([])
    allow(edhrec_service).to receive(:commander_themes).and_return([])
    allow(edhrec_service).to receive(:name_to_slug).and_return("test-commander")
    allow(combo_service).to receive(:find_combos).and_return([])
  end

  describe "GET /commanders/search" do
    context "when query param is present" do
      let(:results) do
        [ { "id" => "abc", "name" => "Jace, the Mind Sculptor", "type_line" => "Legendary Planeswalker — Jace" } ]
      end

      before do
        allow(scryfall_service).to receive(:search_commander).with("Jace").and_return(results)
        get search_commanders_path, params: { q: "Jace" }
      end

      it { expect(response).to have_http_status(:ok) }
    end

    context "when query param is blank" do
      before { get search_commanders_path, params: { q: "" } }

      it { expect(response).to have_http_status(:ok) }
    end
  end

  describe "GET /commanders/:id" do
    context "when commander exists in database" do
      let(:commander) { create(:commander) }

      before { get commander_path(commander) }

      it { expect(response).to have_http_status(:ok) }
      it { expect(response.body).to include(commander.name) }
    end

    context "with EDHREC top cards" do
      let(:commander) { create(:commander) }
      let(:top_cards) do
        [
          { name: "Sol Ring", category: "artifact", reason: "Popular with #{commander.name}" },
          { name: "Rhystic Study", category: "enchantment", reason: "Popular with #{commander.name}" }
        ]
      end

      before do
        allow(edhrec_service).to receive(:top_cards_with_details).and_return(top_cards)
        get commander_path(commander)
      end

      it { expect(response).to have_http_status(:ok) }
      it { expect(response.body).to include("Sol Ring") }
      it { expect(response.body).to include("Rhystic Study") }
    end

    context "with known combos" do
      let(:commander) { create(:commander) }
      let(:combos) do
        [ { cards: [ commander.name, "Thassa's Oracle" ], result: "Win the game", steps: "" } ]
      end

      before do
        allow(combo_service).to receive(:find_combos).and_return(combos)
        get commander_path(commander)
      end

      it { expect(response).to have_http_status(:ok) }
      it { expect(response.body).to include("Thassa&#39;s Oracle") }
    end

    context "when commander does not exist" do
      before { get commander_path("nonexistent-id") }

      it { expect(response).to redirect_to(root_path) }
    end
  end
end
