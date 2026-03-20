require "rails_helper"

RSpec.describe "Commanders", type: :request do
  let(:scryfall_service) { instance_double(ScryfallService) }

  before do
    allow(ScryfallService).to receive(:new).and_return(scryfall_service)
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
    end

    context "when commander does not exist" do
      before { get commander_path("nonexistent-id") }

      it { expect(response).to redirect_to(root_path) }
    end
  end
end
