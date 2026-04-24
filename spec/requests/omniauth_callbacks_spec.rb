require "rails_helper"

RSpec.describe "OmniauthCallbacks", type: :request do
  before do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "google-uid-999",
      info: { email: "googleuser@example.com" }
    )
  end

  after do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:google_oauth2] = nil
  end

  describe "GET /auth/google_oauth2/callback" do
    context "first-time signin (new user)" do
      it "creates a user and redirects to root" do
        expect { get "/auth/google_oauth2/callback" }.to change(User, :count).by(1)
        expect(response).to redirect_to(root_path)
      end

      it "sets google_uid on the new user" do
        get "/auth/google_oauth2/callback"
        expect(User.last.google_uid).to eq("google-uid-999")
      end

      it "starts a session" do
        get "/auth/google_oauth2/callback"
        expect(Session.count).to eq(1)
      end
    end

    context "returning user with matching google_uid" do
      let!(:existing_user) { create(:google_user, google_uid: "google-uid-999", email_address: "googleuser@example.com") }

      it "signs in the existing user without creating a duplicate" do
        expect { get "/auth/google_oauth2/callback" }.not_to change(User, :count)
        expect(response).to redirect_to(root_path)
      end
    end

    context "existing email account without google_uid" do
      let!(:existing_user) { create(:user, email_address: "googleuser@example.com") }

      it "links google_uid to the existing user" do
        get "/auth/google_oauth2/callback"
        existing_user.reload
        expect(existing_user.google_uid).to eq("google-uid-999")
      end

      it "does not create a new user" do
        expect { get "/auth/google_oauth2/callback" }.not_to change(User, :count)
      end
    end

    context "anonymous deck claim" do
      it "reassigns anonymous decks to the Google user" do
        commander = create(:commander)
        get new_deck_path
        post decks_path, params: {
          deck: { name: "Anon Deck", commander_id: commander.id, archetype: "aggro", bracket_level: 2 }
        }
        deck = Deck.last
        expect(deck.user_id).to be_nil

        get "/auth/google_oauth2/callback"

        deck.reload
        expect(deck.user_id).to be_present
        expect(deck.anonymous_session_token).to be_nil
      end
    end
  end

  describe "GET /auth/failure" do
    it "redirects to signin with an alert" do
      get "/auth/failure", params: { message: "access_denied" }
      expect(response).to redirect_to(new_session_path)
      follow_redirect!
      expect(response.body).to include("Google sign-in failed")
    end
  end
end
