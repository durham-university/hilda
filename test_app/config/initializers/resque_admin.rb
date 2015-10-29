module Hilda
  class ResqueAdmin
    def self.matches?(request)
#      current_user = request.env['warden'].user
#      return current_user.admin?
      return Rails.env.development?
    end
  end
end
