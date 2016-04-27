module Hilda
  class ApplicationController < ActionController::Base
    rescue_from DeviseLdapAuthenticatable::LdapException do |exception|
      render text: exception, status: 500
    end
    rescue_from CanCan::AccessDenied do |exception|
      redirect_to root_url, :alert => exception.message
    end
    
    # Prevent CSRF attacks by raising an exception.
    # For APIs, you may want to use :null_session instead.
    protect_from_forgery with: :exception

    # Add username - from https://github.com/plataformatec/devise/wiki/How-To%3a-Allow-users-to-sign-in-using-their-username-or-email-address
    before_action :configure_permitted_parameters, if: :devise_controller?    

    layout Hilda.config.fetch('layout','hilda/application')
    
    protected

    def configure_permitted_parameters
      # devise_parameter_sanitizer.for(:sign_up) { |u| u.permit(:username, :email, :password, :password_confirmation, :remember_me) }
      devise_parameter_sanitizer.for(:sign_in) { |u| u.permit(:login, :username, :email, :password, :remember_me) }
      # devise_parameter_sanitizer.for(:account_update) { |u| u.permit(:username, :email, :password, :password_confirmation, :current_password) }
    end
    

  end
end
