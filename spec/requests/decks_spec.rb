require "rails_helper"

RSpec.describe "Decks", type: :request do
  let!(:commander) { create(:commander) }
  let!(:deck) { create(:deck, commander: commander) }

  describe "GET /decks" do
    before { get decks_path }

    it { expect(response).to have_http_status(:ok) }
  end

  describe "GET /decks/new" do
    before { get new_deck_path }

    it { expect(response).to have_http_status(:ok) }
  end

  describe "POST /decks" do
    context "with valid params" do
      let(:params) do
        {
          deck: {
            name: "My Deck",
            commander_id: commander.id,
            archetype: "control",
            power_level: 7
          }
        }
      end

      it "creates a deck and redirects to it" do
        expect { post decks_path, params: params }.to change(Deck, :count).by(1)
        expect(response).to redirect_to(deck_path(Deck.last))
      end
    end

    context "with invalid params" do
      let(:params) { { deck: { name: "" } } }

      it "does not create a deck and re-renders new" do
        expect { post decks_path, params: params }.not_to change(Deck, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "GET /decks/:id" do
    before { get deck_path(deck) }

    it { expect(response).to have_http_status(:ok) }
  end

  describe "GET /decks/:id/suggestions" do
    let(:scryfall_service) { instance_double(ScryfallService, commander_suggestions: []) }

    before do
      allow(ScryfallService).to receive(:new).and_return(scryfall_service)
      get suggestions_deck_path(deck)
    end

    it { expect(response).to have_http_status(:ok) }
  end

  describe "GET /decks/:id/analysis" do
    before { get analysis_deck_path(deck) }

    it { expect(response).to have_http_status(:ok) }
  end
end
