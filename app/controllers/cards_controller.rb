class CardsController < ApplicationController
  allow_unauthenticated_access

  def search
    @results = []
    if params[:q].present? && params[:q].length >= 2
      @results = ScryfallService.new.search_cards(params[:q])
    end
    render layout: false
  end
end
