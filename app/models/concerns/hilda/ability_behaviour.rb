module Hilda
  module AbilityBehaviour
    extend ActiveSupport::Concern

    include CanCan::Ability

    def initialize(user)
      set_hilda_abilities(user)
    end

    def set_hilda_abilities(user)
      user ||= User.new
      if user.is_admin?
        can :manage, :all
      elsif user.is_editor?
        can :manage, Hilda::IngestionProcess
      elsif user.is_registered?
#        can(:manage, Hilda::IngestionProcess, owner: user.user_key) if user.user_key.present?
#        can :manage, Hilda::IngestionProcess
      else
      end
    end
  end
end
