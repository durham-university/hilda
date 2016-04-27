module Hilda
  module UserBehaviour
    extend ActiveSupport::Concern

    def is_admin?
      raise 'Override this'
    end

    def is_registered?
      raise 'Override this'
    end
    
    def is_api_user?
      raise 'Override this'
    end


    def user_key
      send(self.class.user_key_attribute)
    end

    module ClassMethods
      def user_key_attribute
        raise 'Override this'
      end

      def find_by_user_key(key)
        find_by(user_key_attribute => key)
      end
    end
  end
end
