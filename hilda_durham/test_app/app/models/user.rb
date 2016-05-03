class User < ActiveRecord::Base
  include Oubliette::UserBehaviour
  include Schmit::UserBehaviour
  include Trifle::UserBehaviour
  include Hilda::UserBehaviour

  serialize :roles, Array

  devise :database_authenticatable, :ldap_authenticatable, :rememberable, :trackable

  # To enable both database and ldap authentication, we must somehow differentiate
  # between ldap and database users. If Devise finds a valid user object that fails
  # authentication it will not try other authentication strategies. So we must 
  # prevent returning a user object for the wrong strategy that would then fail
  # authentication. Differntiation is currently done based on presence of
  # encrypted_password in the user.
  def self.find_for_database_authentication(conditions)
    user = super(conditions)
    user.try(:encrypted_password).present? ? user : nil
  end
  
  def self.find_for_ldap_authentication(conditions)
    user = super(conditions)
    user.try(:encrypted_password).present? ? nil : user
  end

  def is_admin?
    roles.include? 'admin'
  end

  def is_registered?
    !new_record?
  end
  
  def is_api_user?
    roles.include? 'api'
  end

  def to_s
    display_name || username
  end

  def self.user_key_attribute
    :username
  end

  def ldap_before_save
    self.email = Devise::LDAP::Adapter.get_ldap_param(self.username,"mail").first
    self.display_name = Devise::LDAP::Adapter.get_ldap_param(self.username,"initials").first + " " + Devise::LDAP::Adapter.get_ldap_param(self.username,"sn").first
    self.department = Devise::LDAP::Adapter.get_ldap_param(self.username,"department").try(:first)
  end
end
