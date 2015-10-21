module Hilda::Modules
  class Notifications
    include Hilda::ModuleBase

    def send_notifications()
      # Dummy implementation
    end

    def run_module
      send_notifications
      self.module_output = module_input.deep_dup
    end

    def autorun
      true
    end
  end
end
