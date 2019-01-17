class EntitiesController < ApplicationController
  before_action :new_entity_from_params, only: :create
  before_action :load_entities, only: :index
  before_action :load_entity, only: [:show, :update]

  def index
    authorize Entity

    @cache_key = "entities/index/#{@entities.maximum(:updated_at).try(:utc).try(:to_s, :number)}/#{params[:q]}"

    respond_to do |format|
      format.json { render 'entities/index', status: :ok }
    end
  end

  def show # rubocop:disable Metrics/AbcSize
    authorize @entity

    @cache_key = 'entity/' + @entity.id.to_s + '/' + @entity.updated_at.try(:utc).try(:to_s, :number)

    respond_to do |format|
      format.json { render 'entities/show', status: :ok }
      format.csv do
        require 'csv'

        # Credit CSV code: http://www.funonrails.com/2012/01/csv-file-importexport-in-rails-3.html
        csv_data = CSV.generate do |csv|
          csv << Person.csv_header
          @entity.members.each do |m|
            csv << m.to_csv if m.active
          end
        end
        send_data csv_data,
                  type: 'text/csv; charset=iso-8859-1; header=present',
                  disposition: 'attachment; filename=' + unix_filename(@entity.name.to_s)
      end
    end
  end

  def create
    authorize @entity

    @entity.save

    @entity.owners << current_user if params[:entity][:type] == 'Group'

    if @entity.group?
      @group = @entity
      render 'groups/create'
    else
      respond_to do |format|
        format.json { render json: @entity }
      end
    end
  end

  def update
    authorize @entity

    affected_role_ids = @entity.roles.map(&:id) if @entity.group?

    respond_to do |format|
      if @entity.update_attributes(entity_params)
        # The update may have only touched associations and not @entity directly,
        # so we'll touch the timestamp ourselves to make sure our caches are
        # invlidated correctly.
        @entity.touch

        if @entity.group?
          affected_role_ids = (affected_role_ids + @entity.roles.map(&:id)).flatten.uniq
          Role.where(id: affected_role_ids).each do |role|
            Rails.logger.debug "Entities(Group)#update will cause role_audit for role #{role.id} / #{role.token}"
            Sync.role_audit(Sync.encode(role))
          end
        end

        @cache_key = 'entity/' + @entity.id.to_s + '/' + @entity.updated_at.try(:utc).try(:to_s, :number)

        format.json { render 'entities/show', status: :ok }
      else
        logger.error "Entity#update failed. Reason(s): #{@entity.errors.full_messages.join(', ')}"
        format.json { render json: @entity.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @entity = Entity.find(params[:id])

    authorize @entity

    if @entity.group?
      logger.info "#{current_user.log_identifier}@#{request.remote_ip}: Deleted entity, #{@entity}."

      @entity.destroy
    end

    respond_to do |format|
      format.json { render json: nil }
    end
  end

  def activity
    @entity = Entity.find(params[:id])

    authorize @entity

    @activity = @entity.activity
    if @activity
      if @activity.empty?
        @cache_key = nil
      else
        @cache_key = 'entity/' + @entity.id.to_s + '/activity/' + @activity[0].performed_at.try(:utc).try(:to_s, :number)
      end
    else
      @activity = nil
      @cache_key = nil
    end

    respond_to do |format|
      format.json { render 'shared/activity' }
    end
  end

  protected

  def new_entity_from_params
    # Explicitly check for "Group" and "Person", avoid using 'constantize' (for security)
    if params[:entity][:type] == 'Group'
      @entity = Group.new(entity_params)
    elsif params[:entity][:type] == 'Person'
      @entity = Person.new(entity_params)
    else
      @entity = nil
    end
  end

  private

  def load_entity
    @entity = Entity.find_by_id!(params[:id])
  end

  def load_entities
    if params[:q]
      entities_table = Entity.arel_table
      @entities = []

      q_parts = params[:q].split(' ')

      if q_parts.length == 2
        # Special case where we probably have first name and last name
        @entities = Entity.where(entities_table[:first].matches("%#{q_parts[0]}%")
                          .and(entities_table[:last].matches("%#{q_parts[1]}%")))
      end

      if @entities.empty?
        # Search login IDs in case of an entity-search but looking for person by login ID
        @entities = Entity.where(entities_table[:name].matches("%#{params[:q]}%")
                                                      .or(entities_table[:loginid].matches("%#{params[:q]}%"))
                                                      .or(entities_table[:first].matches("%#{params[:q]}%"))
                                                      .or(entities_table[:last].matches("%#{params[:q]}%")))
      end
    else
      @entities = Entity.all
    end
  end

  def entity_params
    if params[:entity]
      # Workaround for deep_munge issues (http://stackoverflow.com/questions/20164354/rails-strong-parameters-with-empty-arrays)
      params[:entity][:favorite_ids] ||= [] if params[:entity].key?(:favorite_ids)
      params[:entity][:owner_ids] ||= [] if params[:entity].key?(:owner_ids)
      params[:entity][:operator_ids] ||= [] if params[:entity].key?(:operator_ids)
    end
    params.require(:entity).permit(:name, :type, :description, :first, :last, :address, :email, :loginid,
                                   :phone, :active, { owner_ids: [] }, { favorite_ids: [] }, { operator_ids: [] },
                                   { rules_attributes: [:id, :column, :condition, :value, :_destroy] },
                                   { memberships_attributes: [:id, :calculated, :entity_id, :_destroy] },
                                   { group_memberships_attributes: [:id, :calculated, :group_id, :_destroy] },
                                   { group_ownerships_attributes: [:id, :entity_id, :group_id, :_destroy] },
                                   { role_assignments_attributes: [:id, :role_id, :entity_id, :_destroy] },
                                   { group_operatorships_attributes: [:id, :group_id, :entity_id, :_destroy] })
  end
end
