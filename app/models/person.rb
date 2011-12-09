class Person < ActiveRecord::Base
  versioned
  
  belongs_to :title
  has_many :affiliation_assignments
  has_many :affiliations, :through => :affiliation_assignments
  
  has_and_belongs_to_many :groups
  has_many :role_assignments
  
  has_many :ous, :through => :ou_assignments
  has_many :ou_assignments

  has_many :ou_manager_assignments
  has_many :managements, :through => :ou_manager_assignments, :source => :ou, :primary_key => "manager_id"

  has_many :group_manager_assignments
  has_many :ownerships, :through => :group_manager_assignments, :source => :group, :primary_key => "owner_id"
  
  validates_presence_of :loginid
  
  attr_accessible :first, :last, :loginid, :email, :phone, :status, :address, :preferred_name, :ou_tokens, :ou_ids, :group_tokens, :group_ids
  attr_reader :ou_tokens, :group_tokens
  
  def to_param  # overridden
    loginid
  end
  
  def name
      "#{first} #{last}"
  end
  
  # Compute their classifications based on their title
  def classifications
    title.classifications
  end
  
  # Compute roles
  def roles
    roles = []
    
    # Add roles explicitly assigned
    role_assignments.each do |assignment|
      roles << assignment.role
    end
    
    # Add roles via OU defaults
    ous.each do |ou|
      ou.applications.each do |application|
        application.roles.where(:default => true).each do |role|
          # Ensure there are no duplicates
          unless roles.include? role
            roles << role
          end
        end
      end
    end

    # Add roles via public defaults
    Role.includes(:application).where( :default => true ).each do |role|
      # Avoid duplicates
      unless roles.include? role
        roles << role
      end
    end
    
    roles
  end
  
  # Compute accessible applications
  def applications
    apps = []
    
    # Add apps via roles explicitly assigned
    roles.each { |role| apps << role.application }

    # Add apps via OU defaults
    ous.each do |ou|
      ou.applications.each do |application|
        application.roles.where(:default => true).each do |role|
          # Ensure there are no duplicates
          unless apps.include? role.application
            apps << role.application
          end
        end
      end
    end
    
    # Add apps via public defaults
    Role.includes(:application).where( :default => true ).each do |role|
      # Avoid duplicates
      unless apps.include? role.application
        apps << role.application
      end
    end

    apps
  end
  
  def as_json(options={}) 
      { :id => self.id, :name => self.first + " " + self.last } 
  end
  
  # ACL symbols
  def role_symbols
    # Get this app's API key
    api_key = YAML.load_file("#{Rails.root.to_s}/config/api_keys.yml")['keys']['key']
    
    syms = []
    
    # Query for permissions of user via API key, converting them into declarative_authentication's needed symbols
    roles.includes("application").where(:applications => {:api_key => api_key}).each do |role|
      syms << role.name.underscore.to_sym
    end
    
    syms
  end
  
  def ou_tokens=(ids)
      self.ou_ids = ids.split(",")
  end

  def group_tokens=(ids)
      self.group_ids = ids.split(",")
  end
end
