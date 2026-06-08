class CardsController < ApplicationController
  allow_unauthenticated_access

  def search
    @results = []
    if params[:q].present? && params[:q].length >= 2
      t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @results = ScryfallService.new.search_cards(params[:q])
      elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000).round
      Rails.logger.info(
        "[INSTR cards_search] thread_id=#{Thread.current.object_id} q=#{params[:q].inspect} elapsed_ms=#{elapsed}"
      )
    end
    render layout: false
  end
end
