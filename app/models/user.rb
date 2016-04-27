class User < ActiveRecord::Base
  include Hilda::UserBehaviour

  serialize :roles, Array

  devise :ldap_authenticatable, :rememberable, :trackable

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
