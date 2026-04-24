class CommandersController < ApplicationController
  allow_unauthenticated_access

  def search
    @results = []
    if params[:q].present?
      @results = ScryfallService.new.search_commander(params[:q])
      scryfall_ids = @results.map { |c| c["id"] }
      @commander_db_ids = Commander.where(scryfall_id: scryfall_ids).pluck(:scryfall_id, :id).to_h
    else
      @commander_db_ids = {}
    end
  end

  def show
    @commander = Commander.find_by(id: params[:id])
    redirect_to root_path, alert: "Commander not found." and return unless @commander

    edhrec            = EdhrecService.new
    @edhrec_top_cards = edhrec.top_cards_with_details(@commander.name)
    @edhrec_themes    = edhrec.commander_themes(@commander.name)
    @combos           = ComboFinderService.new.find_combos([ @commander.name ])
  end
end
