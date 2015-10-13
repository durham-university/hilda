module Hilda::Jobs::WithUser
  extend ActiveSupport::Concern

  included do
    attr_accessor :user_key
  end

  def initialize(params={})
    case params[:user]
    when String
      @user = nil
      self.user_key = params[:user]
    else
      @user = user
      self.user_key = params[:user].user_key
    end
  end

  def dump_attributes
    super + [:user_key]
  end

  def user
    @user ||= User.find_by_user_key(user_key)
  end

end
