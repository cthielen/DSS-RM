class ApplicationOperatorship < ActiveRecord::Base
  validates_presence_of :application, :entity
  validates_uniqueness_of :application_id, :scope => [:entity_id, :parent_id]

  before_destroy :require_destroy_flag

  belongs_to :application, :touch => true
  belongs_to :entity, :touch => true
  
  after_create :grant_operatorship_to_group_members
  before_destroy :remove_operatorship_from_group_members
  
  after_save { |operatorship| operatorship.log_changes(:save) }
  after_destroy { |operatorship| operatorship.log_changes(:destroy) }
  
  protected
  
  # Explicitly log that this application operatorship was created or destroyed
  def log_changes(action)
    Rails.logger.tagged "ApplicationOperatorship #{id}" do
      case action
      when :save
        if created_at_changed?
          logger.info "Created application operatorship between #{entity.log_identifier} and #{application.log_identifier}."
        else
          # ApplicationOperatorships should really only be created or destroyed, not updated.
          logger.error "log_changes called for existing ApplicationOperatorship. This shouldn't happen. Operatorship is between #{entity.log_identifier} and #{application.log_identifier}."
        end
      when :destroy
        logger.info "Removed application operatorship between #{entity.log_identifier} and #{application.log_identifier}."
      else
        logger.warn "Unknown action in log_changes #{action}."
      end
    end
  end
  
  private
  
  # Grant this application operatorship to all members of the group
  # (iff group operatorship is with a group)
  def grant_operatorship_to_group_members
    if entity.type == 'Group'
      Rails.logger.tagged "ApplicationOperatorship #{id}" do
        entity.members.each do |m|
          logger.info "Granting application operatorship (#{id}, #{application.name}) granted to group (#{entity.id}/#{entity.name}) to its member (#{m.id}/#{m.name})"
          ao = ApplicationOperatorship.new
          ao.application_id = application_id
          ao.entity_id = m.id
          ao.parent_id = self.id
          ao.save!
        end
      end
    end
  end

  # Remove this application operatorship from all members of the group
  # (iff group operatorship is with a group)  
  def remove_operatorship_from_group_members
    if entity.type == 'Group'
      Rails.logger.tagged "ApplicationOperatorship #{id}" do
        entity.members.each do |m|
          logger.info "Removing application operatorship (#{id}, #{application.name}) about to be removed from group (#{entity.id}/#{entity.name} from its member #{m.id}/#{m.name})"
          ao = ApplicationOperatorship.find_by_application_id_and_entity_id_and_parent_id(application_id, m.id, self.id)
          if ao
            destroying_calculated_application_operatorship do
              ao.destroy!
            end
          else
            logger.warn "Failed to remove application operatorship (#{id}, #{application.name}) assigned to group member (#{m.id}/#{m.name}) which needs to be removed as the group (#{entity.id}/#{entity.name}) is losing that operatorship."
          end
        end
      end
    end
  end
  
  # This flag is required to destroy any application operatorship which has a parent operatorship.
  # The purpose of this flagging mechanism is to ensure an ApplicationOperatorship is only destroyed
  # in the right ways, e.g. triggering the grant/remove callbacks found in this class.
  def require_destroy_flag
    if parent_id and not Thread.current[:application_operatorship_destroy_flag]
      errors.add(:parent_id, "can't destroy a calculated group operatorship without flag properly set")
      return false
    end
  end
end

def destroying_calculated_application_operatorship
  begin
    Thread.current[:application_operatorship_destroy_flag] = true
    yield
  ensure
    Thread.current[:application_operatorship_destroy_flag] = nil
  end
end
