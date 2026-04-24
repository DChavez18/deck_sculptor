require "rails_helper"

RSpec.describe "Decks authorization", type: :request do
  let!(:commander) { create(:commander) }

  describe "index scoping" do
    context "signed-in user" do
      let!(:user)       { create(:user) }
      let!(:other_user) { create(:user) }
      let!(:my_deck)    { create(:deck, :owned_by_user, user: user, commander: commander) }
      let!(:other_deck) { create(:deck, :owned_by_user, user: other_user, commander: commander) }

      before { sign_in_as(user) }

      it "shows only the signed-in user's decks" do
        get decks_path
        expect(response.body).to include(my_deck.name)
        expect(response.body).not_to include(other_deck.name)
      end
    end

    context "anonymous user" do
      it "shows only decks matching the anonymous session token" do
        other_deck = create(:deck, commander: commander, anonymous_session_token: "other-token-xyz")

        get new_deck_path
        post decks_path, params: {
          deck: { name: "My Anon Deck", commander_id: commander.id, archetype: "aggro", bracket_level: 2 }
        }
        my_deck = Deck.last

        get decks_path
        expect(response.body).to include(my_deck.name)
        expect(response.body).not_to include(other_deck.name)
      end
    end
  end

  describe "show authorization" do
    context "signed-in user accessing another user's deck" do
      let!(:user)       { create(:user) }
      let!(:other_user) { create(:user) }
      let!(:other_deck) { create(:deck, user: other_user, anonymous_session_token: nil, commander: commander) }

      before { sign_in_as(user) }

      it "returns 404" do
        get deck_path(other_deck)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "deck creation" do
    context "signed-in user" do
      let!(:user) { create(:user) }

      before { sign_in_as(user) }

      it "assigns user_id to the new deck" do
        post decks_path, params: {
          deck: { name: "My Deck", commander_id: commander.id, archetype: "control", bracket_level: 3 }
        }
        expect(Deck.last.user_id).to eq(user.id)
        expect(Deck.last.anonymous_session_token).to be_nil
      end
    end

    context "anonymous user" do
      it "assigns anonymous_session_token to the new deck" do
        get new_deck_path
        post decks_path, params: {
          deck: { name: "Anon Deck", commander_id: commander.id, archetype: "aggro", bracket_level: 2 }
        }
        deck = Deck.last
        expect(deck.user_id).to be_nil
        expect(deck.anonymous_session_token).to be_present
      end
    end
  end
end
