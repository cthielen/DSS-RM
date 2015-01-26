module ActiveDirectoryWrapper
  require 'active_directory'
  AD_PEOPLE_SETTINGS = YAML.load_file("#{Rails.root.to_s}/config/active_directory.yml")['ad_people']
  AD_GROUPS_SETTINGS = YAML.load_file("#{Rails.root.to_s}/config/active_directory.yml")['ad_groups']

  # Takes loginid as a string (e.g. 'jsmith') and returns an ActiveDirectory::User object
  def ActiveDirectoryWrapper.fetch_user(loginid)
    u = nil

    AD_PEOPLE_SETTINGS.each do |entry|
      settings = {
          :host => entry['host'],
          :base => entry['base'],
          :port => 636,
          :encryption => :simple_tls,
          :auth => {
            :method => :simple,
            :username => entry['user'],
            :password => entry['pass']
          }
      }

      ActiveDirectory::Base.setup(settings)
      u = ActiveDirectory::User.find(:first, :samaccountname => loginid)
      break unless u.nil?
    end

    u
  end

  # Takes name as a string (e.g. 'this-that') and returns an ActiveDirectory::Group object
  def ActiveDirectoryWrapper.fetch_group(group_name)
    settings = {
        :host => AD_GROUPS_SETTINGS['host'],
        :base => AD_GROUPS_SETTINGS['base'],
        :port => 636,
        :encryption => :simple_tls,
        :auth => {
          :method => :simple,
          :username => AD_GROUPS_SETTINGS['user'],
          :password => AD_GROUPS_SETTINGS['pass']
        }
    }

    ActiveDirectory::Base.setup(settings)

    begin
      ActiveDirectory::Group.find(:first, :cn => group_name)
    rescue SystemCallError
      # Usually occurs when AD can't be reached (times out)
      return nil
    end
  end

  # Takes objectGuid as a hex string and returns an ActiveDirectory::Group object
  def ActiveDirectoryWrapper.fetch_group_by_guid(guid)
    settings = {
        :host => AD_GROUPS_SETTINGS['host'],
        :base => AD_GROUPS_SETTINGS['base'],
        :port => 636,
        :encryption => :simple_tls,
        :auth => {
          :method => :simple,
          :username => AD_GROUPS_SETTINGS['user'],
          :password => AD_GROUPS_SETTINGS['pass']
        }
    }

    ActiveDirectory::Base.setup(settings)

    begin
      ActiveDirectory::Group.find(:first, :objectguid => guid)
    rescue SystemCallError
      # Usually occurs when AD can't be reached (times out)
      return nil
    end
  end

  # Takes name as a string (e.g. 'this-that') and returns true or false
  def ActiveDirectoryWrapper.group_exists?(group_name)
    if ActiveDirectoryWrapper.fetch_group(group_name).nil?
      return false
    else
      return true
    end
  end

  # Takes user as an ActiveDirectory::User object and group as a ActiveDirectory::Group object and returns boolean
  def ActiveDirectoryWrapper.add_user_to_group(user, group)
    if group.nil?
      return false
    end

    settings = {
        :host => AD_GROUPS_SETTINGS['host'],
        :base => AD_GROUPS_SETTINGS['base'],
        :port => 636,
        :encryption => :simple_tls,
        :auth => {
          :method => :simple,
          :username => AD_GROUPS_SETTINGS['user'],
          :password => AD_GROUPS_SETTINGS['pass']
        }
    }

    ActiveDirectory::Base.setup(settings)

    group.add user
  end

  # Takes group as an ActiveDirectory::Group object and returns an array of users
  def ActiveDirectoryWrapper.list_group_members(group)
    members = []

    if group.nil?
      return []
    end

    AD_PEOPLE_SETTINGS.each do |entry|
      settings = {
          :host => entry['host'],
          :base => entry['base'],
          :port => 636,
          :encryption => :simple_tls,
          :auth => {
            :method => :simple,
            :username => entry['user'],
            :password => entry['pass']
          }
      }

      ActiveDirectory::Base.setup(settings)

      begin
        members += group.member_users
      rescue NoMethodError
        # active_directory gem throws a NoMethodError if the group is blank
      end
    end

    members
  end

  # Returns true if 'user' is in 'group' (both objects should be queried using fetch_user and fetch_group)
  def ActiveDirectoryWrapper.in_group(user, group)
    settings = {
        :host => AD_GROUPS_SETTINGS['host'],
        :base => AD_GROUPS_SETTINGS['base'],
        :port => 636,
        :encryption => :simple_tls,
        :auth => {
          :method => :simple,
          :username => AD_GROUPS_SETTINGS['user'],
          :password => AD_GROUPS_SETTINGS['pass']
        }
    }

    ActiveDirectory::Base.setup(settings)

    begin
      unless user.nil? or group.nil?
        if user.member_of? group
          return true
        end
      end
    rescue ArgumentError
      # puts "Skipping user due to ArgumentError exception"
      return false
    end

    return false
  end

  def ActiveDirectoryWrapper.remove_user_from_group(user, group)
    if group.nil?
      return false
    end

    settings = {
        :host => AD_GROUPS_SETTINGS['host'],
        :base => AD_GROUPS_SETTINGS['base'],
        :port => 636,
        :encryption => :simple_tls,
        :auth => {
          :method => :simple,
          :username => AD_GROUPS_SETTINGS['user'],
          :password => AD_GROUPS_SETTINGS['pass']
        }
    }

    ActiveDirectory::Base.setup(settings)

    group.remove user
  end
end
