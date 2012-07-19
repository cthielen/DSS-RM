class ApplicationsController < ApplicationController
  require 'digest/md5'

  before_filter :load_application, :only => [:show]
  filter_access_to :all

  # GET /applications
  def index
    @applications = Application.all

    respond_to do |format|
      format.html
    end
  end

  # GET /applications/1
  def show
    respond_to do |format|
      format.html { render "show", :layout => false }
    end
  end

  # GET /applications/new
  def new
    @application = Application.new

    respond_to do |format|
      format.html
    end
  end

  # GET /applications/1/edit
  def edit
    @application = Application.find(params[:id])
  end

  # POST /applications
  def create
    @application = Application.new(params[:application])

    respond_to do |format|
      if @application.save
        format.html { redirect_to(@application, :notice => 'Application was successfully created.') }
        format.json { render json: @application, status: :created, location: @application }
      else
        format.html { render :action => "new" }
        format.json { render json: @application.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /applications/1
  def update
    @application = Application.find(params[:id])

    respond_to do |format|
      if @application.update_attributes(params[:application])
        format.html { redirect_to(@application, :notice => 'Application was successfully updated.') }
        format.js { render json: @application, status: :ok }
      else
        format.html { render :action => "edit" }
        format.js { render json: @application.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /applications/1
  def destroy
    @application = Application.find(params[:id])
    @application.destroy

    respond_to do |format|
      format.html { redirect_to(applications_url) }
    end
  end

  protected

  def load_application
    if permitted_to?(:show, :applications)
      @application = Application.find(params[:id])
    else
      @application = nil
      logger.info "#{current_user.loginid}@#{request.remote_ip}: Tried loading an application without permission."
    end
  end
end
