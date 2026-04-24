class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :set_anonymous_session_token

  private

  def set_anonymous_session_token
    return if cookies.signed[:anonymous_session_token].present?
    cookies.signed[:anonymous_session_token] = {
      value: SecureRandom.hex(16),
      expires: 6.months.from_now,
      httponly: true
    }
  end

  def claim_anonymous_decks!(user)
    token = cookies.signed[:anonymous_session_token]
    return unless token.present?
    claimed = Deck.where(anonymous_session_token: token, user_id: nil)
                  .update_all(user_id: user.id, anonymous_session_token: nil)
    if claimed > 0
      flash[:notice] = "Welcome! Saved #{claimed} deck#{'s' unless claimed == 1} to your account."
    end
  end

  def blacklisted?(suggestion, deck)
    scryfall_id = suggestion[:card]["id"] || suggestion[:card]["scryfall_id"]
    deck.card_blacklisted?(scryfall_id) ||
      deck.deck_cards.pluck(:scryfall_id).compact.include?(scryfall_id) ||
      scryfall_id == deck.commander.scryfall_id
  end
end
