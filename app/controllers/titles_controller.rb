class TitlesController < ApplicationController
  filter_access_to :all, :attribute_check => true, :load_method => :load_titles

  def index
    respond_to do |format|
      format.json { render json: @titles }
    end
  end

  private

  def load_titles
    if params[:q]
      titles_table = Title.arel_table
      @titles = Title.with_permissions_to(:read).where(titles_table[:name].matches("%#{params[:q]}%").or(titles_table[:code].matches("%#{params[:q]}%")))
    else
      @titles = Title.with_permissions_to(:read).all
    end
  end
end
