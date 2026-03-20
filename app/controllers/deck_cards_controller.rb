class DeckCardsController < ApplicationController
  before_action :set_deck

  def create
    scryfall_id = deck_card_params[:scryfall_id]

    if scryfall_id.blank?
      render json: { error: "scryfall_id is required" }, status: :unprocessable_entity
      return
    end

    card_data = ScryfallService.new.find_card_by_id(scryfall_id)
    category  = CardCategorizer.new(card_data || {}).category

    @deck_card = @deck.deck_cards.build(deck_card_params.merge(category: category))

    if card_data
      @deck_card.assign_attributes(
        type_line:      card_data["type_line"],
        mana_cost:      card_data["mana_cost"],
        cmc:            card_data["cmc"],
        color_identity: Array(card_data["color_identity"]).join(","),
        oracle_text:    card_data["oracle_text"],
        image_uri:      card_data.dig("image_uris", "normal"),
        raw_data:       card_data
      )
    end

    if @deck_card.save
      redirect_to @deck, notice: "#{@deck_card.card_name} added to deck."
    else
      render json: { errors: @deck_card.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @deck_card = @deck.deck_cards.find(params[:id])
    @deck_card.destroy
    redirect_to @deck, notice: "Card removed from deck."
  end

  private

  def set_deck
    @deck = Deck.find(params[:deck_id])
  end

  def deck_card_params
    params.require(:deck_card).permit(:scryfall_id, :card_name, :quantity)
  end
end
