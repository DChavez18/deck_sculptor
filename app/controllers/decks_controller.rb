class DecksController < ApplicationController
  before_action :set_deck, only: [ :show, :edit, :update, :destroy, :suggestions, :analysis, :intent, :save_intent ]

  def index
    @decks = Deck.includes(:commander).order(created_at: :desc)
  end

  def new
    @deck = Deck.new
    if params[:commander_id].present?
      @preselected_commander = Commander.find_by(id: params[:commander_id])
    end
  end

  def create
    @deck = Deck.new(deck_params)

    scryfall_id = params.dig(:deck, :commander_scryfall_id)
    if scryfall_id.present? && @deck.commander_id.blank?
      @deck.commander = Commander.find_by(scryfall_id: scryfall_id) ||
        begin
          card_data = ScryfallService.new.find_card_by_id(scryfall_id)
          Commander.find_or_create_from_scryfall(card_data) if card_data
        end
    end

    if @deck.save
      redirect_to intent_deck_path(@deck), notice: "Deck created! Tell us about your strategy."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @cards_by_category = @deck.cards_by_category
  end

  def edit
  end

  def update
    if @deck.update(deck_params)
      redirect_to @deck, notice: "Deck updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @deck.destroy
    redirect_to decks_path, notice: "#{@deck.name} was deleted."
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
    @strategy          = StrategyAnalyzer.new(@deck).report
    @ratio_report      = RatioAnalyzer.new(@deck).report
    @curve_advice      = CurveAdvisor.new(@deck).recommendations
  end

  def intent
  end

  def save_intent
    intent_params = params.require(:deck).permit(:win_condition, :budget, :archetype, :themes)
    if @deck.update(intent_params.merge(intent_completed: true))
      redirect_to deck_path(@deck), notice: "Deck intent saved! Suggestions have been personalized."
    else
      render :intent, status: :unprocessable_entity
    end
  end

  private

  def set_deck
    @deck = Deck.includes(:commander, :deck_cards).find(params[:id])
  end

  def deck_params
    params.require(:deck).permit(:name, :commander_id, :description, :archetype, :bracket_level,
                                 :win_condition, :budget, :themes, :intent_completed)
  end
end
