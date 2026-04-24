require "rails_helper"

RSpec.describe "Registrations", type: :request do
  describe "GET /signup" do
    it "returns 200" do
      get signup_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /signup" do
    let(:valid_params) do
      { user: { email_address: "newuser@example.com", password: "password123", password_confirmation: "password123" } }
    end

    context "with valid params" do
      it "creates a user and redirects to root" do
        expect { post signup_path, params: valid_params }.to change(User, :count).by(1)
        expect(response).to redirect_to(root_path)
      end

      it "signs the user in" do
        post signup_path, params: valid_params
        expect(Session.count).to eq(1)
      end
    end

    context "with mismatched passwords" do
      it "renders new with 422" do
        post signup_path, params: {
          user: { email_address: "newuser@example.com", password: "password123", password_confirmation: "different" }
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "with missing email" do
      it "renders new with 422" do
        post signup_path, params: {
          user: { email_address: "", password: "password123", password_confirmation: "password123" }
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "anonymous deck claim" do
      it "reassigns anonymous decks to the new user" do
        commander = create(:commander)
        get new_deck_path
        post decks_path, params: {
          deck: { name: "Anon Deck", commander_id: commander.id, archetype: "aggro", bracket_level: 2 }
        }
        deck = Deck.last
        expect(deck.user_id).to be_nil

        post signup_path, params: valid_params

        deck.reload
        expect(deck.user_id).to eq(User.last.id)
        expect(deck.anonymous_session_token).to be_nil
      end
    end
  end
end
