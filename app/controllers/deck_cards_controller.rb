class DeckCardsController < ApplicationController
  before_action :set_deck

  def create
    scryfall_id = deck_card_params[:scryfall_id]
    card_name   = deck_card_params[:card_name]
    service     = ScryfallService.new

    card_data = if scryfall_id.present?
      service.find_card_by_id(scryfall_id)
    elsif card_name.present?
      service.find_card_by_name(card_name)
    end

    if card_data.nil?
      redirect_to @deck, alert: "Card not found: \"#{card_name.presence || scryfall_id}\""
      return
    end

    category   = CardCategorizer.new(card_data).category
    @deck_card = @deck.deck_cards.build(
      deck_card_params.merge(
        scryfall_id:    card_data["id"],
        card_name:      card_data["name"],
        category:       category,
        type_line:      card_data["type_line"],
        mana_cost:      card_data["mana_cost"],
        cmc:            card_data["cmc"],
        color_identity: Array(card_data["color_identity"]).join(","),
        oracle_text:    card_data["oracle_text"],
        image_uri:      card_data.dig("image_uris", "normal"),
        raw_data:       card_data
      )
    )

    if @deck_card.save
      redirect_to @deck, notice: "#{@deck_card.card_name} added to deck."
    else
      redirect_to @deck, alert: @deck_card.errors.full_messages.to_sentence
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
