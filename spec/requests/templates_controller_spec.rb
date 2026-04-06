require "rails_helper"

RSpec.describe "Templates", type: :request do
  describe "GET /templates" do
    before { get templates_path }

    it { expect(response).to have_http_status(:ok) }

    it "shows all template names" do
      expect(response.body).to include("Aggro Beatdown")
      expect(response.body).to include("Combo Control")
      expect(response.body).to include("Token Swarm")
      expect(response.body).to include("Graveyard Recursion")
      expect(response.body).to include("Spellslinger")
      expect(response.body).to include("Ramp and Stomp")
    end
  end

  describe "GET /templates/:archetype" do
    context "with a valid archetype" do
      before { get template_path("aggro-beatdown") }

      it { expect(response).to have_http_status(:ok) }

      it "shows the template details" do
        expect(response.body).to include("Aggro Beatdown")
      end

      it "includes a link to start a deck with the template" do
        expect(response.body).to include(new_deck_path)
      end
    end

    context "with an unknown archetype" do
      before { get template_path("nonexistent-template") }

      it { expect(response).to have_http_status(:not_found) }
    end
  end
end
