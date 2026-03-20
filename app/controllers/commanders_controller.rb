class CommandersController < ApplicationController
  def search
    @results = []
    if params[:q].present?
      @results = ScryfallService.new.search_commander(params[:q])
    end
  end

  def show
    @commander = Commander.find_by(id: params[:id])
    redirect_to root_path, alert: "Commander not found." unless @commander
  end
end
