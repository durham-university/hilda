module Hilda
  class IngestionProcess < ActiveFedora::Base
    include Hilda::HydraModuleGraph
    include Hilda::ModuleGraphAutosave
    include Hilda::BackgroundRunnable

#    Bootstrap view generation requires this to work
#    def self.columns
#      []
#    end
  end
end
