class DeckCardsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_deck

  def create
    scryfall_id = deck_card_params[:scryfall_id]
    card_name   = deck_card_params[:card_name]
    return_to   = deck_card_params[:return_to]
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

    all_cats  = CardCategorizer.new(card_data).categories
    primary   = all_cats.first
    secondary = (all_cats - [ primary ]).join(",")

    @deck_card = @deck.deck_cards.build(
      deck_card_params.except("return_to").merge(
        scryfall_id:           card_data["id"],
        card_name:             card_data["name"],
        category:              primary,
        secondary_categories:  secondary,
        type_line:             card_data["type_line"],
        mana_cost:             card_data["mana_cost"],
        cmc:                   card_data["cmc"],
        color_identity:        Array(card_data["color_identity"]).join(","),
        oracle_text:           card_data["oracle_text"],
        image_uri:             card_data.dig("image_uris", "normal"),
        raw_data:              card_data
      )
    )

    if @deck_card.save
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update(
              "deck_card_list",
              partial: "decks/deck_card_list",
              locals: { deck: @deck, cards_by_category: @deck.cards_by_category }
            ),
            turbo_stream.remove("suggestion-#{card_data['id']}")
          ]
        end
        format.html do
          if return_to == "suggestions"
            redirect_to suggestions_deck_path(@deck), notice: "#{@deck_card.card_name} added to deck."
          else
            redirect_to @deck, notice: "#{@deck_card.card_name} added to deck."
          end
        end
      end
    else
      redirect_to @deck, alert: @deck_card.errors.full_messages.to_sentence
    end
  rescue ActiveRecord::RecordNotUnique
    @deck.deck_cards.reload
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update(
            "deck_card_list",
            partial: "decks/deck_card_list",
            locals: { deck: @deck, cards_by_category: @deck.cards_by_category }
          ),
          turbo_stream.remove("suggestion-#{card_data['id']}")
        ]
      end
      format.html do
        redirect_to @deck, notice: "#{card_name} is already in your deck."
      end
    end
  end

  def update
    @deck_card = @deck.deck_cards.find(params[:id])
    new_quantity = params.dig(:deck_card, :quantity).to_i

    if new_quantity < 1
      @deck_card.destroy
      redirect_to @deck, notice: "#{@deck_card.card_name} removed from deck."
      return
    end

    if new_quantity > 1 && !@deck_card.basic_land?
      redirect_to @deck, alert: "Non-basic cards are limited to 1 copy in Commander."
      return
    end

    @deck_card.update!(quantity: new_quantity)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @deck }
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
    params.require(:deck_card).permit(:scryfall_id, :card_name, :quantity, :return_to)
  end
end
