class DecksController < ApplicationController
  before_action :set_deck, only: [ :show, :suggestions, :analysis ]

  def index
    @decks = Deck.includes(:commander).order(created_at: :desc)
  end

  def new
    @deck = Deck.new
  end

  def create
    @deck = Deck.new(deck_params)
    if @deck.save
      redirect_to @deck, notice: "Deck created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @cards_by_category = @deck.cards_by_category
  end

  def suggestions
    @suggestions = SuggestionEngine.new(@deck).suggestions
    @edhrec_top  = EdhrecService.new.top_cards(@deck.commander.name)
  end

  def analysis
    @mana_curve        = @deck.mana_curve
    @cards_by_category = @deck.cards_by_category
    deck_card_names    = [ @deck.commander.name ] + @deck.deck_cards.pluck(:card_name)
    @combos            = ComboFinderService.new.find_combos(deck_card_names)
  end

  private

  def set_deck
    @deck = Deck.includes(:commander, :deck_cards).find(params[:id])
  end

  def deck_params
    params.require(:deck).permit(:name, :commander_id, :description, :archetype, :power_level)
  end
end
