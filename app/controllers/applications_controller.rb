class ApplicationsController < ApplicationController
  before_filter :load_application, :only => [:show]
  filter_access_to :all
  respond_to :html, :json

  # GET /applications
  def index
    @applications = current_user.manageable_applications
    logger.info "#{current_user.loginid}@#{request.remote_ip}: Loaded application index (main page)."
    respond_with @applications
  end

  # GET /applications/1
  def show
    # SECUREME: Can the current user see this application?

    respond_with @application do |format|
      format.csv {
        require 'csv'

        logger.info "#{current_user.loginid}@#{request.remote_ip}: Downloaded CSV of application, #{params[:application]}."

        # Credit CSV code: http://www.funonrails.com/2012/01/csv-file-importexport-in-rails-3.html
        csv_data = CSV.generate do |csv|
          # Add the header
          csv << Application.csv_header
          # Add members of each role
          @application.roles.each do |r|
            r.to_csv.each do |row|
              csv << row
            end
          end
          # Add the owners
          @application.owners.each do |owner|
            csv << ["owner", owner.to_csv].flatten
          end
        end
        send_data csv_data,
          :type => 'text/csv; charset=iso-8859-1; header=present',
          :disposition => "attachment; filename=rm_application_#{@application.to_param}.csv"
      }
    end
  end

  # GET /applications/new
  def new
    # SECUREME: Can the current user try to create a new application?
    @application = Application.new

    respond_with @application
  end

  # POST /applications
  def create
    # SECUREME: Can the current user create applications?

    params[:application][:owner_ids] = [] unless params[:application][:owner_ids]
    params[:application][:owner_ids] << current_user.id unless params[:application][:owner_ids].include? current_user.id
    @application = Application.new(params[:application])

    if @application.save
      logger.info "#{current_user.loginid}@#{request.remote_ip}: Created new application, #{params[:application]}."
    else
      logger.warn "#{current_user.loginid}@#{request.remote_ip}: Failed to create new application, #{params[:application]}."
    end

    respond_with @application
  end

  # PUT /applications/1
  def update
    # SECUREME: Can the current user update this application?

    @application = Application.find(params[:id])

    if @application.update_attributes(params[:application])
      logger.info "#{current_user.loginid}@#{request.remote_ip}: Updated application with params #{params[:application]}."
    end

    respond_with @application do |format|
      format.json { render :json => @application } # A new role may have been created, so we need to render out to reveal the new ID
    end
  end

  # DELETE /applications/1
  def destroy
    # SECUREME: Can the current user delete this application?

    @application = Application.find(params[:id])
    @application.destroy

    logger.info "#{current_user.loginid}@#{request.remote_ip}: Deleted application, #{params[:application]}."

    respond_with @application
  end

  protected

  def load_application
    if permitted_to?(:show, :applications)
      @application = Application.find(params[:id])
      @application.nil? ? nil : @application = Application.find_by_name(params[:id])
    else
      @application = nil
      logger.info "#{current_user.loginid}@#{request.remote_ip}: Tried loading an application without permission."
    end
  end
end
