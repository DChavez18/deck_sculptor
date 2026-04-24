require "rails_helper"

RSpec.describe "Sessions", type: :request do
  let!(:user) { create(:user, password: "password123") }

  describe "POST /session" do
    context "with valid credentials" do
      it "creates a session and redirects to root" do
        post session_path, params: { email_address: user.email_address, password: "password123" }
        expect(response).to redirect_to(root_path)
        expect(Session.where(user: user).count).to eq(1)
      end
    end

    context "with invalid credentials" do
      it "redirects back to signin with an alert" do
        post session_path, params: { email_address: user.email_address, password: "wrong" }
        expect(response).to redirect_to(new_session_path)
        follow_redirect!
        expect(response.body).to include("Try another email address or password")
      end
    end

    context "anonymous deck claim" do
      it "reassigns anonymous decks to the signed-in user" do
        commander = create(:commander)
        get new_deck_path
        post decks_path, params: {
          deck: { name: "Anon Deck", commander_id: commander.id, archetype: "aggro", bracket_level: 2 }
        }
        deck = Deck.last
        expect(deck.user_id).to be_nil

        post session_path, params: { email_address: user.email_address, password: "password123" }

        deck.reload
        expect(deck.user_id).to eq(user.id)
        expect(deck.anonymous_session_token).to be_nil
      end
    end
  end

  describe "DELETE /session" do
    before do
      post session_path, params: { email_address: user.email_address, password: "password123" }
    end

    it "destroys the session and redirects to signin" do
      expect { delete session_path }.to change { Session.count }.by(-1)
      expect(response).to redirect_to(new_session_path)
    end
  end
end
